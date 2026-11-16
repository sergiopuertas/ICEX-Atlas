import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:icex_atlas/core/providers.dart';
import 'package:icex_atlas/core/router/app_router.dart';
import 'package:icex_atlas/core/theme/icex_theme.dart';
import 'package:icex_atlas/core/utils/time_ago.dart';
import 'package:icex_atlas/features/feed/application/feed_controller.dart';
import 'package:icex_atlas/features/feed/domain/post.dart';
import 'package:icex_atlas/features/feed/presentation/post_actions.dart';
import 'package:icex_atlas/l10n/app_localizations.dart';
import 'package:icex_atlas/shared/widgets/avatar.dart';
import 'package:icex_atlas/shared/widgets/common.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'post_detail_page.g.dart';

@riverpod
Future<Post> postDetail(Ref ref, String id) => ref.watch(feedRepositoryProvider).post(id);

@riverpod
class CommentsController extends _$CommentsController {
  @override
  Future<List<Comment>> build(String postId) async =>
      (await ref.watch(feedRepositoryProvider).comments(postId)).items;

  Future<void> add(String texto) async {
    final c = await ref
        .read(feedRepositoryProvider)
        .addComment(id: ref.read(idGeneratorProvider).next(), postId: postId, texto: texto);
    final list = [...state.value ?? const <Comment>[], c];
    state = AsyncData(list);
    ref.read(feedControllerProvider.notifier).updateComments(postId, list.length);
  }
}

/// Publicación con sus comentarios (deep link /post/:id desde notificaciones y push).
class PostDetailPage extends ConsumerStatefulWidget {
  const PostDetailPage({required this.postId, super.key});

  final String postId;

  @override
  ConsumerState<PostDetailPage> createState() => _PostDetailPageState();
}

class _PostDetailPageState extends ConsumerState<PostDetailPage> {
  final _text = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final v = _text.text.trim();
    if (v.isEmpty) return;
    setState(() => _sending = true);
    try {
      await ref.read(commentsControllerProvider(widget.postId).notifier).add(v);
      _text.clear();
    } on Object catch (e) {
      if (mounted) showSnack(context, ErrorView.messageFor(AppLocalizations.of(context), e));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final post = ref.watch(postDetailProvider(widget.postId));
    final comments = ref.watch(commentsControllerProvider(widget.postId));
    return Scaffold(
      appBar: AppBar(title: Text(l.commentsTitle)),
      body: switch (post) {
        AsyncError(:final error) => ErrorView(error: error),
        AsyncData(:final value) => Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (value.tipo == PostTipo.novedadOficial)
                    IcexCard(child: Text(value.texto, style: t.bodyLarge))
                  else
                    ConnectedPostCard(post: value),
                  const SizedBox(height: 16),
                  Semantics(header: true, child: Text(l.commentsTitle, style: t.titleMedium)),
                  const SizedBox(height: 8),
                  ...switch (comments) {
                    AsyncData(:final value) when value.isEmpty => [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(l.noComments, style: t.bodyMedium),
                      ),
                    ],
                    AsyncData(:final value) => [for (final c in value) _CommentTile(c)],
                    AsyncError(:final error) => [ErrorView(error: error)],
                    _ => [const LoadingView()],
                  },
                ],
              ),
            ),
            SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
                decoration: const BoxDecoration(
                  color: IcexColors.card,
                  border: Border(top: BorderSide(color: IcexColors.border)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _text,
                        minLines: 1,
                        maxLines: 4,
                        maxLength: 2000,
                        buildCounter: (
                          _, {
                          required currentLength,
                          required isFocused,
                          maxLength,
                        }) => null,
                        decoration: InputDecoration(hintText: l.commentHint),
                        onSubmitted: (_) => _send(),
                      ),
                    ),
                    IconButton.filled(
                      tooltip: l.comment,
                      onPressed: _sending ? null : _send,
                      icon: const Icon(Icons.send),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        _ => const LoadingView(),
      },
    );
  }
}

class _CommentTile extends StatelessWidget {
  const _CommentTile(this.c);

  final Comment c;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            customBorder: const CircleBorder(),
            onTap: () => context.push(Routes.profile(c.autor.slug)),
            child: Avatar.of(c.autor, size: 36),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: IcexColors.secondary,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(c.autor.nombre, style: t.titleSmall)),
                      Text(timeAgo(AppLocalizations.of(context), c.createdAt), style: t.bodySmall),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(c.texto, style: t.bodyMedium),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
