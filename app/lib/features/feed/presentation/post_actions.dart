import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:icex_atlas/core/auth/session_controller.dart';
import 'package:icex_atlas/core/providers.dart';
import 'package:icex_atlas/core/router/app_router.dart';
import 'package:icex_atlas/core/theme/icex_theme.dart';
import 'package:icex_atlas/features/feed/application/post_interactions.dart';
import 'package:icex_atlas/features/feed/domain/post.dart';
import 'package:icex_atlas/features/feed/presentation/compose_page.dart';
import 'package:icex_atlas/features/feed/presentation/post_card.dart';
import 'package:icex_atlas/features/social/data/social_repository.dart';
import 'package:icex_atlas/l10n/app_localizations.dart';
import 'package:icex_atlas/shared/widgets/common.dart';
import 'package:share_plus/share_plus.dart';

/// PostCard conectada al estado compartido de publicaciones (Inicio, perfil y detalle ven
/// siempre la misma versión: recomendaciones, comentarios y borrados).
class ConnectedPostCard extends ConsumerWidget {
  const ConnectedPostCard({
    required this.post,
    this.flat = false,
    this.onComment,
    this.fullText = false,
    super.key,
  });

  final Post post;
  final bool flat;
  final bool fullText;

  /// Por defecto abre el detalle con comentarios. En el propio detalle, enfoca el campo.
  final VoidCallback? onComment;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(postOverridesProvider.select((s) => s.resolve(post)));
    if (p == null) return const SizedBox.shrink(); // borrada
    final myId = ref.watch(sessionUserIdProvider);
    final isOwn = p.autor.userId == myId;
    final l = AppLocalizations.of(context);
    return PostCard(
      post: p,
      isOwn: isOwn,
      flat: flat,
      fullText: fullText,
      onRecommend: () =>
          _guard(context, l, ref.read(postOverridesProvider.notifier).toggleRecommend(p)),
      onComment: onComment ?? () => context.push(Routes.post(p.id)),
      onShare: () => showShareSheet(context, ref, p),
      onMore: () => _showOptions(context, ref, p, isOwn: isOwn),
    );
  }

  Future<void> _showOptions(
    BuildContext context,
    WidgetRef ref,
    Post p, {
    required bool isOwn,
  }) async {
    final l = AppLocalizations.of(context);
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      useRootNavigator: true,
      builder: (c) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (p.texto.isNotEmpty)
              ListTile(
                leading: const Icon(Icons.copy_rounded),
                title: Text(l.copyText),
                onTap: () => Navigator.pop(c, 'copy'),
              ),
            ListTile(
              leading: const Icon(Icons.ios_share),
              title: Text(l.shareExternal),
              onTap: () => Navigator.pop(c, 'external'),
            ),
            if (isOwn)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: IcexColors.destructive),
                title: Text(l.deletePost, style: const TextStyle(color: IcexColors.destructive)),
                onTap: () => Navigator.pop(c, 'delete'),
              )
            else ...[
              ListTile(
                leading: const Icon(Icons.person_outline),
                title: Text(l.viewProfileOf(p.autor.nombre)),
                onTap: () => Navigator.pop(c, 'profile'),
              ),
              ListTile(
                leading: const Icon(Icons.flag_outlined),
                title: Text(l.report),
                onTap: () => Navigator.pop(c, 'report'),
              ),
            ],
          ],
        ),
      ),
    );
    if (!context.mounted || choice == null) return;
    switch (choice) {
      case 'copy':
        await Clipboard.setData(ClipboardData(text: p.texto));
        if (context.mounted) showSnack(context, l.copied);
      case 'external':
        _shareExternal(p);
      case 'delete':
        await _confirmDelete(context, ref, p);
      case 'profile':
        unawaited(context.push(Routes.profile(p.autor.slug)));
      case 'report':
        await showReportSheet(context, ref, ReportTarget.post, p.id);
    }
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref, Post p) async {
    final l = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(l.deletePost),
        content: Text(l.deletePostBody),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(l.cancel)),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: IcexColors.destructive),
            onPressed: () => Navigator.pop(c, true),
            child: Text(l.delete),
          ),
        ],
      ),
    );
    if ((ok ?? false) && context.mounted) {
      await _guard(context, l, ref.read(postOverridesProvider.notifier).delete(p));
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

void _shareExternal(Post post) {
  final excerpt = post.texto.length > 280 ? '${post.texto.substring(0, 280)}…' : post.texto;
  unawaited(
    SharePlus.instance.share(ShareParams(text: '${post.autor.nombre} en ICEX Alumni:\n\n$excerpt')),
  );
}

/// Compartir: en la red (abre el compositor con la publicación citada) o fuera de la app.
Future<void> showShareSheet(BuildContext context, WidgetRef ref, Post post) async {
  final l = AppLocalizations.of(context);
  final choice = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    useRootNavigator: true,
    builder: (c) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.repeat_rounded),
            title: Text(l.shareInNetwork),
            subtitle: Text(l.shareInNetworkHint),
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
    // Se comparte siempre el original (no una cadena de compartidos).
    final original = post.compartido;
    final quoted = original ?? SharedPost(id: post.id, texto: post.texto, autor: post.autor);
    final published = await context.push<bool>(Routes.compose, extra: ComposeArgs(shared: quoted));
    if ((published ?? false) && context.mounted) showSnack(context, l.sharedDone);
  } else if (choice == 'fuera') {
    _shareExternal(post);
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
    useRootNavigator: true,
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
          padding: const EdgeInsets.only(bottom: 8),
          child: ConnectedPostCard(key: ValueKey(p.id), post: p, flat: true),
        ),
    ],
  );
}
