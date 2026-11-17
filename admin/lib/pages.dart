import 'dart:async';

import 'package:flutter/material.dart';
import 'package:icex_atlas_admin/admin_api.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Panel: Resumen · Novedades · Denuncias · Clubs · Socios (este último solo admin).
class AdminHome extends StatefulWidget {
  const AdminHome({required this.api, required this.isAdmin, super.key});

  final AdminApi api;
  final bool isAdmin;

  @override
  State<AdminHome> createState() => _AdminHomeState();
}

class _AdminHomeState extends State<AdminHome> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final pages = <(IconData, String, Widget)>[
      (Icons.dashboard_outlined, 'Resumen', DashboardPage(api: widget.api)),
      if (widget.isAdmin) (Icons.campaign_outlined, 'Novedades', NewsAdminPage(api: widget.api)),
      (Icons.flag_outlined, 'Denuncias', ReportsPage(api: widget.api, isAdmin: widget.isAdmin)),
      if (widget.isAdmin) (Icons.groups_outlined, 'Clubs', ClubsAdminPage(api: widget.api)),
      if (widget.isAdmin) (Icons.badge_outlined, 'Socios', MembersPage(api: widget.api)),
    ];
    final i = _tab.clamp(0, pages.length - 1);
    return Scaffold(
      appBar: AppBar(
        title: const Text('ICEX Atlas · Administración'),
        actions: [
          TextButton.icon(
            onPressed: () => Supabase.instance.client.auth.signOut(),
            icon: const Icon(Icons.logout),
            label: const Text('Salir'),
          ),
        ],
      ),
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: i,
            labelType: NavigationRailLabelType.all,
            onDestinationSelected: (v) => setState(() => _tab = v),
            destinations: [
              for (final p in pages) NavigationRailDestination(icon: Icon(p.$1), label: Text(p.$2)),
            ],
          ),
          const VerticalDivider(width: 1),
          Expanded(child: pages[i].$3),
        ],
      ),
    );
  }
}

/// Carga asíncrona con estados de carga/error/vacío.
class Loader<T> extends StatefulWidget {
  const Loader({required this.load, required this.builder, super.key});

  final Future<T> Function() load;
  final Widget Function(BuildContext, T, VoidCallback reload) builder;

  @override
  State<Loader<T>> createState() => _LoaderState<T>();
}

class _LoaderState<T> extends State<Loader<T>> {
  late Future<T> _f = widget.load();

  void _reload() {
    final next = widget.load();
    setState(() {
      _f = next;
    });
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<T>(
    future: _f,
    builder: (context, s) {
      if (s.connectionState == ConnectionState.waiting) {
        return const Center(child: CircularProgressIndicator());
      }
      if (s.hasError) {
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Error: ${s.error}'),
              TextButton(onPressed: _reload, child: const Text('Reintentar')),
            ],
          ),
        );
      }
      if (!s.hasData) return const Center(child: CircularProgressIndicator());
      return widget.builder(context, s.data as T, _reload);
    },
  );
}

Future<void> _run(BuildContext context, Future<void> f, String ok) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    await f;
    messenger.showSnackBar(SnackBar(content: Text(ok)));
  } on Object catch (e) {
    messenger.showSnackBar(SnackBar(content: Text('Error: $e')));
  }
}

class DashboardPage extends StatelessWidget {
  const DashboardPage({required this.api, super.key});

  final AdminApi api;

  @override
  Widget build(BuildContext context) => Loader<Map<String, dynamic>>(
    load: api.dashboard,
    builder: (context, d, _) => Padding(
      padding: const EdgeInsets.all(24),
      child: Wrap(
        spacing: 16,
        runSpacing: 16,
        children: [
          for (final e in {
            'Socios activos': d['socios_activos'],
            'Denuncias pendientes': d['denuncias_pendientes'],
            'Novedades': d['novedades'],
            'Clubs': d['clubs'],
            'Publicaciones (7 días)': d['posts_7d'],
          }.entries)
            SizedBox(
              width: 220,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${e.value}', style: Theme.of(context).textTheme.headlineMedium),
                      Text(e.key),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
  );
}

class NewsAdminPage extends StatelessWidget {
  const NewsAdminPage({required this.api, super.key});

  final AdminApi api;

  Future<void> _edit(BuildContext context, VoidCallback reload, [Map<String, dynamic>? n]) async {
    final titulo = TextEditingController(text: n?['titulo'] as String?);
    final texto = TextEditingController(text: n?['texto'] as String?);
    final etiqueta = TextEditingController(text: n?['etiqueta'] as String?);
    var fijado = n?['fijado'] as bool? ?? false;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, set) => AlertDialog(
          title: Text(n == null ? 'Nueva novedad' : 'Editar novedad'),
          content: SizedBox(
            width: 520,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titulo,
                  decoration: const InputDecoration(labelText: 'Título'),
                ),
                TextField(
                  controller: etiqueta,
                  decoration: const InputDecoration(labelText: 'Etiqueta (Evento, Clubs…)'),
                ),
                TextField(
                  controller: texto,
                  maxLines: 6,
                  decoration: const InputDecoration(labelText: 'Texto'),
                ),
                CheckboxListTile(
                  value: fijado,
                  onChanged: (v) => set(() => fijado = v ?? false),
                  title: const Text('Fijar arriba en Inicio'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')),
            FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Publicar')),
          ],
        ),
      ),
    );
    if ((ok ?? false) &&
        titulo.text.trim().isNotEmpty &&
        texto.text.trim().isNotEmpty &&
        context.mounted) {
      await _run(
        context,
        api.publishNews(
          id: n?['id'] as String?,
          titulo: titulo.text.trim(),
          texto: texto.text.trim(),
          etiqueta: etiqueta.text.trim(),
          fijado: fijado,
        ),
        'Novedad publicada (se notifica a todos los socios)',
      );
      reload();
    }
    titulo.dispose();
    texto.dispose();
    etiqueta.dispose();
  }

  @override
  Widget build(BuildContext context) => Loader<List<Map<String, dynamic>>>(
    load: api.news,
    builder: (context, list, reload) => Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(context, reload),
        icon: const Icon(Icons.add),
        label: const Text('Nueva novedad'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (final n in list)
            Card(
              child: ListTile(
                leading: Icon(n['fijado'] == true ? Icons.push_pin : Icons.article_outlined),
                title: Text(n['titulo'] as String? ?? ''),
                subtitle: Text(
                  n['texto'] as String? ?? '',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: Wrap(
                  children: [
                    IconButton(
                      tooltip: n['fijado'] == true ? 'Desfijar' : 'Fijar',
                      icon: const Icon(Icons.push_pin_outlined),
                      onPressed: () async {
                        await _run(
                          context,
                          api.setPinned(n['id'] as String, pinned: n['fijado'] != true),
                          'Actualizado',
                        );
                        reload();
                      },
                    ),
                    IconButton(
                      tooltip: 'Editar',
                      icon: const Icon(Icons.edit),
                      onPressed: () => _edit(context, reload, n),
                    ),
                    IconButton(
                      tooltip: 'Eliminar',
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () async {
                        await _run(context, api.deletePost(n['id'] as String), 'Eliminada');
                        reload();
                      },
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    ),
  );
}

class ReportsPage extends StatelessWidget {
  const ReportsPage({required this.api, required this.isAdmin, super.key});

  final AdminApi api;
  final bool isAdmin;

  @override
  Widget build(BuildContext context) => Loader<List<Map<String, dynamic>>>(
    load: api.reports,
    builder: (context, list, reload) => list.isEmpty
        ? const Center(child: Text('No hay denuncias pendientes. 🎉'))
        : ListView(
            padding: const EdgeInsets.all(16),
            children: [
              for (final r in list)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${r['target_tipo']} · ${r['motivo']} · ${r['estado']}',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Autor: ${(r['autor'] as Map?)?['nombre'] ?? '—'} · Denuncia: ${(r['denunciante'] as Map?)?['nombre'] ?? '—'}',
                        ),
                        if (r['detalle'] != null) Text('Detalle: ${r['detalle']}'),
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          color: const Color(0xFFF3EFED),
                          child: Text(r['contenido'] as String? ?? ''),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          children: [
                            OutlinedButton(
                              onPressed: () async {
                                await _run(
                                  context,
                                  api.resolve(r['id'] as String, 'descartar'),
                                  'Descartada',
                                );
                                reload();
                              },
                              child: const Text('Descartar'),
                            ),
                            FilledButton(
                              onPressed: () async {
                                await _run(
                                  context,
                                  api.resolve(r['id'] as String, 'ocultar_contenido'),
                                  'Contenido ocultado',
                                );
                                reload();
                              },
                              child: const Text('Ocultar contenido'),
                            ),
                            if (isAdmin)
                              FilledButton.tonal(
                                onPressed: () async {
                                  await _run(
                                    context,
                                    api.resolve(r['id'] as String, 'suspender_socio'),
                                    'Socio suspendido',
                                  );
                                  reload();
                                },
                                child: const Text('Suspender socio'),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
  );
}

class ClubsAdminPage extends StatelessWidget {
  const ClubsAdminPage({required this.api, super.key});

  final AdminApi api;

  Future<void> _edit(
    BuildContext context,
    VoidCallback reload, [
    Map<String, dynamic>? club,
  ]) async {
    final c = {
      for (final k in ['nombre', 'ciudad', 'pais', 'lat', 'lng', 'descripcion'])
        k: TextEditingController(text: club?[k]?.toString()),
    };
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(club == null ? 'Nuevo club' : 'Editar club'),
        content: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final e in c.entries)
                TextField(
                  controller: e.value,
                  decoration: InputDecoration(labelText: e.key),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('Guardar')),
        ],
      ),
    );
    final lat = double.tryParse(c['lat']!.text.replaceAll(',', '.'));
    final lng = double.tryParse(c['lng']!.text.replaceAll(',', '.'));
    if ((ok ?? false) && lat != null && lng != null && context.mounted) {
      await _run(
        context,
        api.upsertClub(
          id: club?['id'] as String?,
          nombre: c['nombre']!.text.trim(),
          ciudad: c['ciudad']!.text.trim(),
          pais: c['pais']!.text.trim(),
          lat: lat,
          lng: lng,
          descripcion: c['descripcion']!.text.trim(),
        ),
        'Club guardado',
      );
      reload();
    }
    for (final t in c.values) {
      t.dispose();
    }
  }

  @override
  Widget build(BuildContext context) => Loader<List<Map<String, dynamic>>>(
    load: api.clubs,
    builder: (context, list, reload) => Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(context, reload),
        icon: const Icon(Icons.add),
        label: const Text('Nuevo club'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (final club in list)
            Card(
              child: ListTile(
                title: Text(club['nombre'] as String),
                subtitle: Text(
                  '${club['ciudad']}, ${club['pais']} · ${club['miembros_count']} miembros',
                ),
                trailing: Wrap(
                  children: [
                    IconButton(
                      tooltip: 'Editar',
                      icon: const Icon(Icons.edit),
                      onPressed: () => _edit(context, reload, club),
                    ),
                    IconButton(
                      tooltip: 'Eliminar',
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () async {
                        await _run(context, api.deleteClub(club['id'] as String), 'Club eliminado');
                        reload();
                      },
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    ),
  );
}

class MembersPage extends StatefulWidget {
  const MembersPage({required this.api, super.key});

  final AdminApi api;

  @override
  State<MembersPage> createState() => _MembersPageState();
}

class _MembersPageState extends State<MembersPage> {
  String _q = '';
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.all(16),
        child: TextField(
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search),
            hintText: 'Buscar socio por nombre, empresa, ciudad…',
          ),
          onChanged: (v) {
            _debounce?.cancel();
            _debounce = Timer(const Duration(milliseconds: 300), () => setState(() => _q = v));
          },
        ),
      ),
      Expanded(
        child: Loader<List<Map<String, dynamic>>>(
          key: ValueKey(_q),
          load: () => widget.api.members(_q),
          builder: (context, list, reload) => ListView(
            children: [
              for (final m in list)
                ListTile(
                  title: Text(m['nombre'] as String),
                  subtitle: Text('${m['promocion']}ª promoción · ${m['status']}'),
                  trailing: DropdownButton<String>(
                    value: m['role'] as String,
                    items: const [
                      DropdownMenuItem(value: 'socio', child: Text('Socio')),
                      DropdownMenuItem(value: 'moderador', child: Text('Moderación')),
                      DropdownMenuItem(value: 'admin', child: Text('Administración')),
                    ],
                    onChanged: (r) async {
                      if (r == null) return;
                      await _run(
                        context,
                        widget.api.setRole(m['user_id'] as String, r),
                        'Rol actualizado',
                      );
                      reload();
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    ],
  );
}
