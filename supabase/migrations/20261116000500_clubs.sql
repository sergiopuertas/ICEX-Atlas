-- =============================================================================
-- ICEX Atlas · 0500 · clubs: clubs locales por ciudad, eventos e inscripciones
-- =============================================================================

create type clubs.club_rol as enum ('miembro', 'organizador');
create type clubs.inscripcion_estado as enum ('inscrito', 'lista_espera');

create table clubs.clubs (
  id              uuid primary key default util.uuid_v7(),
  nombre          text not null check (char_length(nombre) between 3 and 120),
  ciudad          text not null,
  pais            text not null,
  pais_code       char(2),
  ubicacion       extensions.geography(point, 4326) not null,
  descripcion     text check (char_length(descripcion) <= 2000),
  miembros_count  integer not null default 0 check (miembros_count >= 0),
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);
create index clubs_ubicacion_gix on clubs.clubs using gist (ubicacion);
create index clubs_ciudad_idx on clubs.clubs (pais, ciudad);
create trigger clubs_touch before update on clubs.clubs for each row execute function util.touch_updated_at();

create table clubs.club_members (
  club_id    uuid not null references clubs.clubs (id) on delete cascade,
  user_id    uuid not null references identity.members (user_id) on delete cascade,
  rol        clubs.club_rol not null default 'miembro',
  created_at timestamptz not null default now(),
  primary key (club_id, user_id)
);
create index club_members_user_idx on clubs.club_members (user_id, club_id);

create table clubs.events (
  id               uuid primary key default util.uuid_v7(),
  club_id          uuid not null references clubs.clubs (id) on delete cascade,
  titulo           text not null check (char_length(titulo) between 3 and 160),
  descripcion      text check (char_length(descripcion) <= 4000),
  inicio           timestamptz not null,
  fin              timestamptz,
  lugar            text,
  online_url       text,
  aforo            integer check (aforo is null or aforo > 0),
  inscritos_count  integer not null default 0 check (inscritos_count >= 0),
  created_by       uuid references identity.members (user_id) on delete set null,
  created_at       timestamptz not null default now(),
  check (fin is null or fin >= inicio)
);
create index events_club_inicio_idx on clubs.events (club_id, inicio);
create index events_inicio_idx on clubs.events (inicio);

create table clubs.event_attendees (
  event_id   uuid not null references clubs.events (id) on delete cascade,
  user_id    uuid not null references identity.members (user_id) on delete cascade,
  estado     clubs.inscripcion_estado not null default 'inscrito',
  created_at timestamptz not null default now(),
  primary key (event_id, user_id)
);
create index event_attendees_user_idx on clubs.event_attendees (user_id);

alter table clubs.clubs enable row level security;
alter table clubs.club_members enable row level security;
alter table clubs.events enable row level security;
alter table clubs.event_attendees enable row level security;

-- Interfaz pública
create or replace function clubs.is_organizer(p_club uuid)
returns boolean language sql stable security definer set search_path = ''
as $$
  select exists (select 1 from clubs.club_members cm
    where cm.club_id = p_club and cm.user_id = (select auth.uid()) and cm.rol = 'organizador')
    or identity.is_admin();
$$;

create or replace function clubs.my_club_ids()
returns setof uuid language sql stable security definer set search_path = ''
as $$ select cm.club_id from clubs.club_members cm where cm.user_id = (select auth.uid()); $$;

grant execute on all functions in schema clubs to authenticated, service_role;

-- RLS
create policy clubs_select on clubs.clubs for select to authenticated using ((select identity.is_member()));
create policy clubs_admin on clubs.clubs for all to authenticated
  using ((select identity.is_admin())) with check ((select identity.is_admin()));

create policy club_members_select on clubs.club_members for select to authenticated using ((select identity.is_member()));
create policy club_members_join on clubs.club_members for insert to authenticated
  with check (user_id = (select auth.uid()) and rol = 'miembro' and (select identity.is_member()));
create policy club_members_leave on clubs.club_members for delete to authenticated
  using ((user_id = (select auth.uid()) and (select identity.is_member())) or (select identity.is_admin()));
create policy club_members_admin on clubs.club_members for update to authenticated
  using ((select identity.is_admin())) with check ((select identity.is_admin()));

create policy events_select on clubs.events for select to authenticated using ((select identity.is_member()));
create policy events_write_organizer on clubs.events for insert to authenticated
  with check ((select identity.is_member()) and clubs.is_organizer(club_id) and created_by = (select auth.uid()));
create policy events_update_organizer on clubs.events for update to authenticated
  using (clubs.is_organizer(club_id)) with check (clubs.is_organizer(club_id));
create policy events_delete_organizer on clubs.events for delete to authenticated
  using (clubs.is_organizer(club_id));

-- Las inscripciones se gestionan solo con api.register_event (control de aforo);
-- la lectura: propias, o todas si eres organizador del club.
create policy attendees_select on clubs.event_attendees for select to authenticated
  using ((select identity.is_member()) and (user_id = (select auth.uid())
    or clubs.is_organizer((select e.club_id from clubs.events e where e.id = event_id))));
create policy attendees_delete_own on clubs.event_attendees for delete to authenticated
  using (user_id = (select auth.uid()) and (select identity.is_member()));

grant select on clubs.clubs, clubs.club_members, clubs.events, clubs.event_attendees to authenticated;
grant insert, delete on clubs.club_members to authenticated;
grant insert, update, delete on clubs.events to authenticated;
grant insert, update, delete on clubs.clubs to authenticated;
grant update on clubs.club_members to authenticated;
grant delete on clubs.event_attendees to authenticated;
grant all on all tables in schema clubs to service_role;

-- Contadores
create or replace function clubs.on_member_change()
returns trigger language plpgsql security definer set search_path = ''
as $$
begin
  if tg_op = 'INSERT' then
    update clubs.clubs set miembros_count = miembros_count + 1 where id = new.club_id; return new;
  else
    update clubs.clubs set miembros_count = greatest(miembros_count - 1, 0) where id = old.club_id; return old;
  end if;
end;
$$;
create trigger club_members_counts after insert or delete on clubs.club_members
  for each row execute function clubs.on_member_change();

create or replace function clubs.on_attendee_change()
returns trigger language plpgsql security definer set search_path = ''
as $$
begin
  if tg_op = 'INSERT' and new.estado = 'inscrito' then
    update clubs.events set inscritos_count = inscritos_count + 1 where id = new.event_id;
  elsif tg_op = 'DELETE' and old.estado = 'inscrito' then
    update clubs.events set inscritos_count = greatest(inscritos_count - 1, 0) where id = old.event_id;
    -- Promociona al primero de la lista de espera.
    update clubs.event_attendees a set estado = 'inscrito'
     where (a.event_id, a.user_id) = (
       select w.event_id, w.user_id from clubs.event_attendees w
        where w.event_id = old.event_id and w.estado = 'lista_espera'
        order by w.created_at limit 1);
  elsif tg_op = 'UPDATE' and old.estado = 'lista_espera' and new.estado = 'inscrito' then
    update clubs.events set inscritos_count = inscritos_count + 1 where id = new.event_id;
  end if;
  return coalesce(new, old);
end;
$$;
create trigger attendees_counts after insert or delete or update of estado on clubs.event_attendees
  for each row execute function clubs.on_attendee_change();
