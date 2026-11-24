import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:icex_atlas/core/router/app_router.dart';
import 'package:icex_atlas/core/theme/icex_theme.dart';
import 'package:icex_atlas/core/utils/time_ago.dart';
import 'package:icex_atlas/features/feed/domain/post.dart';
import 'package:icex_atlas/l10n/app_localizations.dart';
import 'package:icex_atlas/shared/widgets/avatar.dart';
import 'package:icex_atlas/shared/widgets/badges.dart';
import 'package:icex_atlas/shared/widgets/expandable_text.dart';
import 'package:icex_atlas/shared/widgets/image_viewer.dart';

/// Tarjeta de publicación.
///
/// Estructura inspirada en LinkedIn: tipo (si lo hay) → autor con titular, antigüedad, fase y
/// promoción → texto recortado con «…ver más» → imagen de borde a borde → contadores →
/// barra de acciones con icono sobre etiqueta (caben las cuatro sin encoger el texto).
/// De Instagram: doble toque en la imagen para Recomendar, con animación de corazón.
class PostCard extends StatefulWidget {
  const PostCard({
    required this.post,
    required this.onRecommend,
    required this.onComment,
    required this.onShare,
    this.isOwn = false,
    this.onMore,
    this.onSend,
    this.now,
    this.flat = false,
    this.fullText = false,
    super.key,
  });

  /// Texto completo, sin «Leer más» (pantalla de detalle).
  final bool fullText;

  final Post post;
  final VoidCallback onRecommend;
  final VoidCallback onComment;
  final VoidCallback onShare;
  final VoidCallback? onMore;

  /// «Enviar» (abre chat con el autor). Por defecto navega al chat.
  final VoidCallback? onSend;
  final bool isOwn;

  /// Sin bordes ni esquinas: publicación a todo el ancho en el feed (estilo LinkedIn).
  final bool flat;

  /// Para tests deterministas (golden).
  final DateTime? now;

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> with SingleTickerProviderStateMixin {
  late final AnimationController _burst = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 650),
  );

  @override
  void dispose() {
    _burst.dispose();
    super.dispose();
  }

  void _doubleTapRecommend() {
    unawaited(HapticFeedback.lightImpact());
    _burst.forward(from: 0);
    if (!widget.post.recomendado) widget.onRecommend();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final post = widget.post;
    final a = post.autor;
    const hPad = EdgeInsets.symmetric(horizontal: 16);
    void openAuthor() => context.push(Routes.profile(a.slug));

    final content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (post.tipo.hasBadge)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: PostTypeBadge(post.tipo),
          ),
        Padding(
          padding: EdgeInsets.fromLTRB(16, post.tipo.hasBadge ? 10 : 14, 4, 0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                button: true,
                label: a.nombre,
                excludeSemantics: true,
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: openAuthor,
                  child: Avatar.of(a, size: 46, ring: true),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: InkWell(
                  onTap: openAuthor,
                  borderRadius: BorderRadius.circular(6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        a.nombre,
                        style: t.titleSmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (a.headline.isNotEmpty)
                        Text(
                          a.headline,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: t.bodySmall?.copyWith(fontSize: 13),
                        ),
                      const SizedBox(height: 3),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(timeAgo(l, post.createdAt, now: widget.now), style: t.bodySmall),
                          PhaseBadge(a.fase, compact: true),
                          PromoBadge(a.promocion, compact: true),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              if (widget.onMore != null)
                IconButton(
                  tooltip: l.moreOptions,
                  onPressed: widget.onMore,
                  icon: const Icon(Icons.more_horiz, color: IcexColors.mutedForeground),
                ),
            ],
          ),
        ),
        if (post.titulo != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Text(post.titulo!, style: t.titleMedium),
          ),
        if (post.texto.isNotEmpty)
          Padding(
            padding: EdgeInsets.fromLTRB(16, post.titulo == null ? 12 : 6, 16, 0),
            child: widget.fullText
                ? Text(post.texto, style: t.bodyLarge?.copyWith(fontSize: 15.5, height: 1.45))
                : ExpandableText(
                    post.texto,
                    style: t.bodyLarge?.copyWith(fontSize: 15.5, height: 1.45),
                  ),
          ),
        if (post.compartido != null)
          Padding(padding: hPad, child: _SharedPreview(post.compartido!)),
        if (post.media.isNotEmpty)
          _PostImage(
            path: post.media.first,
            flat: widget.flat,
            burst: _burst,
            onDoubleTap: _doubleTapRecommend,
          ),
        _Counts(post: post, onComments: widget.onComment),
        const Padding(padding: hPad, child: Divider()),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            children: [
              _Action(
                icon: post.recomendado ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                label: l.recommend,
                selected: post.recomendado,
                onTap: () {
                  unawaited(HapticFeedback.selectionClick());
                  widget.onRecommend();
                },
              ),
              _Action(icon: Icons.mode_comment_outlined, label: l.comment, onTap: widget.onComment),
              _Action(icon: Icons.repeat_rounded, label: l.share, onTap: widget.onShare),
              if (!widget.isOwn)
                _Action(
                  icon: Icons.send_outlined,
                  label: l.send,
                  onTap: widget.onSend ?? () => context.push(Routes.chatWith(a.userId)),
                ),
            ],
          ),
        ),
      ],
    );

    return Material(
      color: IcexColors.card,
      clipBehavior: Clip.antiAlias,
      shape: widget.flat
          ? const Border.symmetric(horizontal: BorderSide(color: IcexColors.border))
          : RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(IcexTheme.radius),
              side: const BorderSide(color: IcexColors.border),
            ),
      child: content,
    );
  }
}

class _Counts extends StatelessWidget {
  const _Counts({required this.post, required this.onComments});

  final Post post;
  final VoidCallback onComments;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final recos = post.recomendacionesCount;
    final comments = post.comentariosCount;
    if (recos == 0 && comments == 0) return const SizedBox(height: 10);
    // Nodo propio para el lector de pantalla: «76 recomendaciones, 18 comentarios».
    // Sin él, el recuento se fundía con la publicación entera en un único nodo.
    return Semantics(
      container: true,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
        // spaceBetween en lugar de Spacer: con Spacer cada lado solo recibía un tercio del
        // ancho y «76 recomendaciones» se cortaba aunque hubiera sitio.
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            if (recos > 0)
              Flexible(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 18,
                      height: 18,
                      decoration: const BoxDecoration(
                        color: IcexColors.primary,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.favorite_rounded, size: 11, color: Colors.white),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        l.recommendationsCount(recos),
                        style: t.bodySmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              )
            else
              const SizedBox.shrink(),
            if (comments > 0)
              Flexible(
                child: InkWell(
                  onTap: onComments,
                  borderRadius: BorderRadius.circular(8),
                  // Zona táctil de 48 dp de alto sin cambiar el aspecto de la línea.
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
                    child: Align(
                      alignment: Alignment.centerRight,
                      widthFactor: 1,
                      child: Text(
                        l.commentsCount(comments),
                        style: t.bodySmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({
    required this.icon,
    required this.label,
    required this.onTap,
    this.selected = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final color = selected ? IcexColors.primary : IcexColors.mutedForeground;
    return Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        label: label,
        excludeSemantics: true,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 52),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  transitionBuilder: (child, a) => ScaleTransition(
                    scale: Tween<double>(
                      begin: 0.6,
                      end: 1,
                    ).animate(CurvedAnimation(parent: a, curve: Curves.elasticOut)),
                    child: child,
                  ),
                  child: Icon(icon, key: ValueKey(icon), size: 22, color: color),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SharedPreview extends StatelessWidget {
  const _SharedPreview(this.shared);

  final SharedPost shared;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Material(
        color: IcexColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: IcexColors.border),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => context.push(Routes.post(shared.id)),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Avatar.of(shared.autor, size: 24),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        AppLocalizations.of(context).sharedFrom(shared.autor.nombre),
                        style: t.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  shared.texto,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: t.bodyMedium,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PostImage extends ConsumerWidget {
  const _PostImage({
    required this.path,
    required this.flat,
    required this.burst,
    required this.onDoubleTap,
  });

  final String path;
  final bool flat;
  final Animation<double> burst;
  final VoidCallback onDoubleTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final url = ref.watch(signedImageUrlProvider(('post-media', path, 1080))).value;
    final cacheKey = 'post-media/$path';
    final heroTag = 'post-media/$path/${identityHashCode(this)}';
    final image = AspectRatio(
      aspectRatio: 5 / 4,
      child: url == null
          ? const ColoredBox(color: IcexColors.muted)
          : Hero(
              tag: heroTag,
              child: CachedNetworkImage(
                imageUrl: url,
                cacheKey: cacheKey,
                fit: BoxFit.cover,
                // Decodificar al tamaño en pantalla, no al del archivo: decodificar fotos
                // grandes en el hilo de interfaz era una de las causas de tirones al hacer
                // scroll.
                memCacheWidth:
                    (MediaQuery.sizeOf(context).width * MediaQuery.devicePixelRatioOf(context))
                        .round(),
                fadeInDuration: const Duration(milliseconds: 150),
                placeholder: (_, _) => const ColoredBox(color: IcexColors.muted),
                errorWidget: (_, _, _) => const ColoredBox(
                  color: IcexColors.muted,
                  child: Icon(Icons.broken_image_outlined, color: IcexColors.mutedForeground),
                ),
              ),
            ),
    );
    return Padding(
      padding: EdgeInsets.fromLTRB(flat ? 0 : 12, 12, flat ? 0 : 12, 0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(flat ? 0 : 10),
        child: GestureDetector(
          onTap: url == null
              ? null
              : () => unawaited(
                  showImageViewer(context, url: url, cacheKey: cacheKey, heroTag: heroTag),
                ),
          onDoubleTap: onDoubleTap,
          child: Stack(
            alignment: Alignment.center,
            children: [
              image,
              _HeartBurst(animation: burst),
            ],
          ),
        ),
      ),
    );
  }
}

/// Corazón que aparece y se desvanece al recomendar con doble toque.
class _HeartBurst extends AnimatedWidget {
  const _HeartBurst({required Animation<double> animation}) : super(listenable: animation);

  @override
  Widget build(BuildContext context) {
    final v = (listenable as Animation<double>).value;
    if (v == 0 || v == 1) return const SizedBox.shrink();
    final scale = Curves.elasticOut.transform((v * 1.6).clamp(0, 1));
    final opacity = v < 0.7 ? 1.0 : (1 - (v - 0.7) / 0.3);
    return IgnorePointer(
      child: Opacity(
        opacity: opacity.clamp(0, 1),
        child: Transform.scale(
          scale: 0.4 + scale * 0.6,
          child: const Icon(
            Icons.favorite_rounded,
            size: 96,
            color: Colors.white,
            shadows: [Shadow(color: Color(0x55000000), blurRadius: 16)],
          ),
        ),
      ),
    );
  }
}

/// Novedad oficial fijada, en formato compacto: icono, etiqueta, título y una línea de texto.
class FeaturedNewsBanner extends StatelessWidget {
  const FeaturedNewsBanner({required this.post, required this.onTap, super.key});

  final Post post;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Material(
      color: const Color(0xFFFFF7F7),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(IcexTheme.radius),
        side: const BorderSide(color: Color(0xFFF2B8BC)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(IcexTheme.radius),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: IcexColors.primary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.campaign_rounded, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const PostTypeBadge(PostTipo.novedadOficial),
                    const SizedBox(height: 4),
                    Text(
                      post.titulo ?? '',
                      style: t.titleSmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      post.texto,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: t.bodySmall,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: IcexColors.mutedForeground),
            ],
          ),
        ),
      ),
    );
  }
}
