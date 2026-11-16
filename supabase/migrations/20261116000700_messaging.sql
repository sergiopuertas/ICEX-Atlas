-- =============================================================================
-- ICEX Atlas · 0700 · messaging: conversaciones 1:1 con categoría, mensajes, leídos
-- =============================================================================

create type messaging.conversation_tipo as enum ('directa', 'grupo');
create type messaging.categoria as enum (
  'solicitud_informacion', 'oportunidad_laboral', 'mentoria', 'networking', 'evento', 'colaboracion_empresarial');

create table messaging.conversations (
  id                       uuid primary key default util.uuid_v7(),
  tipo                     messaging.conversation_tipo not null default 'directa',
  categoria                messaging.categoria not null default 'networking',
  -- Clave única para 1:1: "menor_uuid:mayor_uuid". Null en grupos (preparado, no usado en MVP).
  direct_key               text unique,
  titulo                   text,
  creado_por               uuid references identity.members (user_id) on delete set null,
  ultimo_mensaje_en        timestamptz,
  ultimo_mensaje_id        uuid,
  ultimo_mensaje_preview   text,
  created_at               timestamptz not null default now(),
  check (tipo = 'grupo' or direct_key is not null)
);

create table messaging.conversation_members (
  conversation_id   uuid not null references messaging.conversations (id) on delete cascade,
  user_id           uuid not null references identity.members (user_id) on delete cascade,
  ultimo_leido_id   uuid,
  no_leidos         integer not null default 0 check (no_leidos >= 0),
  silenciado        boolean not null default false,
  archivado         boolean not null default false,
  joined_at         timestamptz not null default now(),
  primary key (conversation_id, user_id)
);
create index conversation_members_user_idx on messaging.conversation_members (user_id, conversation_id);

-- Mensajes particionados por mes usando el propio UUIDv7 como clave de rango (D-009).
create table messaging.messages (
  id               uuid not null,                     -- UUIDv7 generado en el cliente → idempotencia
  conversation_id  uuid not null references messaging.conversations (id) on delete cascade,
  remitente_id     uuid references identity.members (user_id) on delete set null,
  cuerpo           text not null check (char_length(cuerpo) between 1 and 4000),
  created_at       timestamptz not null default now(),
  primary key (id)
) partition by range (id);
create index messages_conversation_idx on messaging.messages (conversation_id, id desc);

create table messaging.messages_default partition of messaging.messages default;

create or replace function messaging.ensure_partitions(p_from date, p_months int)
returns int language plpgsql security definer set search_path = ''
as $$
declare
  v_start date := date_trunc('month', p_from)::date;
  v_end date;
  v_name text;
  v_created int := 0;
begin
  for i in 0 .. p_months - 1 loop
    v_end := (v_start + interval '1 month')::date;
    v_name := 'messages_' || to_char(v_start, 'YYYY_MM');
    if to_regclass('messaging.' || v_name) is null then
      execute format(
        'create table messaging.%I partition of messaging.messages for values from (%L) to (%L)',
        v_name, util.uuid_v7_floor(v_start::timestamptz), util.uuid_v7_floor(v_end::timestamptz));
      execute format('alter table messaging.%I enable row level security', v_name);
      v_created := v_created + 1;
    end if;
    v_start := v_end;
  end loop;
  return v_created;
end;
$$;
revoke execute on function messaging.ensure_partitions(date, int) from public, authenticated, anon;
grant execute on function messaging.ensure_partitions(date, int) to service_role;

-- Particiones desde enero de 2025 (datos de demo) hasta 3 meses vista. El cron mantiene el resto.
select messaging.ensure_partitions('2025-01-01', (extract(year from age(now() + interval '3 months', '2025-01-01')) * 12
  + extract(month from age(now() + interval '3 months', '2025-01-01')) + 1)::int);

alter table messaging.conversations enable row level security;
alter table messaging.conversation_members enable row level security;
alter table messaging.messages enable row level security;
alter table messaging.messages_default enable row level security;

-- -----------------------------------------------------------------------------
-- Interfaz pública
-- -----------------------------------------------------------------------------
create or replace function messaging.is_participant(p_conversation uuid, p_user uuid default null)
returns boolean language sql stable security definer set search_path = ''
as $$
  select exists (select 1 from messaging.conversation_members cm
    where cm.conversation_id = p_conversation and cm.user_id = coalesce(p_user, (select auth.uid())));
$$;

create or replace function messaging.direct_key(p_a uuid, p_b uuid)
returns text language sql immutable set search_path = ''
as $$ select least(p_a, p_b)::text || ':' || greatest(p_a, p_b)::text; $$;

grant execute on function messaging.is_participant(uuid, uuid), messaging.direct_key(uuid, uuid) to authenticated, service_role;

-- RLS: solo participantes. Las escrituras pasan por api.send_message / api.mark_read.
create policy conversations_select on messaging.conversations for select to authenticated
  using ((select identity.is_member()) and messaging.is_participant(id));
create policy conversation_members_select on messaging.conversation_members for select to authenticated
  using ((select identity.is_member()) and messaging.is_participant(conversation_id));
create policy conversation_members_update_own on messaging.conversation_members for update to authenticated
  using (user_id = (select auth.uid()) and (select identity.is_member()))
  with check (user_id = (select auth.uid()));
create policy messages_select on messaging.messages for select to authenticated
  using ((select identity.is_member()) and messaging.is_participant(conversation_id));

grant select on messaging.conversations, messaging.conversation_members, messaging.messages to authenticated;
grant update (silenciado, archivado) on messaging.conversation_members to authenticated;
grant all on all tables in schema messaging to service_role;

-- -----------------------------------------------------------------------------
-- Realtime: Broadcast desde la base de datos al canal privado de la conversación.
-- Canal: "conversation:<uuid>". Autorización con RLS sobre realtime.messages.
-- -----------------------------------------------------------------------------
create or replace function messaging.broadcast_message()
returns trigger language plpgsql security definer set search_path = ''
as $$
begin
  perform realtime.send(
    jsonb_build_object(
      'id', new.id,
      'conversation_id', new.conversation_id,
      'remitente_id', new.remitente_id,
      'cuerpo', new.cuerpo,
      'created_at', new.created_at),
    'message.created',
    'conversation:' || new.conversation_id::text,
    true);
  return null;
end;
$$;
create trigger messages_broadcast after insert on messaging.messages
  for each row execute function messaging.broadcast_message();

-- Autorización de canales privados.
--   conversation:<uuid> → participantes de la conversación
--   user:<uuid>         → solo el propio usuario (no leídos, notificaciones)
create policy realtime_icex_read on realtime.messages for select to authenticated
  using (
    (select identity.is_member()) and (
      (realtime.topic() like 'conversation:%'
        and messaging.is_participant(substring(realtime.topic() from 14)::uuid))
      or realtime.topic() = 'user:' || (select auth.uid())::text));

-- Los clientes solo pueden emitir (broadcast) "typing"/"read" a conversaciones propias.
create policy realtime_icex_write on realtime.messages for insert to authenticated
  with check (
    (select identity.is_member())
    and realtime.topic() like 'conversation:%'
    and messaging.is_participant(substring(realtime.topic() from 14)::uuid)
    and extension = 'broadcast');
