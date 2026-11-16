import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:icex_atlas/core/theme/icex_theme.dart';
import 'package:icex_atlas/core/utils/time_ago.dart';
import 'package:icex_atlas/features/feed/application/feed_controller.dart';
import 'package:icex_atlas/features/feed/domain/post.dart';
import 'package:icex_atlas/l10n/app_localizations.dart';
import 'package:icex_atlas/shared/widgets/common.dart';

/// Comunicados oficiales de la asociación (fijados primero).
class NewsPage extends ConsumerWidget {
  const NewsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final news = ref.watch(newsControllerProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l.navNews)),
      body: switch (news) {
        AsyncData(:final value) => NotificationListener<ScrollNotification>(
          onNotification: (n) {
            if (n.metrics.extentAfter < 400) {
              ref.read(newsControllerProvider.notifier).loadMore().ignore();
            }
            return false;
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            children: [
              PageHeader(
                title: l.newsTitle,
                subtitle: l.newsCount(value.destacadas.length + value.posts.length),
                leading: const CircleAvatar(
                  backgroundColor: IcexColors.primary,
                  foregroundColor: Colors.white,
                  child: Icon(Icons.campaign_outlined),
                ),
              ),
              for (final p in [...value.destacadas, ...value.posts])
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: NewsCard(post: p),
                ),
            ],
          ),
        ),
        AsyncError(:final error) => ErrorView(
          error: error,
          onRetry: () => ref.invalidate(newsControllerProvider),
        ),
        _ => const LoadingView(),
      },
    );
  }
}

class NewsCard extends StatelessWidget {
  const NewsCard({required this.post, super.key});

  final Post post;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    return IcexCard(
      accentLeft: post.fijado,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (post.fijado)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.push_pin_outlined, size: 14, color: IcexColors.primary),
                    Text(
                      l.pinned,
                      style: const TextStyle(
                        color: IcexColors.primary,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              if (post.etiqueta != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
                  decoration: BoxDecoration(
                    color: IcexColors.promoTag,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    post.etiqueta!,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
              Text(shortDate(post.createdAt), style: t.bodySmall),
            ],
          ),
          const SizedBox(height: 10),
          Semantics(header: true, child: Text(post.titulo ?? '', style: t.titleLarge)),
          const SizedBox(height: 6),
          Text(post.texto, style: t.bodyLarge?.copyWith(color: IcexColors.mutedForeground)),
        ],
      ),
    );
  }
}
