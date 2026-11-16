-- clubs, eventos (aforo y lista de espera) y mapa (clusters PostGIS).
begin;
\ir helpers.inc
select plan(20);

select tests.create_member('Org') as org \gset
select tests.create_member('Socia 1') as s1 \gset
select tests.create_member('Socia 2') as s2 \gset
select tests.create_member('Admin', 'admin') as admin \gset

select tests.authenticate_as(:'s1');
select throws_ok($$insert into clubs.clubs (nombre, ciudad, pais, ubicacion) values ('Club falso', 'X', 'Y',
  extensions.st_makepoint(0, 0)::extensions.geography)$$, '42501', null, 'clubs_admin (negativo): un socio no crea clubs');

select tests.authenticate_as(:'admin');
select lives_ok($$select api.admin_upsert_club('01900000-0000-7000-8000-0000000c1b01', 'Club Test Oslo', 'Oslo', 'Noruega', 59.91, 10.75, 'NO')$$,
  'clubs_admin: el admin crea un club');
select lives_ok(format($$select api.admin_set_club_role('01900000-0000-7000-8000-0000000c1b01', %L, 'organizador')$$, :'org'),
  'el admin nombra organizador');

select tests.authenticate_as(:'s1');
select ok(exists(select 1 from clubs.clubs where id = '01900000-0000-7000-8000-0000000c1b01'), 'clubs_select: socios ven los clubs');
select lives_ok($$select api.join_club('01900000-0000-7000-8000-0000000c1b01')$$, 'club_members_join: unirse');
select throws_ok(format($$insert into clubs.club_members (club_id, user_id) values ('01900000-0000-7000-8000-0000000c1b01', %L)$$, :'s2'),
  '42501', null, 'club_members_join (negativo): no puede apuntar a otra persona');
select throws_ok($$insert into clubs.club_members (club_id, user_id, rol) select '01900000-0000-7000-8000-0000000c1b01', auth.uid(), 'organizador'
  on conflict do nothing$$, '42501', null, 'club_members_join (negativo): no puede autoproclamarse organizador');
select is((select miembros_count from clubs.clubs where id = '01900000-0000-7000-8000-0000000c1b01'), 2, 'Trigger miembros_count');
select throws_ok($$select api.create_event(gen_random_uuid(), '01900000-0000-7000-8000-0000000c1b01', 'Evento pirata', now() + interval '2 days')$$,
  '42501', null, 'events_write_organizer (negativo): un socio no crea eventos');

select tests.authenticate_as(:'org');
select lives_ok($$select api.create_event('01900000-0000-7000-8000-0000000e0e01', '01900000-0000-7000-8000-0000000c1b01',
  'Café en Oslo', now() + interval '3 days', p_aforo => 1)$$, 'events_write_organizer: el organizador crea un evento (aforo 1)');

select tests.authenticate_as(:'s1');
select is(api.register_event('01900000-0000-7000-8000-0000000e0e01') ->> 'mi_inscripcion', 'inscrito', 'register_event: plaza confirmada');
select tests.authenticate_as(:'s2');
select is(api.register_event('01900000-0000-7000-8000-0000000e0e01') ->> 'mi_inscripcion', 'lista_espera', 'Aforo completo → lista de espera');
select is_empty($$select 1 from clubs.event_attendees where user_id <> auth.uid()$$, 'attendees_select (negativo): no ve inscripciones ajenas');
select tests.authenticate_as(:'org');
select is((select count(*)::int from clubs.event_attendees where event_id = '01900000-0000-7000-8000-0000000e0e01'), 2,
  'attendees_select: el organizador ve todas las inscripciones');
select tests.authenticate_as(:'s1');
select api.cancel_event_registration('01900000-0000-7000-8000-0000000e0e01');
select tests.authenticate_as(:'s2');
select is(api.list_events('01900000-0000-7000-8000-0000000c1b01') -> 0 ->> 'mi_inscripcion', 'inscrito',
  'Al liberarse una plaza, la lista de espera promociona');
select is((select inscritos_count from clubs.events where id = '01900000-0000-7000-8000-0000000e0e01'), 1, 'inscritos_count coherente');

-- mapa
select api.update_my_profile(p_lat => 59.91, p_lng => 10.75, p_ciudad => 'Oslo');
select ok((api.map_clusters(2, -180, -85, 180, 85) ->> 'total')::int >= 500, 'map_clusters: zoom mundial agrupa a todos los alumni con ubicación');
select ok(jsonb_array_length(api.map_clusters(2, -180, -85, 180, 85) -> 'clusters')
          < jsonb_array_length(api.map_clusters(8, -10, 35, 5, 45) -> 'clusters') + 200,
  'map_clusters: a zoom bajo hay pocos clusters');
select ok(exists(select 1 from jsonb_array_elements(api.map_clusters(12, 10.6, 59.8, 10.9, 60.0) -> 'clusters') c
                 where c -> 'alumni' ->> 'user_id' = :'s2'), 'map_clusters: a zoom alto, cluster de 1 con la ficha del alumni');
select ok(exists(select 1 from jsonb_array_elements(api.map_clusters(5, 0, 50, 20, 65) -> 'clubs') c
                 where c ->> 'nombre' = 'Club Test Oslo'), 'map_clusters incluye clubs en la vista');

select * from finish();
rollback;
