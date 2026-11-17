-- Rendimiento de get_feed y search_directory con los datos semilla (640 socios, ~15.000 follows).
-- Cada llamada se ejecuta como un socio real (rol authenticated + claims del JWT) para que RLS cuente.
-- Mide la duración de cada llamada con clock_timestamp() y calcula p50/p95/máx en milisegundos.
\set ON_ERROR_STOP on
set client_min_messages = warning;

create temporary table perf (caso text, ms double precision);
grant insert on perf to authenticated;

do $$
declare
  u uuid;
  t0 timestamptz;
  j jsonb;
  cur text;
  queries text[] := array['', 'ana', 'sener', 'madrid', 'export manager', 'jimenez', '42ª', 'singapur', 'fase', 'ca'];
  i int;
begin
  -- calentamiento de cachés
  for u in select user_id from identity.members order by user_id limit 5 loop
    perform set_config('role', 'authenticated', true);
    perform set_config('request.jwt.claims', json_build_object('sub', u, 'role', 'authenticated')::text, true);
    perform api.get_feed(null, 20);
    perform api.search_directory(null);
    perform set_config('role', 'postgres', true);
  end loop;

  i := 0;
  for u in select user_id from identity.members order by md5(user_id::text) limit 100 loop
    i := i + 1;
    perform set_config('role', 'authenticated', true);
    perform set_config('request.jwt.claims', json_build_object('sub', u, 'role', 'authenticated')::text, true);

    t0 := clock_timestamp();
    j := api.get_feed(null, 20);
    insert into perf values ('get_feed (1ª página)', extract(epoch from clock_timestamp() - t0) * 1000);

    cur := j ->> 'next_cursor';
    if cur is not null then
      t0 := clock_timestamp();
      perform api.get_feed(cur, 20);
      insert into perf values ('get_feed (página siguiente)', extract(epoch from clock_timestamp() - t0) * 1000);
    end if;

    t0 := clock_timestamp();
    perform api.search_directory(nullif(queries[1 + i % array_length(queries, 1)], ''));
    insert into perf values ('search_directory (texto)', extract(epoch from clock_timestamp() - t0) * 1000);

    t0 := clock_timestamp();
    perform api.search_directory(null, 40 + i % 10, null, case i % 4 when 0 then 'todos' when 1 then 'mi_promocion' when 2 then 'exterior' else 'activo' end);
    insert into perf values ('search_directory (filtros/pestañas)', extract(epoch from clock_timestamp() - t0) * 1000);

    perform set_config('role', 'postgres', true);
  end loop;
end $$;

\echo
\echo '== Latencia por llamada (ms), 100 socios distintos =='
select caso,
       count(*) as n,
       round(percentile_cont(0.5) within group (order by ms)::numeric, 2) as p50_ms,
       round(percentile_cont(0.95) within group (order by ms)::numeric, 2) as p95_ms,
       round(max(ms)::numeric, 2) as max_ms
  from perf group by caso order by caso;

-- Umbral del criterio de calidad: p95 < 200 ms
select case when max(p95) < 200 then 'OK: p95 < 200 ms' else 'FALLO: p95 >= 200 ms' end as resultado
  from (select percentile_cont(0.95) within group (order by ms) p95 from perf group by caso) x \gset
\echo :resultado

\echo
\echo '== EXPLAIN ANALYZE (una llamada representativa como socio) =='
select user_id as ana from profiles.profiles where nombre = 'Ana Ortega Jiménez' \gset
select set_config('request.jwt.claims', json_build_object('sub', :'ana', 'role', 'authenticated')::text, false) \g /dev/null
select set_config('role', 'authenticated', false) \g /dev/null
explain (analyze, buffers, costs off, summary on) select api.get_feed(null, 20);
explain (analyze, buffers, costs off, summary on) select api.search_directory('export manager');
