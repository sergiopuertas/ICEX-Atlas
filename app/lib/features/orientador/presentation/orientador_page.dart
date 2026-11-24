import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:icex_atlas/core/auth/session_controller.dart';
import 'package:icex_atlas/core/errors/failure.dart';
import 'package:icex_atlas/core/providers.dart';
import 'package:icex_atlas/core/router/app_router.dart';
import 'package:icex_atlas/core/theme/icex_theme.dart';
import 'package:icex_atlas/features/orientador/domain/orientador.dart';
import 'package:icex_atlas/features/profiles/domain/profile.dart';
import 'package:icex_atlas/l10n/app_localizations.dart';
import 'package:icex_atlas/shared/widgets/app_shell.dart';
import 'package:icex_atlas/shared/widgets/badges.dart';
import 'package:icex_atlas/shared/widgets/common.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'orientador_page.g.dart';

class OrientadorState {
  const OrientadorState({
    required this.query,
    this.history = const [],
    this.loading = false,
    this.error,
  });

  final OrientadorQuery query;
  final List<OrientadorResult> history;
  final bool loading;
  final Object? error;

  OrientadorState copyWith({
    OrientadorQuery? query,
    List<OrientadorResult>? history,
    bool? loading,
    Object? Function()? error,
  }) => OrientadorState(
    query: query ?? this.query,
    history: history ?? this.history,
    loading: loading ?? this.loading,
    error: error == null ? this.error : error(),
  );
}

@riverpod
class OrientadorController extends _$OrientadorController {
  @override
  OrientadorState build() {
    final s = ref.read(sessionControllerProvider);
    final fase = s is SignedIn ? s.me.profile.card.fase : Fase.fase1;
    return OrientadorState(
      query: OrientadorQuery(fase: fase, pais: 'Alemania', sector: 'Energía', consulta: ''),
    );
  }

  void update(OrientadorQuery q) => state = state.copyWith(query: q);

  void applyShortcut((String, Fase, String, String, String) a) => state = state.copyWith(
    query: OrientadorQuery(fase: a.$2, pais: a.$3, sector: a.$4, consulta: a.$5),
  );

  Future<void> ask() async {
    if (state.loading) return;
    state = state.copyWith(loading: true, error: () => null);
    try {
      final r = await ref.read(orientadorRepositoryProvider).ask(state.query);
      if (!ref.mounted) return;
      state = state.copyWith(
        history: [r, ...state.history],
        loading: false,
        query: state.query.copyWith(consulta: ''),
      );
    } on Object catch (e) {
      if (ref.mounted) state = state.copyWith(loading: false, error: () => e);
    }
  }
}

/// Orientador con IA: fase, país, sector, consulta libre, atajos y pasos + alumni sugeridos.
class OrientadorPage extends ConsumerStatefulWidget {
  const OrientadorPage({super.key});

  @override
  ConsumerState<OrientadorPage> createState() => _OrientadorPageState();
}

class _OrientadorPageState extends ConsumerState<OrientadorPage> {
  late final TextEditingController _text = TextEditingController(
    text: ref.read(orientadorControllerProvider).query.consulta,
  );

  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final s = ref.watch(orientadorControllerProvider);
    final c = ref.read(orientadorControllerProvider.notifier);
    listenScrollToTop(ref, AppTab.orientador, _scroll);
    // Sincroniza el campo cuando la consulta cambia desde fuera (atajos o tras enviar).
    // Antes se asignaba `_text.text` dentro de build: notificaba durante la construcción y
    // mandaba el cursor al principio.
    ref.listen(orientadorControllerProvider.select((x) => x.query.consulta), (_, v) {
      if (_text.text != v) {
        _text.value = TextEditingValue(
          text: v,
          selection: TextSelection.collapsed(offset: v.length),
        );
      }
    });

    Widget select<T>(
      String label,
      T value,
      List<T> items,
      String Function(T) text,
      void Function(T) onChanged,
    ) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<T>(
        // `initialValue` solo se lee al crear el campo: la clave lo recrea cuando un atajo
        // cambia la fase, el país o el sector (antes el desplegable seguía mostrando el
        // valor anterior aunque la consulta ya era otra).
        key: ValueKey('$label|$value'),
        initialValue: value,
        isExpanded: true,
        decoration: InputDecoration(labelText: label),
        items: [for (final i in items) DropdownMenuItem(value: i, child: Text(text(i)))],
        onChanged: (v) => v == null ? null : onChanged(v),
      ),
    );

    return ListView(
      controller: _scroll,
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        if (ref.watch(appEnvProvider).showDemoBanner) const DemoBanner(),
        PageHeader(
          title: l.orientadorTitle,
          subtitle: l.orientadorSubtitle(s.history.length),
          leading: const Icon(Icons.explore_outlined, color: IcexColors.primary, size: 28),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: IcexCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(l.orientadorIdeas, style: t.titleSmall),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final a in OrientadorCatalog.atajos)
                      ActionChip(
                        avatar: const Icon(Icons.auto_awesome_outlined, color: IcexColors.primary),
                        label: Text(a.$1),
                        onPressed: () => c.applyShortcut(a),
                      ),
                  ],
                ),
                const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Divider()),
                select<Fase>(
                  l.orientadorPhase,
                  s.query.fase,
                  Fase.values,
                  (f) => f == Fase.activo ? 'Activo' : f.label,
                  (f) => c.update(s.query.copyWith(fase: f)),
                ),
                select<String>(
                  l.orientadorCountry,
                  s.query.pais,
                  OrientadorCatalog.paises,
                  (p) => p,
                  (p) => c.update(s.query.copyWith(pais: p)),
                ),
                select<String>(
                  l.orientadorSector,
                  s.query.sector,
                  OrientadorCatalog.sectores,
                  (p) => p,
                  (p) => c.update(s.query.copyWith(sector: p)),
                ),
                TextField(
                  key: const Key('orientador-text'),
                  controller: _text,
                  minLines: 3,
                  maxLines: 6,
                  maxLength: 2000,
                  buildCounter: (_, {required currentLength, required isFocused, maxLength}) =>
                      null,
                  onChanged: (v) =>
                      c.update(ref.read(orientadorControllerProvider).query.copyWith(consulta: v)),
                  decoration: InputDecoration(hintText: l.orientadorHint),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: FilledButton.icon(
                    onPressed: s.loading
                        ? null
                        : () {
                            FocusScope.of(context).unfocus();
                            unawaited(c.ask());
                          },
                    icon: s.loading
                        ? const SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.send),
                    label: Text(s.loading ? l.orientadorLoading : l.orientadorSubmit),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (s.error != null)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              s.error is RateLimitedFailure
                  ? l.orientadorRateLimited
                  : ErrorView.messageFor(l, s.error!),
              style: t.bodyMedium?.copyWith(color: IcexColors.destructive),
            ),
          ),
        for (final r in s.history)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: OrientadorResultCard(result: r),
          ),
      ],
    );
  }
}

class OrientadorResultCard extends StatelessWidget {
  const OrientadorResultCard({required this.result, super.key});

  final OrientadorResult result;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    return IcexCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(result.resumen, style: t.titleMedium),
          const SizedBox(height: 12),
          Semantics(header: true, child: Text(l.orientadorSteps, style: t.titleSmall)),
          const SizedBox(height: 6),
          for (final (i, p) in result.pasos.indexed)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 12,
                    backgroundColor: IcexColors.primary,
                    child: Text(
                      '${i + 1}',
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text(p, style: t.bodyLarge)),
                ],
              ),
            ),
          if (result.alumni.isNotEmpty) ...[
            const SizedBox(height: 8),
            Semantics(header: true, child: Text(l.orientadorAlumni, style: t.titleSmall)),
            for (final a in result.alumni)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(a.nombre),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(a.motivo),
                    if (a.fase != null && a.promocion != null) ...[
                      const SizedBox(height: 4),
                      PhasePromoRow(fase: a.fase!, promocion: a.promocion!),
                    ],
                  ],
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push(Routes.profile(a.slug)),
              ),
          ],
          const SizedBox(height: 8),
          Text(result.aviso, style: t.bodySmall),
          if (result.restantes != null)
            Text(l.orientadorRemaining(result.restantes!), style: t.bodySmall),
        ],
      ),
    );
  }
}
