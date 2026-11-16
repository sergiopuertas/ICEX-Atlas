-- feed: RLS de posts/comentarios/recomendaciones, novedades, contadores, timeline keyset.
begin;
\ir helpers.inc
select plan(30);

select tests.create_member('Autora') as autora \gset
select tests.create_member('Lectora') as lectora \gset
select tests.create_member('Extraño') as extrano \gset
select tests.create_member('Moderadora', 'moderador') as moder \gset
select tests.create_member('Admin', 'admin') as admin \gset

select tests.authenticate_as(:'autora');
select lives_ok($$select api.create_post('01900000-0000-7000-8000-000000000001', 'Hola red', 'logro')$$, 'posts_insert: publicar');
select is((select count(*)::int from feed.posts where id = '01900000-0000-7000-8000-000000000001'), 1, 'publicado una vez');
select lives_ok($$select api.create_post('01900000-0000-7000-8000-000000000001', 'Hola red', 'logro')$$, 'reintento idempotente');
select is((select posts_count from profiles.profiles where user_id = :'autora'), 1, 'Trigger posts_count (sin duplicar)');
select throws_ok($$select api.create_post(gen_random_uuid(), 'x', 'novedad_oficial')$$, '42501', null,
  'Un socio no puede publicar novedades oficiales');
select throws_ok(format($$insert into feed.posts (autor_id, tipo, titulo, texto) values (%L, 'novedad_oficial', 't', 'x')$$, :'autora'),
  '42501', null, 'posts_insert (negativo): ni con INSERT directo');
select throws_ok(format($$insert into feed.posts (autor_id, texto) values (%L, 'x')$$, :'lectora'),
  '42501', null, 'posts_insert (negativo): no puede publicar como otra persona');
select lives_ok($$select api.create_post('01900000-0000-7000-8000-000000000002', 'Solo seguidores', 'general', '{}', 'seguidores')$$,
  'Publicación solo para seguidores');

select tests.authenticate_as(:'lectora');
select ok(exists(select 1 from feed.posts where id = '01900000-0000-7000-8000-000000000001'), 'posts_select: visible a socios');
select ok(not exists(select 1 from feed.posts where id = '01900000-0000-7000-8000-000000000002'), 'posts_select (negativo): "seguidores" oculto a no seguidores');
select api.follow(:'autora');
select ok(exists(select 1 from feed.posts where id = '01900000-0000-7000-8000-000000000002'), 'posts_select: "seguidores" visible al seguir');
update feed.posts set texto = 'editado por otra' where id = '01900000-0000-7000-8000-000000000001';
select is((select texto from feed.posts where id = '01900000-0000-7000-8000-000000000001'), 'Hola red', 'posts_update_own (negativo): no edita posts ajenos');
select throws_ok($$select api.delete_post('01900000-0000-7000-8000-000000000001')$$, '42501', null, 'posts_delete (negativo): no borra posts ajenos');

-- recomendaciones y comentarios
select lives_ok($$select api.recommend('01900000-0000-7000-8000-000000000001')$$, 'recommendations_insert: recomendar');
select lives_ok($$select api.recommend('01900000-0000-7000-8000-000000000001')$$, 'recomendar dos veces es idempotente');
select is((select recomendaciones_count from feed.posts where id = '01900000-0000-7000-8000-000000000001'), 1, 'Trigger recomendaciones_count');
select lives_ok($$select api.add_comment('01900000-0000-7000-8000-0000000000c1', '01900000-0000-7000-8000-000000000001', '¡Enhorabuena!')$$, 'comments_insert: comentar');
select is((select comentarios_count from feed.posts where id = '01900000-0000-7000-8000-000000000001'), 1, 'Trigger comentarios_count');
select throws_ok(format($$insert into feed.recommendations (post_id, user_id) values ('01900000-0000-7000-8000-000000000001', %L)$$, :'extrano'),
  '42501', null, 'recommendations_insert (negativo): no recomienda en nombre de otro');

select tests.authenticate_as(:'extrano');
select throws_ok($$insert into feed.comments (post_id, autor_id, texto) select '01900000-0000-7000-8000-000000000002', auth.uid(), 'x'$$,
  '42501', null, 'comments_insert (negativo): no comenta en un post que no puede ver');

-- bloqueo oculta contenido
select tests.authenticate_as(:'autora');
select api.block(:'extrano');
select tests.authenticate_as(:'extrano');
select ok(not exists(select 1 from feed.posts where autor_id = :'autora'), 'Bloqueo: el bloqueado no ve las publicaciones');

-- moderación
select tests.authenticate_as(:'moder');
update feed.posts set oculto = true where id = '01900000-0000-7000-8000-000000000001';
select tests.authenticate_as(:'lectora');
select ok(not exists(select 1 from feed.posts where id = '01900000-0000-7000-8000-000000000001'), 'posts_moderate: oculto deja de verse');
select tests.authenticate_as(:'autora');
select ok(exists(select 1 from feed.posts where id = '01900000-0000-7000-8000-000000000001'), 'el autor sigue viendo su post oculto');

-- novedades oficiales (admin)
select tests.authenticate_as(:'admin');
select lives_ok($$select api.admin_publish_news('01900000-0000-7000-8000-0000000000a1', 'Reunión anual', 'Texto', 'Evento', true)$$,
  'admin_publish_news: el admin publica novedad fijada');
select tests.authenticate_as(:'lectora');
select ok((api.get_feed() -> 'destacadas') @> '[{"id": "01900000-0000-7000-8000-0000000000a1"}]'::jsonb,
  'get_feed: novedad fijada en "destacadas"');
select ok(exists(select 1 from notifications.notifications where user_id = :'lectora' and tipo = 'novedad'),
  'Novedad oficial: notificación a todos los socios');
select throws_ok($$select api.admin_publish_news(gen_random_uuid(), 't', 'x')$$, '42501', null, 'Un socio no usa el panel admin');

-- timeline keyset: 25 posts de la autora seguida → 2 páginas sin solapes
select tests.authenticate_as(:'autora');
select api.create_post(util.uuid_v7(now() - (g || ' minutes')::interval), 'post ' || g) from generate_series(1, 25) g;
select tests.authenticate_as(:'lectora');
select is(jsonb_array_length(api.get_feed(null, 10) -> 'items'), 10, 'get_feed: página 1 de 10');
select is((with p1 as (select api.get_feed(null, 10) j),
               p2 as (select api.get_feed((select j ->> 'next_cursor' from p1), 10) j)
           select count(*)::int from (
             select jsonb_array_elements(j -> 'items') ->> 'id' id from p1
             intersect select jsonb_array_elements(j -> 'items') ->> 'id' from p2) x), 0,
  'get_feed: el cursor no repite elementos');
select ok((with p1 as (select api.get_feed(null, 10) j)
           select (j -> 'items' -> 0 ->> 'created_at')::timestamptz >= (j -> 'items' -> 9 ->> 'created_at')::timestamptz from p1),
  'get_feed: orden cronológico descendente');

select * from finish();
rollback;
