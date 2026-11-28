import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:icex_atlas/core/db/app_database.dart';
import 'package:icex_atlas/core/providers.dart';
import 'package:icex_atlas/core/router/app_router.dart';
import 'package:icex_atlas/core/theme/icex_theme.dart';
import 'package:icex_atlas/features/profiles/domain/profile_completion.dart';
import 'package:icex_atlas/l10n/app_localizations.dart';

/// Si el aviso de Inicio se descartó. Se guarda en el dispositivo (y se borra al cerrar
/// sesión con el resto de datos locales). En el propio perfil el aviso no se descarta.
class ProfileCompletionDismissed extends AsyncNotifier<bool> {
  static const _key = 'ui:profile-completion-dismissed';

  @override
  Future<bool> build() async {
    final db = ref.watch(appDatabaseProvider);
    final row = await (db.select(
      db.cachedPages,
    )..where((t) => t.key.equals(_key))).getSingleOrNull();
    return row != null;
  }

  Future<void> dismiss() async {
    state = const AsyncData(true);
    final db = ref.read(appDatabaseProvider);
    await db
        .into(db.cachedPages)
        .insertOnConflictUpdate(
          CachedPagesCompanion(
            key: const Value(_key),
            json: const Value('true'),
            updatedAt: Value(DateTime.now()),
          ),
        );
  }
}

final profileCompletionDismissedProvider = AsyncNotifierProvider<ProfileCompletionDismissed, bool>(
  ProfileCompletionDismissed.new,
);

/// «Completa tu perfil»: progreso y lo que falta, con acceso directo a editarlo.
class ProfileCompletionCard extends ConsumerWidget {
  const ProfileCompletionCard({required this.completion, this.dismissible = false, super.key});

  final ProfileCompletion completion;

  /// En Inicio se puede descartar; en el perfil propio no.
  final bool dismissible;

  static String label(AppLocalizations l, ProfileItem i) => switch (i) {
    ProfileItem.photo => l.completionPhoto,
    ProfileItem.position => l.completionPosition,
    ProfileItem.location => l.completionLocation,
    ProfileItem.sector => l.completionSector,
    ProfileItem.bio => l.completionBio,
    ProfileItem.experience => l.completionExperience,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (completion.isComplete) return const SizedBox.shrink();
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    return Material(
      key: const Key('profile-completion'),
      color: IcexColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(IcexTheme.radius),
        side: const BorderSide(color: IcexColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(l.completionTitle(completion.percent), style: t.titleSmall),
                  ),
                ),
                if (dismissible)
                  IconButton(
                    key: const Key('profile-completion-dismiss'),
                    tooltip: l.dismiss,
                    visualDensity: VisualDensity.compact,
                    iconSize: 18,
                    onPressed: () =>
                        ref.read(profileCompletionDismissedProvider.notifier).dismiss(),
                    icon: const Icon(Icons.close),
                  )
                else
                  const SizedBox(height: 40),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: completion.ratio,
                  minHeight: 6,
                  color: IcexColors.primary,
                  backgroundColor: IcexColors.muted,
                  semanticsLabel: l.completionTitle(completion.percent),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text(l.completionWhy, style: t.bodySmall),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final i in completion.missing)
                  ActionChip(
                    avatar: const Icon(Icons.add, size: 16),
                    label: Text(label(l, i)),
                    visualDensity: VisualDensity.compact,
                    onPressed: () => context.push(Routes.editProfile),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
