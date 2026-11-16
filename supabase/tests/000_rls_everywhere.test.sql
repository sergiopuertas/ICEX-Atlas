-- CI: falla si existe una tabla sin RLS en cualquier esquema de la aplicación
-- (los expuestos por la Data API y los de módulo, a los que se llega vía `api`).
begin;
select plan(3);

select is_empty($$
  select n.nspname || '.' || c.relname
    from pg_class c join pg_namespace n on n.oid = c.relnamespace
   where c.relkind in ('r', 'p')
     and n.nspname in ('api', 'public', 'util', 'identity', 'profiles', 'social', 'clubs', 'feed', 'messaging',
                       'notifications', 'orientador', 'moderation', 'config')
     and not c.relrowsecurity
$$, 'Todas las tablas de los esquemas de la aplicación tienen RLS activado');

select is_empty($$
  select p.oid::regprocedure::text from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'api' and has_function_privilege('anon', p.oid, 'execute')
$$, 'anon no puede ejecutar ninguna función de api');

select is_empty($$
  select p.oid::regprocedure::text from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname in ('api', 'identity', 'profiles', 'social', 'clubs', 'feed', 'messaging', 'notifications',
                       'orientador', 'moderation', 'config', 'util')
     and p.prosecdef
     and not exists (select 1 from unnest(coalesce(p.proconfig, '{}')) c where c like 'search_path=%')
$$, 'Toda función security definer fija search_path');

select * from finish();
rollback;
