-- =============================================================================
-- ICEX Atlas · 0400 · social: seguidores, bloqueos, sugerencias
-- =============================================================================

create table social.follows (
  seguidor_id  uuid not null references identity.members (user_id) on delete cascade,
  seguido_id   uuid not null references identity.members (user_id) on delete cascade,
  created_at   timestamptz not null default now(),
  primary key (seguidor_id, seguido_id),
  check (seguidor_id <> seguido_id)
);
create index follows_inverse_idx on social.follows (seguido_id, seguidor_id);

create table social.blocks (
  bloqueador_id uuid not null references identity.members (user_id) on delete cascade,
  bloqueado_id  uuid not null references identity.members (user_id) on delete cascade,
  created_at    timestamptz not null default now(),
  primary key (bloqueador_id, bloqueado_id),
  check (bloqueador_id <> bloqueado_id)
);
create index blocks_inverse_idx on social.blocks (bloqueado_id, bloqueador_id);

alter table social.follows enable row level security;
alter table social.blocks enable row level security;

-- -----------------------------------------------------------------------------
-- Interfaz pública del módulo (otros módulos solo usan estas funciones).
-- -----------------------------------------------------------------------------
create or replace function social.is_blocked_between(p_a uuid, p_b uuid)
returns boolean language sql stable security definer set search_path = ''
as $$
  select exists (
    select 1 from social.blocks b
    where (b.bloqueador_id = p_a and b.bloqueado_id = p_b)
       or (b.bloqueador_id = p_b and b.bloqueado_id = p_a));
$$;

create or replace function social.follows_user(p_follower uuid, p_target uuid)
returns boolean language sql stable security definer set search_path = ''
as $$
  select exists (select 1 from social.follows f where f.seguidor_id = p_follower and f.seguido_id = p_target);
$$;

-- Ids que sigue el usuario actual (para el timeline).
create or replace function social.my_followed_ids()
returns setof uuid language sql stable security definer set search_path = ''
as $$ select f.seguido_id from social.follows f where f.seguidor_id = (select auth.uid()); $$;

-- Ids con bloqueo en cualquier sentido respecto al usuario actual.
create or replace function social.my_blocked_ids()
returns setof uuid language sql stable security definer set search_path = ''
as $$
  select b.bloqueado_id from social.blocks b where b.bloqueador_id = (select auth.uid())
  union
  select b.bloqueador_id from social.blocks b where b.bloqueado_id = (select auth.uid());
$$;

grant execute on all functions in schema social to authenticated, service_role;

-- RLS
create policy follows_select_members on social.follows for select to authenticated
  using ((select identity.is_member()));
create policy follows_insert_own on social.follows for insert to authenticated
  with check (
    seguidor_id = (select auth.uid())
    and (select identity.is_member())
    and identity.is_member_id(seguido_id)
    and not social.is_blocked_between(seguidor_id, seguido_id));
create policy follows_delete_own on social.follows for delete to authenticated
  using (seguidor_id = (select auth.uid()) and (select identity.is_member()));

-- Los bloqueos solo los ve quien bloquea.
create policy blocks_select_own on social.blocks for select to authenticated
  using (bloqueador_id = (select auth.uid()) and (select identity.is_member()));
create policy blocks_insert_own on social.blocks for insert to authenticated
  with check (bloqueador_id = (select auth.uid()) and (select identity.is_member()));
create policy blocks_delete_own on social.blocks for delete to authenticated
  using (bloqueador_id = (select auth.uid()) and (select identity.is_member()));

grant select, insert, delete on social.follows, social.blocks to authenticated;
grant all on social.follows, social.blocks to service_role;

-- -----------------------------------------------------------------------------
-- Contadores desnormalizados (seguidores/siguiendo) mantenidos por triggers.
-- -----------------------------------------------------------------------------
create or replace function social.on_follow_change()
returns trigger language plpgsql security definer set search_path = ''
as $$
begin
  if tg_op = 'INSERT' then
    update profiles.profiles set siguiendo_count = siguiendo_count + 1 where user_id = new.seguidor_id;
    update profiles.profiles set seguidores_count = seguidores_count + 1 where user_id = new.seguido_id;
    return new;
  else
    update profiles.profiles set siguiendo_count = greatest(siguiendo_count - 1, 0) where user_id = old.seguidor_id;
    update profiles.profiles set seguidores_count = greatest(seguidores_count - 1, 0) where user_id = old.seguido_id;
    return old;
  end if;
end;
$$;
create trigger follows_counts after insert or delete on social.follows
  for each row execute function social.on_follow_change();

-- Bloquear deshace el seguimiento en ambos sentidos.
create or replace function social.on_block_created()
returns trigger language plpgsql security definer set search_path = ''
as $$
begin
  delete from social.follows
   where (seguidor_id = new.bloqueador_id and seguido_id = new.bloqueado_id)
      or (seguidor_id = new.bloqueado_id and seguido_id = new.bloqueador_id);
  return new;
end;
$$;
create trigger blocks_unfollow after insert on social.blocks
  for each row execute function social.on_block_created();
