-- =============================================================================
-- ICEX Atlas · 0900 · orientador (pgvector), moderation (denuncias), config (flags)
-- =============================================================================

-- ---------------------------------------------------------------- config ------
create table config.app_config (
  key         text primary key check (key ~ '^[a-z0-9_.]{2,64}$'),
  value       jsonb not null,
  descripcion text,
  updated_at  timestamptz not null default now()
);
alter table config.app_config enable row level security;
create trigger app_config_touch before update on config.app_config for each row execute function util.touch_updated_at();
create policy app_config_read on config.app_config for select to authenticated using ((select identity.is_member()));
create policy app_config_admin on config.app_config for all to authenticated
  using ((select identity.is_admin())) with check ((select identity.is_admin()));
grant select, insert, update, delete on config.app_config to authenticated;
grant all on config.app_config to service_role;

insert into config.app_config (key, value, descripcion) values
  ('orientador.enabled', 'true', 'Activa el Orientador con IA'),
  ('orientador.daily_limit', '10', 'Consultas por socio y día'),
  ('feed.page_size', '20', 'Tamaño de página del feed'),
  ('map.tile_url', '"https://tile.openstreetmap.org/{z}/{x}/{y}.png"', 'Proveedor de teselas (respeta la política de uso de OSM)'),
  ('map.tile_attribution', '"© OpenStreetMap contributors"', 'Atribución obligatoria del proveedor de teselas'),
  ('community.stats_override', 'null', 'Cifras oficiales de la asociación (alumni, activos, países, promociones). null = calcular');

create or replace function config.get(p_key text, p_default jsonb default null)
returns jsonb language sql stable security definer set search_path = ''
as $$ select coalesce((select c.value from config.app_config c where c.key = p_key), p_default); $$;
grant execute on function config.get(text, jsonb) to authenticated, service_role;

-- ------------------------------------------------------------- orientador -----
create type orientador.source_tipo as enum ('post', 'perfil', 'guia');

create table orientador.documents (
  id           uuid primary key default util.uuid_v7(),
  source_tipo  orientador.source_tipo not null,
  source_id    uuid not null,
  user_id      uuid references identity.members (user_id) on delete cascade,   -- dueño (perfil/post)
  pais         text,
  sector       text,
  fase         text,
  contenido    text not null,
  embedding    extensions.vector(384),
  updated_at   timestamptz not null default now(),
  unique (source_tipo, source_id)
);
create index documents_embedding_hnsw on orientador.documents using hnsw (embedding extensions.vector_cosine_ops);
create index documents_user_idx on orientador.documents (user_id);

create table orientador.queries (
  id          uuid primary key default util.uuid_v7(),
  user_id     uuid not null references identity.members (user_id) on delete cascade,
  fase        text,
  pais        text,
  sector      text,
  consulta    text not null check (char_length(consulta) <= 2000),
  respuesta   jsonb,
  proveedor   text,
  created_at  timestamptz not null default now()
);
comment on table orientador.queries is 'Consultas al Orientador. Se borran automáticamente a los 30 días (cron orientador-purge).';
create index queries_user_day_idx on orientador.queries (user_id, created_at desc);
create index queries_created_idx on orientador.queries (created_at);

alter table orientador.documents enable row level security;
alter table orientador.queries enable row level security;

-- documents: no accesible a clientes (solo vía funciones definer que filtran consentimiento).
create policy documents_service_only on orientador.documents for select to authenticated using (false);
create policy queries_own on orientador.queries for select to authenticated
  using (user_id = (select auth.uid()) and (select identity.is_member()));
create policy queries_delete_own on orientador.queries for delete to authenticated
  using (user_id = (select auth.uid()) and (select identity.is_member()));
grant select, delete on orientador.queries to authenticated;
grant all on orientador.documents, orientador.queries to service_role;

-- Encolar reindexado cuando cambian posts o perfiles.
create or replace function orientador.enqueue_post()
returns trigger language plpgsql security definer set search_path = ''
as $$
begin
  if tg_op = 'DELETE' then
    delete from orientador.documents where source_tipo = 'post' and source_id = old.id;
    return old;
  end if;
  if new.oculto then
    delete from orientador.documents where source_tipo = 'post' and source_id = new.id;
  else
    perform pgmq.send('embeddings', jsonb_build_object('source_tipo', 'post', 'source_id', new.id));
  end if;
  return new;
end;
$$;
create trigger posts_enqueue_embedding after insert or update of texto, oculto or delete on feed.posts
  for each row execute function orientador.enqueue_post();

create or replace function orientador.enqueue_profile()
returns trigger language plpgsql security definer set search_path = ''
as $$
begin
  if not new.acepta_sugerencias then
    delete from orientador.documents where source_tipo = 'perfil' and source_id = new.user_id;
  else
    perform pgmq.send('embeddings', jsonb_build_object('source_tipo', 'perfil', 'source_id', new.user_id));
  end if;
  return new;
end;
$$;
create trigger profiles_enqueue_embedding after insert or update of cargo, empresa, sector, pais, ciudad, bio, fase, acepta_sugerencias
  on profiles.profiles for each row execute function orientador.enqueue_profile();

-- Texto canónico a indexar (lo usa el indexador).
create or replace function orientador.source_text(p_tipo orientador.source_tipo, p_id uuid)
returns table (user_id uuid, contenido text, pais text, sector text, fase text)
language sql stable security definer set search_path = ''
as $$
  select p.autor_id, p.texto, pr.pais, pr.sector, pr.fase::text
    from feed.posts p join profiles.profiles pr on pr.user_id = p.autor_id
   where p_tipo = 'post' and p.id = p_id and not p.oculto and p.visibilidad = 'socios' and pr.acepta_sugerencias
  union all
  select pr.user_id,
         concat_ws('. ', pr.nombre, pr.cargo, pr.empresa, pr.sector, pr.ciudad, pr.pais, pr.bio,
                   'Fase ' || pr.fase::text, pr.promocion || 'ª promoción'),
         pr.pais, pr.sector, pr.fase::text
    from profiles.profiles pr
   where p_tipo = 'perfil' and pr.user_id = p_id and pr.acepta_sugerencias;
$$;

create or replace function orientador.upsert_document(
  p_tipo orientador.source_tipo, p_id uuid, p_embedding extensions.vector(384))
returns void language plpgsql security definer set search_path = ''
as $$
declare r record;
begin
  select * into r from orientador.source_text(p_tipo, p_id);
  if r is null or r.contenido is null then
    delete from orientador.documents where source_tipo = p_tipo and source_id = p_id;
    return;
  end if;
  insert into orientador.documents (source_tipo, source_id, user_id, pais, sector, fase, contenido, embedding, updated_at)
  values (p_tipo, p_id, r.user_id, r.pais, r.sector, r.fase, r.contenido, p_embedding, now())
  on conflict (source_tipo, source_id) do update
    set contenido = excluded.contenido, embedding = excluded.embedding, pais = excluded.pais,
        sector = excluded.sector, fase = excluded.fase, user_id = excluded.user_id, updated_at = now();
end;
$$;

revoke execute on all functions in schema orientador from public, authenticated, anon;
grant execute on all functions in schema orientador to service_role;

-- ------------------------------------------------------------- moderation -----
create type moderation.target_tipo as enum ('post', 'comentario', 'perfil', 'mensaje');
create type moderation.motivo as enum ('spam', 'acoso', 'contenido_inapropiado', 'datos_personales', 'suplantacion', 'otro');
create type moderation.estado as enum ('pendiente', 'en_revision', 'accion_tomada', 'descartada');

create table moderation.reports (
  id            uuid primary key default util.uuid_v7(),
  reporter_id   uuid references identity.members (user_id) on delete set null,
  target_tipo   moderation.target_tipo not null,
  target_id     uuid not null,
  target_owner  uuid references identity.members (user_id) on delete set null,
  motivo        moderation.motivo not null,
  detalle       text check (char_length(detalle) <= 1000),
  estado        moderation.estado not null default 'pendiente',
  resolucion    text,
  resuelto_por  uuid references identity.members (user_id) on delete set null,
  resuelto_en   timestamptz,
  created_at    timestamptz not null default now()
);
create index reports_estado_idx on moderation.reports (estado, created_at);
create unique index reports_once_uidx on moderation.reports (reporter_id, target_tipo, target_id) where estado = 'pendiente';

alter table moderation.reports enable row level security;
create policy reports_insert_member on moderation.reports for insert to authenticated
  with check (reporter_id = (select auth.uid()) and (select identity.is_member()) and estado = 'pendiente');
create policy reports_select on moderation.reports for select to authenticated
  using ((reporter_id = (select auth.uid()) and (select identity.is_member())) or (select identity.is_moderator()));
create policy reports_update_mod on moderation.reports for update to authenticated
  using ((select identity.is_moderator())) with check ((select identity.is_moderator()));
grant select, insert on moderation.reports to authenticated;
grant update (estado, resolucion, resuelto_por, resuelto_en) on moderation.reports to authenticated;
grant all on moderation.reports to service_role;
