import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:icex_atlas/core/providers.dart';
import 'package:icex_atlas/core/theme/icex_theme.dart';
import 'package:icex_atlas/features/profiles/domain/profile.dart';

/// URL firmada (bucket privado) con transformación de tamaño en Storage.
///
/// Se conserva 50 min (la firma dura 60): antes se descartaba en cuanto el avatar salía de
/// pantalla, y al volver a hacer scroll cada foto mostraba las iniciales hasta resolver otra
/// vez la URL (parpadeo), aunque la imagen ya estuviera en la caché de disco.
// ignore: specify_nonobvious_property_types (tipo interno de Riverpod)
final signedImageUrlProvider = FutureProvider.autoDispose.family<String, (String, String, int)>((
  ref,
  args,
) async {
  final url = await ref
      .watch(apiClientProvider)
      .signedUrl(args.$1, args.$2, width: args.$3, height: args.$3);
  final link = ref.keepAlive();
  final timer = Timer(const Duration(minutes: 50), link.close);
  ref.onDispose(timer.cancel);
  return url;
});

/// Avatar circular con anillo del color de la fase (mockup). Iniciales si no hay foto.
class Avatar extends ConsumerWidget {
  const Avatar({
    required this.nombre,
    required this.fase,
    this.fotoPath,
    this.size = 44,
    this.ring = false,
    super.key,
  });

  factory Avatar.of(ProfileCard p, {double size = 44, bool ring = false, Key? key}) => Avatar(
    nombre: p.nombre,
    fase: p.fase,
    fotoPath: p.fotoPath,
    size: size,
    ring: ring,
    key: key,
  );

  final String nombre;
  final Fase fase;
  final String? fotoPath;
  final double size;
  final bool ring;

  String get _initials {
    final parts = nombre.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    return (parts.first[0] + (parts.length > 1 ? parts[1][0] : '')).toUpperCase();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Tamaños redondeados a escalones: menos variantes de la misma foto en Storage y caché.
    final raw = (size * MediaQuery.devicePixelRatioOf(context)).round().clamp(48, 400);
    final px = const [64, 128, 200, 300, 400].firstWhere((b) => b >= raw, orElse: () => 400);
    final fallback = CircleAvatar(
      backgroundColor: IcexColors.muted,
      child: Text(
        _initials,
        style: TextStyle(
          fontSize: size * 0.36,
          fontWeight: FontWeight.w700,
          color: IcexColors.mutedForeground,
        ),
      ),
    );
    Widget image = fallback;
    if (fotoPath != null) {
      final url = ref.watch(signedImageUrlProvider(('avatars', fotoPath!, px)));
      image = url.maybeWhen(
        data: (u) => ClipOval(
          child: CachedNetworkImage(
            imageUrl: u,
            cacheKey: 'avatars/$fotoPath@$px',
            fit: BoxFit.cover,
            width: size,
            height: size,
            memCacheWidth: px,
            memCacheHeight: px,
            errorWidget: (_, _, _) => fallback,
            placeholder: (_, _) => fallback,
          ),
        ),
        orElse: () => fallback,
      );
    }
    return Semantics(
      label: 'Foto de $nombre',
      image: true,
      excludeSemantics: true,
      child: Container(
        width: size,
        height: size,
        padding: ring ? EdgeInsets.all(size > 60 ? 3 : 2) : EdgeInsets.zero,
        decoration: ring
            ? BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: IcexColors.phase(fase), width: size > 60 ? 3 : 2),
              )
            : null,
        child: image,
      ),
    );
  }
}
