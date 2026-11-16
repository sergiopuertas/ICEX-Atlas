-- notifications (agrupación, preferencias, push), moderation, config, orientador, storage.
begin;
\ir helpers.inc
select plan(29);

select tests.create_member('Autora') as autora \gset
select tests.create_member('Fan 1') as fan1 \gset
select tests.create_member('Fan 2') as fan2 \gset
select tests.create_member('Moderadora', 'moderador') as moder \gset
select tests.create_member('Admin', 'admin') as admin \gset

-- ------------------------------------------------------- notifications --------
select tests.authenticate_as(:'autora');
select api.create_post('01900000-0000-7000-8000-00000000b001', 'Mi logro', 'logro');
select tests.authenticate_as(:'fan1');
select api.recommend('01900000-0000-7000-8000-00000000b001');
select api.follow(:'autora');
select tests.authenticate_as(:'fan2');
select api.recommend('01900000-0000-7000-8000-00000000b001');

select tests.authenticate_as(:'autora');
select is((select total from notifications.notifications where user_id = :'autora' and tipo = 'recomendacion'), 2,
  'Agrupación: 2 recomendaciones → 1 notificación con total 2');
select is((select count(*)::int from notifications.notifications where user_id = :'autora'), 2,
  'notifications_select_own: ve sus notificaciones (recomendación + seguidor)');
select is((api.list_notifications() ->> 'no_leidas')::int, 2, 'list_notifications cuenta no leídas');
select is(api.mark_notifications_read(), 2, 'mark_notifications_read marca todas');
select ok(tests.queue_len('push') >= 3, 'Cada notificación con push activado se encola en pgmq');

select tests.authenticate_as(:'fan1');
select is_empty(format($$select 1 from notifications.notifications where user_id = %L$$, :'autora'),
  'notifications_select_own (negativo): no ve notificaciones ajenas');
update notifications.notifications set leido = false where user_id = :'autora';
select tests.authenticate_as(:'autora');
select is((select count(*)::int from notifications.notifications where not leido), 0,
  'notifications_update_own (negativo): otro no puede modificarlas');

-- preferencias y consentimiento
select is((api.update_notification_preferences('{"push_social": false, "email_novedades": true}'::jsonb) ->> 'email_novedades')::boolean,
  false, 'Sin consentimiento expreso no se activan emails');
select is((api.update_notification_preferences('{"consentimiento_comunicaciones": true, "email_novedades": true}'::jsonb) ->> 'email_novedades')::boolean,
  true, 'Con consentimiento sí');
select isnt((api.get_notification_preferences() ->> 'consentimiento_at'), null, 'Se registra la fecha del consentimiento');
select tests.clear_authentication();
select pgmq.purge_queue('push');
select tests.authenticate_as(:'fan2');
select api.follow(:'autora');
select is(tests.queue_len('push')::int, 0, 'push_social=false: no se encola push (sí queda en el centro)');
select tests.authenticate_as(:'fan1');
select is_empty(format($$select 1 from notifications.preferences where user_id = %L$$, :'autora'), 'preferences_own (negativo)');

-- push tokens
select lives_ok($$select api.register_push_token('token-fcm-de-prueba-123', 'android')$$, 'push_tokens_own: registrar token');
select tests.authenticate_as(:'fan2');
select is_empty($$select 1 from notifications.push_tokens where token = 'token-fcm-de-prueba-123'$$, 'push_tokens_own (negativo)');
select lives_ok($$select api.register_push_token('token-fcm-de-prueba-123', 'android')$$, 'Un token reutilizado en otro login se reasigna');
select tests.authenticate_as(:'fan1');
select is_empty($$select 1 from notifications.push_tokens$$, 'y deja de pertenecer al usuario anterior');

-- ----------------------------------------------------------- moderation -------
select tests.authenticate_as(:'fan1');
select api.report('post', '01900000-0000-7000-8000-00000000b001', 'spam', 'Prueba') as report \gset
select isnt(:'report'::uuid, null::uuid, 'reports_insert_member: denunciar');
select is(api.report('post', '01900000-0000-7000-8000-00000000b001', 'spam'), null,
  'Denunciar dos veces es idempotente (no duplica la pendiente)');
select tests.authenticate_as(:'fan2');
select is_empty($$select 1 from moderation.reports$$, 'reports_select (negativo): no ve denuncias ajenas');
select throws_ok(format($$select api.admin_resolve_report(%L, 'ocultar_contenido')$$, :'report'), '42501', null,
  'Un socio no resuelve denuncias');
select tests.authenticate_as(:'moder');
select is(jsonb_array_length(api.admin_list_reports()), 1, 'reports_select: la moderadora ve la cola');
select lives_ok(format($$select api.admin_resolve_report(%L, 'ocultar_contenido', 'spam confirmado')$$, :'report'), 'Moderadora oculta el contenido');
select ok((select oculto from feed.posts where id = '01900000-0000-7000-8000-00000000b001'), 'El post queda oculto');
select throws_ok(format($$select api.admin_resolve_report(%L, 'suspender_socio')$$, :'report'), '42501', null,
  'Solo admin puede suspender socios');

-- --------------------------------------------------------------- config -------
select tests.authenticate_as(:'fan1');
select is((api.app_config() ->> 'orientador.daily_limit')::int, 10, 'app_config_read: flags visibles a socios');
update config.app_config set value = '999' where key = 'orientador.daily_limit';
select is((api.app_config() ->> 'orientador.daily_limit')::int, 10, 'app_config_admin (negativo): un socio no cambia flags');
select tests.authenticate_as(:'admin');
select lives_ok($$select api.admin_set_config('orientador.daily_limit', '3')$$, 'app_config_admin: el admin cambia flags');

-- ------------------------------------------------------- orientador/storage --
select tests.authenticate_as(:'fan1');
select throws_ok($$select 1 from orientador.documents$$, '42501', null, 'documents_service_only: índice vectorial no accesible a clientes');
select throws_ok($$insert into storage.objects (bucket_id, name, owner) values ('avatars', auth.uid()::text || '/x.jpg', auth.uid())$$,
  '42501', null, 'Storage (negativo): los clientes no suben directamente (solo vía media-upload)');

select * from finish();
rollback;
