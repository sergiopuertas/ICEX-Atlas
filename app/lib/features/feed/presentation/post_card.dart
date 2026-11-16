import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:icex_atlas/core/router/app_router.dart';
import 'package:icex_atlas/core/theme/icex_theme.dart';
import 'package:icex_atlas/core/utils/time_ago.dart';
import 'package:icex_atlas/features/feed/domain/post.dart';
import 'package:icex_atlas/l10n/app_localizations.dart';
import 'package:icex_atlas/shared/widgets/avatar.dart';
import 'package:icex_atlas/shared/widgets/badges.dart';
import 'package:icex_atlas/shared/widgets/common.dart';

/// Tarjeta de publicación del mockup: badge de tipo, autor (fase, promoción, cargo,
/// antigüedad), texto, contadores y acciones Recomendar · Comentar · Compartir · Enviar.
class PostCard extends StatelessWidget {
  const PostCard({
    required this.post,
    required this.onRecommend,
    required this.onComment,
    required this.onShare,
    this.isOwn = false,
    this.onMore,
    this.now,
    super.key,
  });

  final Post post;
  final VoidCallback onRecommend;
  final VoidCallback onComment;
  final VoidCallback onShare;
  final VoidCallback? onMore;
  final bool isOwn;

  /// Para tests deterministas (golden).
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final a = post.autor;
    return IcexCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (post.tipo.hasBadge) ...[PostTypeBadge(post.tipo), const SizedBox(height: 10)],
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InkWell(
                customBorder: const CircleBorder(),
                onTap: () => context.push(Routes.profile(a.slug)),
                child: Avatar.of(a, size: 48, ring: true),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Semantics(
                          link: true,
                          child: GestureDetector(
                            onTap: () => context.push(Routes.profile(a.slug)),
                            child: Text(a.nombre, style: t.titleSmall),
                          ),
                        ),
                        PhaseBadge(a.fase),
                        PromoBadge(a.promocion),
                      ],
                    ),
                    if (a.headline.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          a.headline,
                          style: t.bodyMedium?.copyWith(color: IcexColors.mutedForeground),
                        ),
                      ),
                    Text(timeAgo(l, post.createdAt, now: now), style: t.bodySmall),
                  ],
                ),
              ),
              if (onMore != null)
                IconButton(
                  tooltip: isOwn ? l.deletePost : l.report,
                  onPressed: onMore,
                  icon: const Icon(Icons.more_horiz, color: IcexColors.mutedForeground),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (post.titulo != null) ...[
            Text(post.titulo!, style: t.titleMedium),
            const SizedBox(height: 6),
          ],
          SelectableText(post.texto, style: t.bodyLarge),
          if (post.compartido != null) _SharedPreview(post.compartido!),
          if (post.media.isNotEmpty) _PostImage(path: post.media.first),
          const SizedBox(height: 12),
          Row(
            children: [
              Text(l.recommendationsCount(post.recomendacionesCount), style: t.bodySmall),
              const Spacer(),
              Text(l.commentsCount(post.comentariosCount), style: t.bodySmall),
            ],
          ),
          const Padding(padding: EdgeInsets.only(top: 8), child: Divider()),
          Row(
            children: [
              _Action(
                icon: post.recomendado ? Icons.favorite : Icons.favorite_border,
                label: l.recommend,
                selected: post.recomendado,
                onTap: onRecommend,
              ),
              _Action(icon: Icons.mode_comment_outlined, label: l.comment, onTap: onComment),
              _Action(icon: Icons.repeat, label: l.share, onTap: onShare),
              if (!isOwn)
                _Action(
                  icon: Icons.send_outlined,
                  label: l.send,
                  onTap: () => context.push(Routes.chatWith(a.userId)),
                ),
            ],
          ),
        ],
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
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 19, color: color),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                ],
              ),
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
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: IcexColors.secondary,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(AppLocalizations.of(context).sharedFrom(shared.autor.nombre), style: t.bodySmall),
          const SizedBox(height: 4),
          Text(shared.texto, maxLines: 4, overflow: TextOverflow.ellipsis, style: t.bodyMedium),
        ],
      ),
    );
  }
}

class _PostImage extends ConsumerWidget {
  const _PostImage({required this.path});

  final String path;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final url = ref.watch(signedImageUrlProvider(('post-media', path, 1080)));
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: AspectRatio(
          aspectRatio: 4 / 3,
          child: url.maybeWhen(
            data: (u) =>
                CachedNetworkImage(imageUrl: u, cacheKey: 'post-media/$path', fit: BoxFit.cover),
            orElse: () => const ColoredBox(color: IcexColors.muted),
          ),
        ),
      ),
    );
  }
}

/// Banner destacado de novedad oficial fijada (rosa pálido con borde rojo, como el mockup).
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
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const PostTypeBadge(PostTipo.novedadOficial),
              const SizedBox(height: 8),
              Text(post.titulo ?? '', style: t.titleMedium),
              const SizedBox(height: 6),
              Text(post.texto, style: t.bodyMedium?.copyWith(color: IcexColors.mutedForeground)),
            ],
          ),
        ),
      ),
    );
  }
}
