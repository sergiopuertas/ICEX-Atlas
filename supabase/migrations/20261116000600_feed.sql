-- =============================================================================
-- ICEX Atlas · 0600 · feed: publicaciones, comentarios, recomendaciones, novedades
-- =============================================================================

create type feed.post_tipo as enum ('general', 'evento', 'oportunidad_laboral', 'logro', 'novedad_oficial');
create type feed.post_visibilidad as enum ('socios', 'seguidores');

create table feed.posts (
  id                      uuid primary key default util.uuid_v7(),
  autor_id                uuid not null references identity.members (user_id) on delete cascade,
  tipo                    feed.post_tipo not null default 'general',
  titulo                  text check (char_length(titulo) <= 200),        -- novedades oficiales
  etiqueta                text check (char_length(etiqueta) <= 40),       -- "Clubs", "Empleo"… (novedades)
  texto                   text not null check (char_length(texto) between 1 and 5000),
  media                   text[] not null default '{}' check (cardinality(media) <= 4),
  visibilidad             feed.post_visibilidad not null default 'socios',
  club_id                 uuid references clubs.clubs (id) on delete set null,
  compartido_de           uuid references feed.posts (id) on delete set null,
  fijado                  boolean not null default false,
  oculto                  boolean not null default false,                 -- moderación
  recomendaciones_count   integer not null default 0 check (recomendaciones_count >= 0),
  comentarios_count       integer not null default 0 check (comentarios_count >= 0),
  compartidos_count       integer not null default 0 check (compartidos_count >= 0),
  created_at              timestamptz not null default now(),
  updated_at              timestamptz not null default now(),
  check (tipo <> 'novedad_oficial' or titulo is not null)
);
-- Índice principal del timeline (fan-out on read): posts de un autor por fecha.
create index posts_autor_created_idx on feed.posts (autor_id, created_at desc, id desc) where not oculto;
create index posts_club_created_idx on feed.posts (club_id, created_at desc, id desc) where club_id is not null and not oculto;
create index posts_novedades_idx on feed.posts (fijado desc, created_at desc, id desc)
  where tipo = 'novedad_oficial' and not oculto;
create index posts_created_idx on feed.posts (created_at desc, id desc) where not oculto;
create trigger posts_touch before update on feed.posts for each row execute function util.touch_updated_at();

create table feed.comments (
  id          uuid primary key default util.uuid_v7(),
  post_id     uuid not null references feed.posts (id) on delete cascade,
  autor_id    uuid not null references identity.members (user_id) on delete cascade,
  texto       text not null check (char_length(texto) between 1 and 2000),
  oculto      boolean not null default false,
  created_at  timestamptz not null default now()
);
create index comments_post_idx on feed.comments (post_id, created_at, id);

-- «Recomendar» es la reacción de ICEX Atlas.
create table feed.recommendations (
  post_id     uuid not null references feed.posts (id) on delete cascade,
  user_id     uuid not null references identity.members (user_id) on delete cascade,
  created_at  timestamptz not null default now(),
  primary key (post_id, user_id)
);
create index recommendations_user_idx on feed.recommendations (user_id, created_at desc);

-- Preparada para fan-out on write (D-010). NO se usa en la fase 1.
create table feed.feed_items (
  user_id     uuid not null references identity.members (user_id) on delete cascade,
  post_id     uuid not null references feed.posts (id) on delete cascade,
  created_at  timestamptz not null,
  primary key (user_id, created_at, post_id)
);
comment on table feed.feed_items is 'Inactiva. Reservada para fan-out on write si el volumen lo exige (docs/decisiones.md D-010).';

alter table feed.posts enable row level security;
alter table feed.comments enable row level security;
alter table feed.recommendations enable row level security;
alter table feed.feed_items enable row level security;

-- -----------------------------------------------------------------------------
-- Interfaz pública: ¿puede el usuario actual ver este post?
-- -----------------------------------------------------------------------------
create or replace function feed.can_view(p feed.posts)
returns boolean language sql stable set search_path = ''
as $$
  select (select identity.is_member())
     and (not p.oculto or p.autor_id = (select auth.uid()) or (select identity.is_moderator()))
     and not social.is_blocked_between((select auth.uid()), p.autor_id)
     and (p.visibilidad = 'socios'
          or p.autor_id = (select auth.uid())
          or social.follows_user((select auth.uid()), p.autor_id));
$$;

create or replace function feed.can_view_post(p_post uuid)
returns boolean language sql stable security definer set search_path = ''
as $$ select coalesce((select feed.can_view(p) from feed.posts p where p.id = p_post), false); $$;

grant execute on all functions in schema feed to authenticated, service_role;

-- Posts
create policy posts_select on feed.posts for select to authenticated using (feed.can_view(posts));
create policy posts_insert on feed.posts for insert to authenticated
  with check (
    autor_id = (select auth.uid())
    and (select identity.is_member())
    and (tipo <> 'novedad_oficial' or (select identity.is_admin()))
    and (not fijado or (select identity.is_admin())));
create policy posts_update_own on feed.posts for update to authenticated
  using (autor_id = (select auth.uid()) and (select identity.is_member()))
  with check (autor_id = (select auth.uid()) and (tipo <> 'novedad_oficial' or (select identity.is_admin())));
create policy posts_moderate on feed.posts for update to authenticated
  using ((select identity.is_moderator())) with check ((select identity.is_moderator()));
create policy posts_delete on feed.posts for delete to authenticated
  using ((autor_id = (select auth.uid()) and (select identity.is_member())) or (select identity.is_moderator()));

-- Comentarios: visibles si el post es visible.
create policy comments_select on feed.comments for select to authenticated
  using (feed.can_view_post(post_id) and (not oculto or autor_id = (select auth.uid()) or (select identity.is_moderator()))
         and not social.is_blocked_between((select auth.uid()), autor_id));
create policy comments_insert on feed.comments for insert to authenticated
  with check (autor_id = (select auth.uid()) and (select identity.is_member()) and feed.can_view_post(post_id));
create policy comments_delete on feed.comments for delete to authenticated
  using ((autor_id = (select auth.uid()) and (select identity.is_member())) or (select identity.is_moderator()));
create policy comments_moderate on feed.comments for update to authenticated
  using ((select identity.is_moderator())) with check ((select identity.is_moderator()));

-- Recomendaciones
create policy recommendations_select on feed.recommendations for select to authenticated
  using ((select identity.is_member()) and feed.can_view_post(post_id));
create policy recommendations_insert on feed.recommendations for insert to authenticated
  with check (user_id = (select auth.uid()) and (select identity.is_member()) and feed.can_view_post(post_id));
create policy recommendations_delete on feed.recommendations for delete to authenticated
  using (user_id = (select auth.uid()) and (select identity.is_member()));

-- feed_items: solo lectura propia (inactiva).
create policy feed_items_select_own on feed.feed_items for select to authenticated
  using (user_id = (select auth.uid()) and (select identity.is_member()));

grant select, insert, update, delete on feed.posts, feed.comments to authenticated;
grant select, insert, delete on feed.recommendations to authenticated;
grant select on feed.feed_items to authenticated;
grant all on all tables in schema feed to service_role;

-- -----------------------------------------------------------------------------
-- Contadores
-- -----------------------------------------------------------------------------
create or replace function feed.on_recommendation_change()
returns trigger language plpgsql security definer set search_path = ''
as $$
begin
  if tg_op = 'INSERT' then
    update feed.posts set recomendaciones_count = recomendaciones_count + 1 where id = new.post_id; return new;
  else
    update feed.posts set recomendaciones_count = greatest(recomendaciones_count - 1, 0) where id = old.post_id; return old;
  end if;
end;
$$;
create trigger recommendations_counts after insert or delete on feed.recommendations
  for each row execute function feed.on_recommendation_change();

create or replace function feed.on_comment_change()
returns trigger language plpgsql security definer set search_path = ''
as $$
begin
  if tg_op = 'INSERT' then
    update feed.posts set comentarios_count = comentarios_count + 1 where id = new.post_id; return new;
  else
    update feed.posts set comentarios_count = greatest(comentarios_count - 1, 0) where id = old.post_id; return old;
  end if;
end;
$$;
create trigger comments_counts after insert or delete on feed.comments
  for each row execute function feed.on_comment_change();

create or replace function feed.on_post_change()
returns trigger language plpgsql security definer set search_path = ''
as $$
begin
  if tg_op = 'INSERT' then
    update profiles.profiles set posts_count = posts_count + 1 where user_id = new.autor_id;
    if new.compartido_de is not null then
      update feed.posts set compartidos_count = compartidos_count + 1 where id = new.compartido_de;
    end if;
    return new;
  else
    update profiles.profiles set posts_count = greatest(posts_count - 1, 0) where user_id = old.autor_id;
    if old.compartido_de is not null then
      update feed.posts set compartidos_count = greatest(compartidos_count - 1, 0) where id = old.compartido_de;
    end if;
    return old;
  end if;
end;
$$;
create trigger posts_counts after insert or delete on feed.posts
  for each row execute function feed.on_post_change();
