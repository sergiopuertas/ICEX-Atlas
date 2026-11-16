-- =============================================================================
-- ICEX Atlas · 0800 · notifications: centro de notificaciones, preferencias, push
-- =============================================================================

create type notifications.tipo as enum (
  'nuevo_seguidor', 'recomendacion', 'comentario', 'mensaje', 'evento', 'novedad', 'sistema');
create type notifications.plataforma as enum ('ios', 'android', 'web');

create table notifications.notifications (
  id          uuid primary key default util.uuid_v7(),
  user_id     uuid not null references identity.members (user_id) on delete cascade,
  tipo        notifications.tipo not null,
  -- Agrupación: notificaciones no leídas con la misma group_key se fusionan ("Ana y 3 más…").
  group_key   text,
  actor_ids   uuid[] not null default '{}',
  total       integer not null default 1,
  payload     jsonb not null default '{}'::jsonb,
  leido       boolean not null default false,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);
create index notifications_user_idx on notifications.notifications (user_id, updated_at desc, id desc);
create unique index notifications_group_unread_uidx on notifications.notifications (user_id, group_key)
  where not leido and group_key is not null;
create index notifications_unread_idx on notifications.notifications (user_id) where not leido;

create table notifications.preferences (
  user_id                        uuid primary key references identity.members (user_id) on delete cascade,
  push_mensajes                  boolean not null default true,
  push_social                    boolean not null default true,     -- seguidores, recomendaciones, comentarios
  push_eventos                   boolean not null default true,
  push_novedades                 boolean not null default true,
  email_novedades                boolean not null default false,
  email_resumen_semanal          boolean not null default false,
  -- Consentimiento expreso (RGPD) para comunicaciones por email.
  consentimiento_comunicaciones  boolean not null default false,
  consentimiento_at              timestamptz,
  updated_at                     timestamptz not null default now()
);
create trigger preferences_touch before update on notifications.preferences
  for each row execute function util.touch_updated_at();

create table notifications.push_tokens (
  token       text primary key check (char_length(token) between 10 and 4096),
  user_id     uuid not null references identity.members (user_id) on delete cascade,
  plataforma  notifications.plataforma not null,
  updated_at  timestamptz not null default now()
);
create index push_tokens_user_idx on notifications.push_tokens (user_id);

alter table notifications.notifications enable row level security;
alter table notifications.preferences enable row level security;
alter table notifications.push_tokens enable row level security;

create policy notifications_select_own on notifications.notifications for select to authenticated
  using (user_id = (select auth.uid()) and (select identity.is_member()));
create policy notifications_update_own on notifications.notifications for update to authenticated
  using (user_id = (select auth.uid()) and (select identity.is_member()))
  with check (user_id = (select auth.uid()));
create policy notifications_delete_own on notifications.notifications for delete to authenticated
  using (user_id = (select auth.uid()) and (select identity.is_member()));

create policy preferences_own on notifications.preferences for all to authenticated
  using (user_id = (select auth.uid()) and (select identity.is_member()))
  with check (user_id = (select auth.uid()) and (select identity.is_member()));

create policy push_tokens_own on notifications.push_tokens for all to authenticated
  using (user_id = (select auth.uid()) and (select identity.is_member()))
  with check (user_id = (select auth.uid()) and (select identity.is_member()));

grant select, delete on notifications.notifications to authenticated;
grant update (leido) on notifications.notifications to authenticated;
grant select, insert, update on notifications.preferences to authenticated;
grant select, insert, update, delete on notifications.push_tokens to authenticated;
grant all on all tables in schema notifications to service_role;

-- -----------------------------------------------------------------------------
-- Colas (pgmq). Los productores encolan dentro de su transacción; las Edge
-- Functions consumen (invocadas por pg_cron cada minuto).
--   push         → una notificación push a enviar (ya filtrada por preferencias)
--   message_events → mensaje nuevo; push-dispatcher decide si el destinatario está offline
--   embeddings   → contenido a (re)indexar para el Orientador
-- -----------------------------------------------------------------------------
select pgmq.create('push');
select pgmq.create('message_events');
select pgmq.create('embeddings');

create or replace function notifications.wants_push(p_user uuid, p_tipo notifications.tipo)
returns boolean language sql stable security definer set search_path = ''
as $$
  select coalesce((
    select case
      when p_tipo = 'mensaje' then p.push_mensajes
      when p_tipo in ('nuevo_seguidor', 'recomendacion', 'comentario') then p.push_social
      when p_tipo = 'evento' then p.push_eventos
      when p_tipo = 'novedad' then p.push_novedades
      else true end
    from notifications.preferences p where p.user_id = p_user), true);
$$;

-- Crea o agrupa una notificación y encola el push si procede. Interfaz pública del módulo.
create or replace function notifications.notify(
  p_user uuid, p_tipo notifications.tipo, p_actor uuid, p_payload jsonb, p_group_key text default null)
returns uuid language plpgsql security definer set search_path = ''
as $$
declare v_id uuid;
begin
  if p_user is null or p_user = p_actor then return null; end if;
  if not identity.is_member_id(p_user) then return null; end if;
  if p_actor is not null and social.is_blocked_between(p_user, p_actor) then return null; end if;

  if p_group_key is not null then
    update notifications.notifications n
       set total = n.total + 1,
           actor_ids = (array_prepend(p_actor, array_remove(n.actor_ids, p_actor)))[1:5],
           payload = n.payload || p_payload,
           updated_at = now()
     where n.user_id = p_user and n.group_key = p_group_key and not n.leido
       and not (p_actor = any (n.actor_ids))
    returning n.id into v_id;
    if v_id is null and exists (select 1 from notifications.notifications n
        where n.user_id = p_user and n.group_key = p_group_key and not n.leido) then
      return null; -- mismo actor repitiendo la acción: no duplicar
    end if;
  end if;

  if v_id is null then
    insert into notifications.notifications (user_id, tipo, group_key, actor_ids, payload)
    values (p_user, p_tipo, p_group_key, case when p_actor is null then '{}' else array[p_actor] end, p_payload)
    returning id into v_id;
  end if;

  if notifications.wants_push(p_user, p_tipo) then
    perform pgmq.send('push', jsonb_build_object(
      'notification_id', v_id, 'user_id', p_user, 'tipo', p_tipo, 'actor_id', p_actor, 'payload', p_payload));
  end if;

  perform realtime.send(jsonb_build_object('notification_id', v_id, 'tipo', p_tipo),
    'notification.created', 'user:' || p_user::text, true);
  return v_id;
end;
$$;
revoke execute on function notifications.notify(uuid, notifications.tipo, uuid, jsonb, text) from public, authenticated, anon;
grant execute on function notifications.notify(uuid, notifications.tipo, uuid, jsonb, text) to service_role;

-- Preferencias por defecto para cada socio nuevo.
create or replace function notifications.on_member_created()
returns trigger language plpgsql security definer set search_path = ''
as $$
begin
  insert into notifications.preferences (user_id) values (new.user_id) on conflict do nothing;
  return new;
end;
$$;
create trigger on_member_created_prefs after insert on identity.members
  for each row execute function notifications.on_member_created();

-- -----------------------------------------------------------------------------
-- Productores (triggers en otros módulos que solo llaman a notifications.notify).
-- -----------------------------------------------------------------------------
create or replace function notifications.on_follow()
returns trigger language plpgsql security definer set search_path = ''
as $$
begin
  perform notifications.notify(new.seguido_id, 'nuevo_seguidor', new.seguidor_id,
    jsonb_build_object('actor_id', new.seguidor_id), 'follow');
  return new;
end;
$$;
create trigger follows_notify after insert on social.follows
  for each row execute function notifications.on_follow();

create or replace function notifications.on_recommendation()
returns trigger language plpgsql security definer set search_path = ''
as $$
declare v_autor uuid;
begin
  select autor_id into v_autor from feed.posts where id = new.post_id;
  perform notifications.notify(v_autor, 'recomendacion', new.user_id,
    jsonb_build_object('post_id', new.post_id), 'reco:' || new.post_id::text);
  return new;
end;
$$;
create trigger recommendations_notify after insert on feed.recommendations
  for each row execute function notifications.on_recommendation();

create or replace function notifications.on_comment()
returns trigger language plpgsql security definer set search_path = ''
as $$
declare v_autor uuid;
begin
  select autor_id into v_autor from feed.posts where id = new.post_id;
  perform notifications.notify(v_autor, 'comentario', new.autor_id,
    jsonb_build_object('post_id', new.post_id, 'comment_id', new.id), 'comment:' || new.post_id::text);
  return new;
end;
$$;
create trigger comments_notify after insert on feed.comments
  for each row execute function notifications.on_comment();

-- Novedad oficial: notificación a todos los socios (5.000 máx. → inserción masiva directa).
create or replace function notifications.on_official_post()
returns trigger language plpgsql security definer set search_path = ''
as $$
begin
  if new.tipo = 'novedad_oficial' then
    insert into notifications.notifications (user_id, tipo, actor_ids, payload)
    select m.user_id, 'novedad', array[new.autor_id],
           jsonb_build_object('post_id', new.id, 'titulo', new.titulo)
      from identity.members m
     where m.status = 'active' and m.user_id <> new.autor_id;
    perform pgmq.send('push', jsonb_build_object('broadcast', 'novedad', 'post_id', new.id, 'titulo', new.titulo));
  end if;
  return new;
end;
$$;
create trigger posts_official_notify after insert on feed.posts
  for each row execute function notifications.on_official_post();

-- Consumo de colas por las Edge Functions (service_role).
create or replace function notifications.dequeue(p_queue text, p_qty int default 50, p_vt int default 60)
returns table (msg_id bigint, read_ct int, message jsonb)
language sql security definer set search_path = ''
as $$ select r.msg_id, r.read_ct, r.message from pgmq.read(p_queue, p_vt, p_qty) r; $$;

create or replace function notifications.ack(p_queue text, p_ids bigint[])
returns int language sql security definer set search_path = ''
as $$ select count(*)::int from pgmq.delete(p_queue, p_ids); $$;

revoke execute on function notifications.dequeue(text, int, int), notifications.ack(text, bigint[]) from public, authenticated, anon;
grant execute on function notifications.dequeue(text, int, int), notifications.ack(text, bigint[]) to service_role;
