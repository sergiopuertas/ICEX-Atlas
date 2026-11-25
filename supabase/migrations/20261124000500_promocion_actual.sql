-- =============================================================================
-- ICEX Atlas · 20261124-0500 · Promoción en curso calculada, no fija
-- Cada año entra una promoción nueva (en 2026, la 51ª, que está en Fase 0). Antes el máximo
-- estaba escrito a mano en la app (51) y había que acordarse de subirlo.
--   promoción en curso = año (hora de Madrid) − 1975       → 2026: 51 · 2027: 52 …
-- Si algún año cambia el calendario, se fija a mano sin desplegar:
--   update config.app_config set value = '52' where key = 'promociones.actual';  (o insert)
-- =============================================================================

create or replace function profiles.current_promocion()
returns int language sql stable security definer set search_path = ''
as $$
  select coalesce(
    (config.get('promociones.actual'))::text::int,
    extract(year from now() at time zone 'Europe/Madrid')::int - 1975);
$$;
grant execute on function profiles.current_promocion() to authenticated, service_role;

-- Alta: si el IdP no dice la fase, la promoción en curso empieza en Fase 0 (el resto, como
-- antes, «activo»). El dato del IdP manda siempre.
create or replace function profiles.on_member_created()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_meta jsonb;
  v_name text;
  v_promo int;
begin
  select coalesce(u.raw_user_meta_data, '{}'::jsonb) into v_meta from auth.users u where u.id = new.user_id;
  v_name := coalesce(nullif(v_meta ->> 'name', ''), nullif(v_meta -> 'custom_claims' ->> 'name', ''), 'Socio ICEX Alumni');
  v_promo := coalesce((v_meta -> 'custom_claims' ->> 'icex_promocion')::int, (v_meta ->> 'icex_promocion')::int, 1);
  insert into profiles.profiles (user_id, slug, nombre, promocion, fase)
  values (new.user_id, profiles.slugify(v_name, new.user_id), v_name, least(greatest(v_promo, 1), 99),
          coalesce((v_meta -> 'custom_claims' ->> 'icex_fase')::profiles.fase,
                   case when v_promo >= profiles.current_promocion() then 'fase_0'::profiles.fase
                        else 'activo'::profiles.fase end))
  on conflict (user_id) do nothing;
  return new;
end;
$$;

-- La app lee de aquí el número de promociones para sus filtros.
create or replace function api.community_stats()
returns jsonb language plpgsql stable security definer set search_path = ''
as $$
declare
  v_override jsonb;
  v_uid uuid := identity.require_member();
  v_stats jsonb;
begin
  v_override := config.get('community.stats_override');
  if v_override is not null and v_override <> 'null'::jsonb then
    v_stats := v_override;
  elsif profiles.aggregates_fresh() then
    v_stats := (select community_stats from profiles.aggregates_meta);
  else
    v_stats := (select jsonb_build_object(
      'alumni', count(*),
      'activos', count(*) filter (where p.fase = 'activo'),
      'paises', count(distinct p.pais_code),
      'promociones', count(distinct p.promocion))
      from profiles.profiles p
      join identity.members m on m.user_id = p.user_id and m.status = 'active');
  end if;
  return v_stats || jsonb_build_object('promocion_actual', profiles.current_promocion());
end;
$$;
