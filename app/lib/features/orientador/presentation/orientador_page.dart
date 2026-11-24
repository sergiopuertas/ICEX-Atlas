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
import 'package:icex_atlas/shared/widgets/brand.dart';
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
    // Contexto inicial tomado del propio perfil (fase, país y sector), si encaja en el
    // catálogo. Se puede cambiar, pero en la mayoría de consultas no hace falta.
    final s = ref.read(sessionControllerProvider);
    final me = s is SignedIn ? s.me.profile.card : null;
    String pick(String? v, List<String> options, String fallback) =>
        options.contains(v) ? v! : fallback;
    return OrientadorState(
      query: OrientadorQuery(
        fase: me?.fase ?? Fase.fase1,
        pais: pick(me?.pais, OrientadorCatalog.paises, 'España'),
        sector: pick(me?.sector, OrientadorCatalog.sectores, 'Consultoría'),
        consulta: '',
      ),
    );
  }

  void update(OrientadorQuery q) => state = state.copyWith(query: q);

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

/// Orientador: el contexto (fase, país y sector, ya rellenos con el perfil) y un botón.
/// Sin texto libre ni sugerencias prefabricadas: se elige y se pide.
class OrientadorPage extends ConsumerStatefulWidget {
  const OrientadorPage({super.key});

  @override
  ConsumerState<OrientadorPage> createState() => _OrientadorPageState();
}

class _OrientadorPageState extends ConsumerState<OrientadorPage> {
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<T?> _pick<T>(String title, List<T> options, T current, String Function(T) label) =>
      showModalBottomSheet<T>(
        context: context,
        showDragHandle: true,
        useRootNavigator: true,
        isScrollControlled: true,
        builder: (c) => SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(c).height * 0.7),
            child: ListView(
              shrinkWrap: true,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                  child: Text(title, style: Theme.of(c).textTheme.titleMedium),
                ),
                for (final o in options)
                  ListTile(
                    title: Text(label(o)),
                    trailing: o == current
                        ? const Icon(Icons.check, color: IcexColors.primary)
                        : null,
                    onTap: () => Navigator.pop(c, o),
                  ),
              ],
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final s = ref.watch(orientadorControllerProvider);
    final c = ref.read(orientadorControllerProvider.notifier);
    listenScrollToTop(ref, AppTab.orientador, _scroll);
    String faseLabel(Fase f) => f == Fase.activo ? 'Activo' : f.label;

    return ListView(
      controller: _scroll,
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        HeroHeader(title: l.orientadorTitle, subtitle: l.orientadorIntro),
        if (ref.watch(appEnvProvider).showDemoBanner) const DemoBanner(),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: IcexCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(l.orientadorContext, style: t.titleMedium),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _ContextPill(
                      label: l.orientadorPhase,
                      value: faseLabel(s.query.fase),
                      onTap: () async {
                        final f = await _pick(
                          l.orientadorPhase,
                          Fase.values,
                          s.query.fase,
                          faseLabel,
                        );
                        if (f != null) c.update(s.query.copyWith(fase: f));
                      },
                    ),
                    _ContextPill(
                      label: l.orientadorCountry,
                      value: s.query.pais,
                      onTap: () async {
                        final p = await _pick(
                          l.orientadorCountry,
                          OrientadorCatalog.paises,
                          s.query.pais,
                          (x) => x,
                        );
                        if (p != null) c.update(s.query.copyWith(pais: p));
                      },
                    ),
                    _ContextPill(
                      label: l.orientadorSector,
                      value: s.query.sector,
                      onTap: () async {
                        final p = await _pick(
                          l.orientadorSector,
                          OrientadorCatalog.sectores,
                          s.query.sector,
                          (x) => x,
                        );
                        if (p != null) c.update(s.query.copyWith(sector: p));
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                FilledButton(
                  key: const Key('orientador-submit'),
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                  onPressed: s.loading
                      ? null
                      : () {
                          FocusScope.of(context).unfocus();
                          unawaited(c.ask());
                        },
                  child: s.loading
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox.square(
                              dimension: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            ),
                            const SizedBox(width: 10),
                            Text(l.orientadorLoading),
                          ],
                        )
                      : Text(l.orientadorSubmit),
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

/// Selector compacto del contexto: «País · Alemania ▾».
class _ContextPill extends StatelessWidget {
  const _ContextPill({required this.label, required this.value, required this.onTap});

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Semantics(
      button: true,
      label: '$label: $value',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.fromLTRB(14, 6, 8, 6),
          decoration: BoxDecoration(
            color: IcexColors.muted,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(text: '$label · ', style: t.bodySmall),
                      TextSpan(
                        text: value,
                        style: t.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Icon(Icons.arrow_drop_down, size: 20),
            ],
          ),
        ),
      ),
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
                  SizedBox(
                    width: 24,
                    child: Text(
                      '${i + 1}.',
                      style: t.titleSmall?.copyWith(color: IcexColors.primary),
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
