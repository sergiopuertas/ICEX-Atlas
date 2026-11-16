import 'package:flutter/material.dart';
import 'package:icex_atlas/core/theme/icex_theme.dart';
import 'package:icex_atlas/l10n/app_localizations.dart';

/// Botón Seguir / Siguiendo del mockup (rojo relleno / contorno).
class FollowButton extends StatelessWidget {
  const FollowButton({
    required this.following,
    required this.onPressed,
    this.small = false,
    super.key,
  });

  final bool following;
  final VoidCallback? onPressed;
  final bool small;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final size = small ? const Size(0, 36) : const Size(0, 44);
    final pad = EdgeInsets.symmetric(horizontal: small ? 14 : 20);
    return following
        ? OutlinedButton.icon(
            onPressed: onPressed,
            icon: const Icon(Icons.check, size: 18),
            label: Text(l.followingButton),
            style: OutlinedButton.styleFrom(minimumSize: size, padding: pad),
          )
        : FilledButton.icon(
            onPressed: onPressed,
            icon: const Icon(Icons.person_add_alt_1_outlined, size: 18),
            label: Text(l.follow),
            style: FilledButton.styleFrom(
              minimumSize: size,
              padding: pad,
              backgroundColor: IcexColors.primary,
            ),
          );
  }
}
