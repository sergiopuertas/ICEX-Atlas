import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:icex_atlas/core/auth/session_controller.dart';
import 'package:icex_atlas/core/providers.dart';
import 'package:icex_atlas/core/router/app_router.dart';
import 'package:icex_atlas/features/feed/application/feed_controller.dart';
import 'package:icex_atlas/features/feed/domain/post.dart';
import 'package:icex_atlas/features/feed/presentation/post_card.dart';
import 'package:icex_atlas/features/social/data/social_repository.dart';
import 'package:icex_atlas/l10n/app_localizations.dart';
import 'package:icex_atlas/shared/widgets/common.dart';
import 'package:share_plus/share_plus.dart';

/// PostCard conectada al FeedController (acciones comunes en Inicio, perfil y detalle).
class ConnectedPostCard extends ConsumerWidget {
  const ConnectedPostCard({required this.post, super.key});

  final Post post;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionControllerProvider);
    final myId = session is SignedIn ? session.me.userId : null;
    final isOwn = post.autor.userId == myId;
    final l = AppLocalizations.of(context);
    return PostCard(
      post: post,
      isOwn: isOwn,
      onRecommend: () =>
          _guard(context, l, ref.read(feedControllerProvider.notifier).toggleRecommend(post)),
      onComment: () => context.push(Routes.post(post.id)),
      onShare: () => showShareSheet(context, ref, post),
      onMore: () => isOwn
          ? _confirmDelete(context, ref)
          : showReportSheet(context, ref, ReportTarget.post, post.id),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final l = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(l.deletePost),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(l.cancel)),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(l.delete)),
        ],
      ),
    );
    if ((ok ?? false) && context.mounted) {
      await _guard(context, l, ref.read(feedControllerProvider.notifier).delete(post));
    }
  }
}

Future<void> _guard(BuildContext context, AppLocalizations l, Future<void> f) async {
  try {
    await f;
  } on Object catch (e) {
    if (context.mounted) showSnack(context, ErrorView.messageFor(l, e));
  }
}

Future<void> showShareSheet(BuildContext context, WidgetRef ref, Post post) async {
  final l = AppLocalizations.of(context);
  final choice = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (c) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.repeat),
            title: Text(l.shareInNetwork),
            onTap: () => Navigator.pop(c, 'red'),
          ),
          ListTile(
            leading: const Icon(Icons.ios_share),
            title: Text(l.shareExternal),
            onTap: () => Navigator.pop(c, 'fuera'),
          ),
        ],
      ),
    ),
  );
  if (!context.mounted) return;
  if (choice == 'red') {
    final controller = TextEditingController();
    final comment = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(l.shareInNetwork),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 3,
          decoration: InputDecoration(hintText: l.composerHint),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: Text(l.cancel)),
          FilledButton(
            onPressed: () => Navigator.pop(c, controller.text.trim()),
            child: Text(l.composerPublish),
          ),
        ],
      ),
    );
    controller.dispose();
    if (comment == null || !context.mounted) return;
    await _guard(
      context,
      l,
      ref
          .read(feedControllerProvider.notifier)
          .publish(
            texto: comment.isEmpty ? 'Comparto esta publicación' : comment,
            compartidoDe: post.compartido?.id ?? post.id,
          ),
    );
  } else if (choice == 'fuera') {
    final excerpt = post.texto.length > 280 ? '${post.texto.substring(0, 280)}…' : post.texto;
    unawaited(
      SharePlus.instance.share(
        ShareParams(text: '${post.autor.nombre} en ICEX Alumni:\n\n$excerpt'),
      ),
    );
  }
}

Future<void> showReportSheet(
  BuildContext context,
  WidgetRef ref,
  ReportTarget target,
  String id,
) async {
  final l = AppLocalizations.of(context);
  final motivos = {
    ReportMotivo.spam: l.reportSpam,
    ReportMotivo.acoso: l.reportHarassment,
    ReportMotivo.contenidoInapropiado: l.reportInappropriate,
    ReportMotivo.datosPersonales: l.reportPersonalData,
    ReportMotivo.suplantacion: l.reportImpersonation,
    ReportMotivo.otro: l.reportOther,
  };
  final m = await showModalBottomSheet<ReportMotivo>(
    context: context,
    showDragHandle: true,
    builder: (c) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: [
          ListTile(title: Text(l.reportTitle, style: Theme.of(c).textTheme.titleMedium)),
          for (final e in motivos.entries)
            ListTile(title: Text(e.value), onTap: () => Navigator.pop(c, e.key)),
        ],
      ),
    ),
  );
  if (m == null || !context.mounted) return;
  try {
    await ref.read(socialRepositoryProvider).report(target, id, m);
    if (context.mounted) showSnack(context, l.reportThanks);
  } on Object catch (e) {
    if (context.mounted) showSnack(context, ErrorView.messageFor(l, e));
  }
}

/// Lista de publicaciones reutilizable (perfil).
class PostList extends StatelessWidget {
  const PostList({required this.posts, super.key});

  final List<Post> posts;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      for (final p in posts)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: ConnectedPostCard(post: p),
        ),
    ],
  );
}
