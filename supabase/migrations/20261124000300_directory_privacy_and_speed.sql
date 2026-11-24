-- =============================================================================
-- ICEX Atlas · 20261124-0300 · Directorio: privacidad y velocidad
--  1. PRIVACIDAD: la columna de búsqueda incluía empresa, cargo y ciudad aunque el socio los
--     hubiera ocultado. Buscando «Iberdrola» aparecía quien había ocultado que trabaja allí.
--     Ahora solo se indexa lo que todos los socios pueden ver.
--  2. Bajas: los perfiles de socios dados de baja seguían en el directorio.
--  3. Velocidad: con RLS el índice trigram no se puede usar (LIKE no es «leakproof») y la
--     condición «not exists … not like» tampoco lo permitía. Ahora la función filtra por sí
--     misma (SECURITY DEFINER, exige socio) y usa el índice con el término más largo.
-- =============================================================================

drop index if exists profiles.profiles_busqueda_trgm_idx;
alter table profiles.profiles drop column busqueda;
alter table profiles.profiles add column busqueda text generated always as (
  util.normalize(
    nombre
    || case when coalesce(visibilidad ->> 'empresa', 'socios') = 'socios' then ' ' || coalesce(empresa, '') else '' end
    || case when coalesce(visibilidad ->> 'ciudad', 'socios') = 'socios' then ' ' || coalesce(ciudad, '') else '' end
    || case when coalesce(visibilidad ->> 'cargo', 'socios') = 'socios' then ' ' || coalesce(cargo, '') else '' end
    || ' ' || coalesce(pais, '') || ' ' || promocion::text || 'ª')
) stored;
create index profiles_busqueda_trgm_idx on profiles.profiles using gin (busqueda extensions.gin_trgm_ops);

create or replace function api.search_directory(
  p_query text default null, p_promocion int default null, p_fase profiles.fase default null,
  p_tab text default 'todos', p_cursor text default null, p_limit int default 24)
returns jsonb language plpgsql stable security definer set search_path = ''
as $$
declare
  v_uid uuid := identity.require_member();
  v_my_promo int;
  v_tokens text[];
  v_longest text;
  v_blocked uuid[];
  v_limit int := least(greatest(coalesce(p_limit, 24), 1), 50);
  v_c_nombre text := nullif(split_part(coalesce(p_cursor, ''), chr(31), 1), '');
  v_c_id uuid := nullif(split_part(coalesce(p_cursor, ''), chr(31), 2), '')::uuid;
  v_items jsonb;
  v_total int;
  v_page_n int;
begin
  if p_tab = 'mi_promocion' then
    select promocion into v_my_promo from profiles.profiles where user_id = v_uid;
  end if;
  v_tokens := array_remove(regexp_split_to_array(util.normalize(trim(coalesce(p_query, ''))), '\s+'), '');
  select t into v_longest from unnest(v_tokens) t order by char_length(t) desc limit 1;
  select coalesce(array_agg(b), '{}') into v_blocked from social.my_blocked_ids() b;

  with hits as (
    select p.user_id, p.nombre
      from profiles.profiles p
      join identity.members m on m.user_id = p.user_id and m.status = 'active'
     where (v_longest is null or p.busqueda like '%' || v_longest || '%')   -- índice trigram
       and (cardinality(v_tokens) <= 1 or not exists (
              select 1 from unnest(v_tokens) t where p.busqueda not like '%' || t || '%'))
       and (p_promocion is null or p.promocion = p_promocion)
       and (p_fase is null or p.fase = p_fase)
       and (coalesce(p_tab, 'todos') <> 'mi_promocion' or p.promocion = v_my_promo)
       and (coalesce(p_tab, 'todos') <> 'exterior' or p.en_el_exterior)
       and (coalesce(p_tab, 'todos') <> 'activo' or p.fase = 'activo')
       and p.user_id <> all (v_blocked)),
  page as (
    select h.user_id, h.nombre from hits h
     where v_c_nombre is null or (h.nombre, h.user_id) > (v_c_nombre, v_c_id)
     order by h.nombre, h.user_id
     limit v_limit + 1)
  select (select count(*) from hits),
         (select count(*) from page),
         (select coalesce(jsonb_agg(
                   profiles.card(p, v_uid, f.f) || jsonb_build_object('is_following', f.f)
                   order by p.nombre, p.user_id), '[]'::jsonb)
            from (select * from page order by nombre, user_id limit v_limit) pg
            join profiles.profiles p on p.user_id = pg.user_id
            cross join lateral (select social.follows_user(v_uid, p.user_id) as f) f)
    into v_total, v_page_n, v_items;

  return jsonb_build_object(
    'items', v_items,
    'total', v_total,
    'next_cursor', case when v_page_n > v_limit
                     then (v_items -> (v_limit - 1) ->> 'nombre') || chr(31) || (v_items -> (v_limit - 1) ->> 'user_id') end);
end;
$$;
