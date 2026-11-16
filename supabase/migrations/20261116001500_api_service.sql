-- =============================================================================
-- ICEX Atlas · 1500 · API de servicio (solo service_role, para Edge Functions)
-- PostgREST solo expone `api`; estas funciones son la puerta de las Edge Functions a
-- colas y tareas internas. Se revocan explícitamente a authenticated/anon.
-- =============================================================================

create or replace function api.svc_assert()
returns void language plpgsql stable set search_path = ''
as $$
begin
  -- Defensa en profundidad (además del REVOKE): con JWT, solo service_role. Sin JWT = sesión
  -- directa de base de datos (cron, migraciones, tests como postgres).
  if auth.role() is not null and auth.role() <> 'service_role' then
    raise exception 'Solo servicio' using errcode = '42501';
  end if;
end;
$$;

-- ------------------------------------------------------------------ colas -----
create or replace function api.svc_queue_read(p_queue text, p_qty int default 100, p_vt int default 60)
returns jsonb language plpgsql security definer set search_path = ''
as $$
begin
  perform api.svc_assert();
  if p_queue not in ('push', 'message_events', 'embeddings') then
    raise exception 'Cola desconocida' using errcode = '22023';
  end if;
  return (select coalesce(jsonb_agg(jsonb_build_object('msg_id', r.msg_id, 'read_ct', r.read_ct, 'message', r.message)), '[]'::jsonb)
            from notifications.dequeue(p_queue, least(p_qty, 500), p_vt) r);
end;
$$;

create or replace function api.svc_queue_ack(p_queue text, p_ids bigint[])
returns int language plpgsql security definer set search_path = ''
as $$
begin
  perform api.svc_assert();
  return notifications.ack(p_queue, p_ids);
end;
$$;

-- Novedad oficial → un mensaje push por socio que quiere recibirlas y tiene dispositivo.
create or replace function api.svc_expand_broadcast(p_post uuid, p_titulo text)
returns int language plpgsql security definer set search_path = ''
as $$
declare v int;
begin
  perform api.svc_assert();
  select count(*) into v from (
    select pgmq.send('push', jsonb_build_object('user_id', m.user_id, 'tipo', 'novedad',
             'payload', jsonb_build_object('post_id', p_post, 'titulo', p_titulo)))
      from identity.members m
     where m.status = 'active'
       and notifications.wants_push(m.user_id, 'novedad')
       and exists (select 1 from notifications.push_tokens t where t.user_id = m.user_id)) s;
  return v;
end;
$$;

-- Destinatarios: tokens, si está conectado (heartbeat < 90 s) y si quiere este tipo de push.
create or replace function api.svc_push_targets(p_users uuid[], p_tipo notifications.tipo)
returns jsonb language plpgsql stable security definer set search_path = ''
as $$
begin
  perform api.svc_assert();
  return (select coalesce(jsonb_agg(jsonb_build_object(
      'user_id', m.user_id,
      'online', coalesce(m.last_seen_at > now() - interval '90 seconds', false),
      'wants', notifications.wants_push(m.user_id, p_tipo),
      'tokens', (select coalesce(jsonb_agg(t.token), '[]'::jsonb) from notifications.push_tokens t where t.user_id = m.user_id))), '[]'::jsonb)
    from identity.members m where m.user_id = any (p_users) and m.status = 'active');
end;
$$;

create or replace function api.svc_display_names(p_users uuid[])
returns jsonb language plpgsql stable security definer set search_path = ''
as $$
begin
  perform api.svc_assert();
  return (select coalesce(jsonb_object_agg(p.user_id, p.nombre), '{}'::jsonb) from profiles.profiles p where p.user_id = any (p_users));
end;
$$;

create or replace function api.svc_drop_tokens(p_tokens text[])
returns int language plpgsql security definer set search_path = ''
as $$
declare v int;
begin
  perform api.svc_assert();
  delete from notifications.push_tokens where token = any (p_tokens);
  get diagnostics v = row_count;
  return v;
end;
$$;

-- -------------------------------------------------------------- orientador ----
create or replace function api.svc_index_source(p_tipo orientador.source_tipo, p_id uuid)
returns jsonb language plpgsql stable security definer set search_path = ''
as $$
begin
  perform api.svc_assert();
  return (select to_jsonb(s) from orientador.source_text(p_tipo, p_id) s limit 1);
end;
$$;

create or replace function api.svc_upsert_embedding(p_tipo orientador.source_tipo, p_id uuid, p_embedding text)
returns void language plpgsql security definer set search_path = ''
as $$
begin
  perform api.svc_assert();
  perform orientador.upsert_document(p_tipo, p_id, p_embedding::extensions.vector(384));
end;
$$;

create or replace function api.svc_delete_document(p_tipo orientador.source_tipo, p_id uuid)
returns void language plpgsql security definer set search_path = ''
as $$
begin
  perform api.svc_assert();
  delete from orientador.documents where source_tipo = p_tipo and source_id = p_id;
end;
$$;

-- ------------------------------------------------------- sincronía socios -----
create or replace function api.svc_member_subjects(p_after uuid default null, p_limit int default 200)
returns jsonb language plpgsql stable security definer set search_path = ''
as $$
begin
  perform api.svc_assert();
  return (select coalesce(jsonb_agg(jsonb_build_object('user_id', m.user_id, 'wp_subject', m.wp_subject) order by m.user_id), '[]'::jsonb)
    from (select * from identity.members m
           where m.status = 'active' and m.wp_subject is not null and (p_after is null or m.user_id > p_after)
           order by m.user_id limit least(p_limit, 1000)) m);
end;
$$;

create or replace function api.svc_revoke_member(p_user uuid, p_reason text default 'baja_wordpress')
returns void language plpgsql security definer set search_path = ''
as $$
begin
  perform api.svc_assert();
  perform identity.revoke_member(p_user, p_reason);
end;
$$;

-- Solo service_role.
revoke execute on function api.svc_assert(), api.svc_queue_read(text, int, int), api.svc_queue_ack(text, bigint[]),
  api.svc_expand_broadcast(uuid, text), api.svc_push_targets(uuid[], notifications.tipo), api.svc_display_names(uuid[]),
  api.svc_drop_tokens(text[]), api.svc_index_source(orientador.source_tipo, uuid),
  api.svc_upsert_embedding(orientador.source_tipo, uuid, text), api.svc_delete_document(orientador.source_tipo, uuid),
  api.svc_member_subjects(uuid, int), api.svc_revoke_member(uuid, text)
  from public, anon, authenticated;
grant execute on function api.svc_assert(), api.svc_queue_read(text, int, int), api.svc_queue_ack(text, bigint[]),
  api.svc_expand_broadcast(uuid, text), api.svc_push_targets(uuid[], notifications.tipo), api.svc_display_names(uuid[]),
  api.svc_drop_tokens(text[]), api.svc_index_source(orientador.source_tipo, uuid),
  api.svc_upsert_embedding(orientador.source_tipo, uuid, text), api.svc_delete_document(orientador.source_tipo, uuid),
  api.svc_member_subjects(uuid, int), api.svc_revoke_member(uuid, text)
  to service_role;
grant execute on function identity.revoke_member(uuid, text) to service_role;
