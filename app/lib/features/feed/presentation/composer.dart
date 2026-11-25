import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:icex_atlas/core/router/app_router.dart';
import 'package:icex_atlas/core/theme/icex_theme.dart';
import 'package:icex_atlas/features/feed/domain/post.dart';
import 'package:icex_atlas/features/feed/presentation/compose_page.dart';
import 'package:icex_atlas/features/profiles/domain/profile.dart';
import 'package:icex_atlas/l10n/app_localizations.dart';
import 'package:icex_atlas/shared/widgets/avatar.dart';
import 'package:icex_atlas/shared/widgets/common.dart';

/// «Comparte una novedad…» con accesos a Foto, Oferta y Evento (mockup), como el
/// «Empieza una publicación» de LinkedIn: al tocarlo se abre el compositor a pantalla completa.
class Composer extends StatelessWidget {
  const Composer({required this.me, this.floating = false, super.key});

  final ProfileCard me;

  /// Tarjeta redondeada sobre la cabecera roja (Inicio), en vez de banda a todo el ancho.
  final bool floating;

  Future<void> _open(BuildContext context, [ComposeArgs args = const ComposeArgs()]) async {
    final l = AppLocalizations.of(context);
    final published = await context.push<bool>(Routes.compose, extra: args);
    if ((published ?? false) && context.mounted) showSnack(context, l.composerPublished);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    Widget quick(IconData icon, Color color, String label, ComposeArgs args) => Expanded(
      child: TextButton.icon(
        onPressed: () => unawaited(_open(context, args)),
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          foregroundColor: IcexColors.mutedForeground,
        ),
        icon: Icon(icon, size: 20, color: color),
        label: Text(label, overflow: TextOverflow.ellipsis),
      ),
    );

    return Material(
      color: IcexColors.card,
      elevation: floating ? 6 : 0,
      shadowColor: const Color(0x55000000),
      shape: floating
          ? RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))
          : const Border.symmetric(horizontal: BorderSide(color: IcexColors.border)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        child: Column(
          children: [
            Row(
              children: [
                InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () => context.push(Routes.profile(me.slug)),
                  child: SizedBox.square(
                    dimension: 48,
                    child: Center(child: Avatar.of(me, size: 42, ring: true)),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Semantics(
                    button: true,
                    child: InkWell(
                      key: const Key('composer-open'),
                      borderRadius: BorderRadius.circular(999),
                      onTap: () => unawaited(_open(context)),
                      child: Container(
                        height: 48,
                        alignment: Alignment.centerLeft,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: IcexColors.border),
                        ),
                        child: Text(
                          l.composerHint,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: t.bodyMedium?.copyWith(color: IcexColors.mutedForeground),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                quick(
                  Icons.image_outlined,
                  const Color(0xFF2E7D32),
                  l.composerPhoto,
                  const ComposeArgs(pickImage: true),
                ),
                quick(
                  Icons.work_outline,
                  IcexColors.primary,
                  l.composerOffer,
                  const ComposeArgs(tipo: PostTipo.oportunidadLaboral),
                ),
                quick(
                  Icons.calendar_month_outlined,
                  const Color(0xFFB26A00),
                  l.composerEvent,
                  const ComposeArgs(tipo: PostTipo.evento),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
