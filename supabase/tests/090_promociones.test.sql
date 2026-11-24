-- Promoción en curso calculada cada año (no un número fijo en la app).
begin;
\ir helpers.inc
select plan(6);

select is(profiles.current_promocion(),
  extract(year from now() at time zone 'Europe/Madrid')::int - 1975,
  'promoción en curso = año − 1975 (2026 → 51ª)');

select tests.create_member('Nueva Promo', 'socio', profiles.current_promocion()) as nueva \gset
select tests.create_member('Veterana', 'socio', 30) as vete \gset
select is((select fase::text from profiles.profiles where user_id = :'nueva'), 'fase_0',
  'quien entra en la promoción en curso empieza en Fase 0');
select is((select fase::text from profiles.profiles where user_id = :'vete'), 'activo',
  'promociones anteriores: activo (si el IdP no dice otra cosa)');

select tests.authenticate_as(:'vete');
select is((api.community_stats() ->> 'promocion_actual')::int, profiles.current_promocion(),
  'la app recibe la promoción en curso con las cifras de la comunidad');

select tests.clear_authentication();
insert into config.app_config (key, value) values ('promociones.actual', '60')
  on conflict (key) do update set value = excluded.value;
select is(profiles.current_promocion(), 60, 'se puede fijar a mano sin desplegar');
select tests.create_member('Con fase del IdP', 'socio', 60) as idp \gset
select is((select fase::text from profiles.profiles where user_id = :'idp'), 'fase_0',
  'con el valor fijado a mano también entra en Fase 0');

select * from finish();
rollback;
