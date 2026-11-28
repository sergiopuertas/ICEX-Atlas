-- -----------------------------------------------------------------------------
-- ICEX Atlas · 20261128-0100 · Arranque en frío (beta abierta)
--
-- Quien se registra en la beta no sigue a nadie y a menudo no tiene promoción, ciudad ni
-- empresa todavía: «Personas que quizá conozcas» salía vacío y el feed también.
--
--  · api.suggestions: si no hay bastantes coincidencias, completa con las personas más
--    seguidas de la comunidad (que aceptan aparecer en sugerencias). Las coincidencias
--    siguen saliendo antes. La promoción 0 («sin promoción») ya no cuenta como coincidencia.
--    Solo socios activos.
--  · api.community_highlights: lo más interesante de los últimos 30 días de gente a la que
--    aún no sigues, para rellenar un feed vacío o corto. Solo posts visibles para todos los
--    socios, de autores que aceptan aparecer en sugerencias, sin bloqueos y como mucho dos
--    por autor. Coste acotado: se puntúan los 300 posts más recientes.
-- -----------------------------------------------------------------------------

create index if not exists profiles_sug_popular_idx
  on profiles.profiles (seguidores_count desc, posts_count desc, user_id)
  where acepta_sugerencias;

create or replace function api.suggestions(p_limit int default 5)
returns jsonb language sql stable security invoker set search_path = ''
as $$
  with me as (select p.* from profiles.profiles p where p.user_id = identity.require_member()),
  excluded as (
    select (select user_id from me) as id
    union select social.my_followed_ids()
    union select social.my_blocked_ids()),
  fof as (
    select f2.seguido_id as id, count(*) as n
      from social.follows f1 join social.follows f2 on f2.seguidor_id = f1.seguido_id
     where f1.seguidor_id = (select user_id from me)
     group by f2.seguido_id),
  candidates as (
    (select id from fof order by n desc, id limit 500)
    union (select p.user_id from profiles.profiles p, me where p.acepta_sugerencias and me.promocion > 0
            and p.promocion = me.promocion
            order by p.seguidores_count desc, p.user_id limit 300)
    union (select p.user_id from profiles.profiles p, me where p.acepta_sugerencias and p.ciudad = me.ciudad
            order by p.seguidores_count desc, p.user_id limit 300)
    union (select p.user_id from profiles.profiles p, me where p.acepta_sugerencias and p.empresa = me.empresa
            order by p.seguidores_count desc, p.user_id limit 300)
    union (select p.user_id from profiles.profiles p, me where p.acepta_sugerencias and p.sector = me.sector
            order by p.seguidores_count desc, p.user_id limit 300)
    -- Relleno para quien acaba de llegar: lo más seguido de la comunidad.
    union (select p.user_id from profiles.profiles p where p.acepta_sugerencias
            order by p.seguidores_count desc, p.posts_count desc, p.user_id limit 100)),
  scored as (
    select p.user_id, p.seguidores_count, p.posts_count,
           coalesce(fof.n, 0) * 3
           + case when me.promocion > 0 and p.promocion = me.promocion then 4 else 0 end
           + case when p.ciudad is not null and p.ciudad = me.ciudad then 3 else 0 end
           + case when p.empresa is not null and p.empresa = me.empresa then 3 else 0 end
           + case when p.sector is not null and p.sector = me.sector then 1 else 0 end as score
      from candidates c
      join profiles.profiles p on p.user_id = c.id
      cross join me
      left join fof on fof.id = p.user_id
     where p.acepta_sugerencias
       and p.user_id not in (select id from excluded where id is not null)
       and identity.is_member_id(p.user_id)),
  top as (
    select s.user_id, s.score from scored s
     order by s.score desc, s.seguidores_count desc, s.posts_count desc, s.user_id
     limit least(greatest(p_limit, 1), 20))
  select coalesce(jsonb_agg(profiles.card(p, (select user_id from me), false)
           || jsonb_build_object('is_following', false, 'score', t.score)
           order by t.score desc, p.seguidores_count desc, p.posts_count desc, p.user_id), '[]'::jsonb)
    from top t join profiles.profiles p on p.user_id = t.user_id;
$$;

create or replace function api.community_highlights(p_limit int default 10)
returns jsonb language sql stable security invoker set search_path = ''
as $$
  with me as (select identity.require_member() as id),
  followed as (select social.my_followed_ids() as id),
  recent as (
    -- posts_created_idx: los más recientes, sin recorrer la tabla.
    select p.* from feed.posts p
     where not p.oculto and p.visibilidad = 'socios' and p.tipo <> 'novedad_oficial'
       and p.created_at > now() - interval '30 days'
     order by p.created_at desc, p.id desc
     limit 300),
  ranked as (
    select r.id, r.autor_id, r.created_at,
           (1 + r.recomendaciones_count + 2 * r.comentarios_count + r.compartidos_count)
             / power(extract(epoch from now() - r.created_at) / 3600 + 2, 1.5) as score
      from recent r
      join profiles.profiles pr on pr.user_id = r.autor_id and pr.acepta_sugerencias
     where r.autor_id <> (select id from me)
       and r.autor_id not in (select id from followed where id is not null)
       and not social.is_blocked_between((select id from me), r.autor_id)
       and identity.is_member_id(r.autor_id)),
  per_author as (
    select ranked.*, row_number() over (partition by autor_id order by score desc, id desc) as n from ranked),
  top as (
    select id, score, created_at from per_author where n <= 2
     order by score desc, created_at desc, id desc
     limit least(greatest(coalesce(p_limit, 10), 1), 20))
  select coalesce(jsonb_agg(feed.post_json(p, (select id from me)) order by t.score desc, t.created_at desc, t.id desc),
                  '[]'::jsonb)
    from top t join feed.posts p on p.id = t.id;
$$;

revoke all on function api.community_highlights(int) from public, anon;
grant execute on function api.community_highlights(int) to authenticated;
