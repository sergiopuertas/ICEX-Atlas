-- Funcionales: directorio (pg_trgm), sugerencias, orientador (límite), RGPD, particiones UUIDv7.
begin;
\ir helpers.inc
select plan(23);

select user_id as ana from profiles.profiles where nombre = 'Ana Ortega Jiménez' \gset
select tests.authenticate_as(:'ana');

-- ------------------------------------------------------------- directorio ----
select ok((api.search_directory() ->> 'total')::int between 600 and 640, 'Directorio sin filtros devuelve la comunidad');
select is(jsonb_array_length(api.search_directory(p_limit => 24) -> 'items'), 24, 'Página de 24 (como el mockup)');
select ok(api.search_directory('jimenez ana') -> 'items' @> jsonb_build_array(jsonb_build_object('user_id', :'ana')),
  'Búsqueda insensible a tildes y al orden de palabras');
select ok((select bool_and((x ->> 'promocion')::int = 42) from jsonb_array_elements(api.search_directory(p_promocion => 42) -> 'items') x),
  'Filtro de promoción');
select ok((select bool_and(x ->> 'fase' = 'fase_1') from jsonb_array_elements(api.search_directory(p_fase => 'fase_1') -> 'items') x),
  'Filtro de fase');
select ok((select bool_and((x ->> 'promocion')::int = 49) from jsonb_array_elements(api.search_directory(p_tab => 'mi_promocion') -> 'items') x),
  'Pestaña "Mi promoción"');
select ok((select bool_and(x ->> 'pais' <> 'España') from jsonb_array_elements(api.search_directory(p_tab => 'exterior') -> 'items') x),
  'Pestaña "En el exterior"');
select ok(jsonb_array_length(api.search_directory('sener') -> 'items') >= 2, 'Busca por empresa');
select ok(jsonb_array_length(api.search_directory('singapur') -> 'items') >= 1, 'Busca por ciudad');
select is((with p1 as (select api.search_directory(p_limit => 10) j),
               p2 as (select api.search_directory(p_cursor => (select j ->> 'next_cursor' from p1), p_limit => 10) j)
           select count(*)::int from (select jsonb_array_elements(j -> 'items') ->> 'user_id' from p1
                                      intersect select jsonb_array_elements(j -> 'items') ->> 'user_id' from p2) x),
  0, 'Keyset del directorio sin solapes');

-- ----------------------------------------------------------- sugerencias -----
select is(jsonb_array_length(api.suggestions(5)), 5, 'Personas que quizá conozcas: 5 sugerencias');
select ok(not exists(select 1 from jsonb_array_elements(api.suggestions(20)) s
                      where social.follows_user(:'ana', (s ->> 'user_id')::uuid)), 'Nunca sugiere a quien ya sigues');

-- ------------------------------------------------------------- estadísticas --
select ok((api.community_stats() ->> 'alumni')::int >= 640, 'La comunidad en cifras: alumni');
select tests.clear_authentication();
update config.app_config set value = '{"alumni": 6340, "activos": 5120, "paises": 82, "promociones": 51}' where key = 'community.stats_override';
select tests.authenticate_as(:'ana');
select is((api.community_stats() ->> 'alumni')::int, 6340, 'Cifras oficiales configurables por la asociación');

-- ------------------------------------------------------------- orientador ----
select tests.clear_authentication();
update config.app_config set value = '2' where key = 'orientador.daily_limit';
delete from orientador.queries where user_id = :'ana';   -- independiente de ejecuciones previas
select tests.authenticate_as(:'ana');
select lives_ok($$select api.orientador_reserve(gen_random_uuid(), 'fase_1', 'Alemania', 'Energía', 'Entrevista Fase II')$$, 'Orientador: 1ª consulta');
select lives_ok($$select api.orientador_reserve(gen_random_uuid(), 'fase_1', 'Alemania', 'Energía', 'Otra')$$, 'Orientador: 2ª consulta');
select throws_ok($$select api.orientador_reserve(gen_random_uuid(), 'fase_1', 'Alemania', 'Energía', 'Tercera')$$, 'P0001', null,
  'Orientador: límite diario por socio');

-- ------------------------------------------------------------------- RGPD ----
select ok((api.export_my_data() -> 'perfil' ->> 'nombre') = 'Ana Ortega Jiménez', 'Exportación: incluye el perfil');
select ok(jsonb_array_length(api.export_my_data() -> 'mensajes_enviados') > 0, 'Exportación: incluye mensajes enviados');
select throws_ok($$select api.delete_my_account('si')$$, '22023', null, 'Borrado exige confirmación literal');
select tests.clear_authentication();
select tests.create_member('Se Va') as sevan \gset
select tests.create_member('Se Queda') as queda \gset
select tests.authenticate_as(:'sevan');
select api.create_post(gen_random_uuid(), 'adiós');
select api.send_message(util.uuid_v7(), 'mensaje a borrar', null, :'queda');
select api.follow(:'queda');
select lives_ok($$select api.delete_my_account('BORRAR MI CUENTA')$$, 'Borrado completo de la cuenta');
select tests.clear_authentication();
select ok(not exists(select 1 from auth.users where id = :'sevan')
          and not exists(select 1 from profiles.profiles where user_id = :'sevan')
          and not exists(select 1 from feed.posts where autor_id = :'sevan')
          and not exists(select 1 from messaging.messages where cuerpo = 'mensaje a borrar')
          and (select seguidores_count from profiles.profiles where user_id = :'queda') = 0,
  'No queda rastro: usuario, perfil, posts, mensajes y contadores ajustados');

-- ----------------------------------------------------- particiones UUIDv7 ----
select tests.clear_authentication();
select is((select count(*)::int from pg_inherits i join pg_class c on c.oid = i.inhrelid
            where i.inhparent = 'messaging.messages'::regclass
              and c.relname = 'messages_' || to_char(now(), 'YYYY_MM')), 1,
  'Existe la partición del mes actual (rango por UUIDv7)');

select * from finish();
rollback;
