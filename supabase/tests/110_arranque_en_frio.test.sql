-- Arranque en frío: sugerencias y «destacado en la comunidad» para quien acaba de llegar.
begin;
\ir helpers.inc
select plan(19);

create function pg_temp.sug(p_limit int default 20) returns jsonb language sql as $$ select api.suggestions(p_limit) $$;
create function pg_temp.sug_ids(p_limit int default 20) returns uuid[] language sql as $$
  select coalesce(array_agg((s ->> 'user_id')::uuid order by o), '{}')
    from jsonb_array_elements(api.suggestions(p_limit)) with ordinality as x(s, o) $$;
create function pg_temp.hl_ids(p_limit int default 20) returns uuid[] language sql as $$
  select coalesce(array_agg((h ->> 'id')::uuid order by o), '{}')
    from jsonb_array_elements(api.community_highlights(p_limit)) with ordinality as x(h, o) $$;
create function pg_temp.post(p_autor uuid, p_texto text, p_vis feed.post_visibilidad default 'socios')
returns uuid language sql as $$
  insert into feed.posts (autor_id, texto, visibilidad) values (p_autor, p_texto, p_vis) returning id $$;

-- Recién llegada de la beta: sin promoción, sin ciudad, sin empresa, no sigue a nadie.
select tests.create_member('Nueva Beta') as nueva \gset
update profiles.profiles set promocion = 0, ciudad = null, empresa = null, sector = null where user_id = :'nueva';
select tests.create_member('Muy Seguida') as popular \gset
select tests.create_member('Oculta Popular') as oculta \gset
select tests.create_member('Suspendida Popular') as suspendida \gset
select tests.create_member('Bloqueada Popular') as bloqueada \gset
select tests.create_member('Otra Sin Promo') as sinpromo \gset
update profiles.profiles set seguidores_count = 900000 where user_id = :'popular';
update profiles.profiles set seguidores_count = 950000, acepta_sugerencias = false where user_id = :'oculta';
update profiles.profiles set seguidores_count = 960000 where user_id = :'suspendida';
update identity.members set status = 'suspended' where user_id = :'suspendida';
update profiles.profiles set seguidores_count = 970000 where user_id = :'bloqueada';
update profiles.profiles set promocion = 0, ciudad = null, empresa = null, sector = null where user_id = :'sinpromo';

select tests.authenticate_as(:'nueva');
select api.block(:'bloqueada');

-- ------------------------------------------------------------- sugerencias ---
select is(jsonb_array_length(pg_temp.sug(5)), 5, 'sin coincidencias, también hay 5 sugerencias (las más seguidas)');
select is((pg_temp.sug_ids(5))[1], :'popular'::uuid, 'la persona más seguida va primero si no hay coincidencias');
select ok(not (:'oculta'::uuid = any (pg_temp.sug_ids())), 'quien no acepta sugerencias no sale aunque sea popular');
select ok(not (:'suspendida'::uuid = any (pg_temp.sug_ids())), 'una cuenta suspendida no sale');
select ok(not (:'bloqueada'::uuid = any (pg_temp.sug_ids())), 'alguien bloqueado no sale');
select ok(not (:'nueva'::uuid = any (pg_temp.sug_ids())), 'una no se sugiere a sí misma');
select is(coalesce((select (s ->> 'score')::int from jsonb_array_elements(pg_temp.sug()) s
                     where s ->> 'user_id' = :'sinpromo'), 0), 0,
  '«sin promoción» no cuenta como coincidencia de promoción');

select tests.clear_authentication();
update profiles.profiles set ciudad = 'Villaprueba del Test' where user_id = :'nueva';
select tests.create_member('Vecina de Lima') as lima \gset
update profiles.profiles set ciudad = 'Villaprueba del Test', seguidores_count = 0 where user_id = :'lima';
select tests.authenticate_as(:'nueva');
select is((pg_temp.sug_ids(5))[1], :'lima'::uuid, 'una coincidencia (misma ciudad) va antes que la más seguida');

select api.follow(:'popular');
select ok(not (:'popular'::uuid = any (pg_temp.sug_ids())), 'a quien ya sigues no se le sugiere');

-- --------------------------------------------------- destacado en la comunidad ---
select tests.clear_authentication();
select tests.create_member('Autora Activa') as autora \gset
select tests.create_member('Autora Reservada') as reservada \gset
update profiles.profiles set acepta_sugerencias = false where user_id = :'reservada';
select pg_temp.post(:'autora', 'Post con mucha conversación') as p_viral \gset
select pg_temp.post(:'autora', 'Post tranquilo') as p_tranquilo \gset
select pg_temp.post(:'autora', 'Tercer post de la misma autora') as p_tercero \gset
update feed.posts set recomendaciones_count = 40, comentarios_count = 10 where id = :'p_viral';
update feed.posts set created_at = now() - interval '1 hour' where id = :'p_tranquilo';
update feed.posts set created_at = now() - interval '2 hours' where id = :'p_tercero';
select pg_temp.post(:'popular', 'De alguien a quien ya sigo') as p_seguido \gset
select pg_temp.post(:'nueva', 'Mío') as p_mio \gset
select pg_temp.post(:'autora', 'Solo para seguidores', 'seguidores') as p_privado \gset
select pg_temp.post(:'bloqueada', 'De alguien bloqueado') as p_bloqueado \gset
select pg_temp.post(:'reservada', 'De quien no quiere aparecer') as p_reservado \gset
select pg_temp.post(:'lima', 'Antiguo') as p_antiguo \gset
update feed.posts set created_at = now() - interval '31 days' where id = :'p_antiguo';

select tests.authenticate_as(:'nueva');
select ok(:'p_viral'::uuid = any (pg_temp.hl_ids()), 'sale lo de gente a la que no sigo');
select ok((select array_position(pg_temp.hl_ids(), :'p_viral'::uuid) < array_position(pg_temp.hl_ids(), :'p_tranquilo'::uuid)),
  'con más recomendaciones y comentarios, más arriba');
select is((select count(*)::int from unnest(pg_temp.hl_ids()) i where i in (:'p_viral', :'p_tranquilo', :'p_tercero')), 2,
  'como mucho dos publicaciones por autora');
select ok(not (:'p_seguido'::uuid = any (pg_temp.hl_ids())), 'no repite lo que ya sale en mi feed (gente a la que sigo)');
select ok(not (:'p_mio'::uuid = any (pg_temp.hl_ids())), 'no muestra lo mío');
select ok(not (:'p_privado'::uuid = any (pg_temp.hl_ids())), 'no muestra posts solo para seguidores');
select ok(not (:'p_bloqueado'::uuid = any (pg_temp.hl_ids())), 'no muestra a alguien bloqueado');
select ok(not (:'p_reservado'::uuid = any (pg_temp.hl_ids())), 'no muestra a quien no acepta sugerencias');
select ok(not (:'p_antiguo'::uuid = any (pg_temp.hl_ids())), 'solo los últimos 30 días');

select tests.as_anon();
select throws_ok($$ select api.community_highlights(5) $$, '42501', null, 'sin sesión no se puede');

select * from finish();
rollback;
