import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:icex_atlas/core/auth/session_controller.dart';
import 'package:icex_atlas/core/providers.dart';
import 'package:icex_atlas/core/router/app_router.dart';
import 'package:icex_atlas/core/theme/icex_theme.dart';
import 'package:icex_atlas/core/utils/time_ago.dart';
import 'package:icex_atlas/features/feed/application/post_interactions.dart';
import 'package:icex_atlas/features/feed/domain/post.dart';
import 'package:icex_atlas/features/feed/presentation/news_page.dart';
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

  /// [id] se reutiliza en reintentos (idempotente: un reintento no duplica el comentario).
  Future<void> add(String texto, {required String id, Post? post}) async {
    final c = await ref
        .read(feedRepositoryProvider)
        .addComment(id: id, postId: postId, texto: texto);
    if (!ref.mounted) return;
    state = AsyncData([...?state.value?.where((x) => x.id != c.id), c]);
    // Contador +1 sobre la versión actual (antes se ponía el nº de comentarios cargados,
    // que con paginación no es el total).
    if (post != null) ref.read(postOverridesProvider.notifier).commentAdded(post);
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
  final _focus = FocusNode();
  final _scroll = ScrollController();
  bool _sending = false;
  String? _pendingId;

  @override
  void initState() {
    super.initState();
    _text.addListener(_onText);
  }

  void _onText() => setState(() {});

  @override
  void dispose() {
    _text.dispose();
    _focus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final v = _text.text.trim();
    if (v.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      _pendingId ??= ref.read(idGeneratorProvider).next();
      await ref
          .read(commentsControllerProvider(widget.postId).notifier)
          .add(v, id: _pendingId!, post: ref.read(postDetailProvider(widget.postId)).value);
      _pendingId = null;
      _text.clear();
      // Mostrar el comentario recién publicado.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) {
          _scroll.animateTo(
            _scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
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
      appBar: AppBar(title: Text(l.postTitle)),
      body: switch (post) {
        AsyncError(:final error) => ErrorView(
          error: error,
          onRetry: () => ref.invalidate(postDetailProvider(widget.postId)),
        ),
        AsyncData(:final value) => Column(
          children: [
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(commentsControllerProvider(widget.postId));
                  final _ = await ref.refresh(postDetailProvider(widget.postId).future);
                },
                child: ListView(
                  controller: _scroll,
                  padding: const EdgeInsets.only(bottom: 16),
                  children: [
                    if (value.tipo == PostTipo.novedadOficial)
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: NewsCard(post: value),
                      )
                    else
                      ConnectedPostCard(
                        post: value,
                        flat: true,
                        fullText: true,
                        onComment: _focus.requestFocus,
                      ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                      child: Semantics(
                        header: true,
                        child: Text(l.commentsTitle, style: t.titleSmall),
                      ),
                    ),
                    ...switch (comments) {
                      AsyncData(:final value) when value.isEmpty => [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                          child: Column(
                            children: [
                              const Icon(
                                Icons.chat_bubble_outline_rounded,
                                size: 36,
                                color: IcexColors.mutedForeground,
                              ),
                              const SizedBox(height: 8),
                              Text(l.noComments, style: t.bodyMedium, textAlign: TextAlign.center),
                            ],
                          ),
                        ),
                      ],
                      AsyncData(:final value) => [for (final c in value) _CommentTile(c)],
                      AsyncError(:final error) => [
                        ErrorView(
                          error: error,
                          onRetry: () => ref.invalidate(commentsControllerProvider(widget.postId)),
                        ),
                      ],
                      _ => [const Padding(padding: EdgeInsets.all(24), child: LoadingView())],
                    },
                  ],
                ),
              ),
            ),
            _CommentInput(controller: _text, focusNode: _focus, sending: _sending, onSend: _send),
          ],
        ),
        _ => const LoadingView(),
      },
    );
  }
}

/// Campo de comentario estilo Instagram: avatar propio, campo redondeado y «Publicar».
class _CommentInput extends ConsumerWidget {
  const _CommentInput({
    required this.controller,
    required this.focusNode,
    required this.sending,
    required this.onSend,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool sending;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final session = ref.watch(sessionControllerProvider);
    final me = session is SignedIn ? session.me.profile.card : null;
    final canSend = controller.text.trim().isNotEmpty && !sending;
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: IcexColors.card,
        border: Border(top: BorderSide(color: IcexColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (me != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4, right: 8),
                  child: Avatar.of(me, size: 34),
                ),
              Expanded(
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  minLines: 1,
                  maxLines: 5,
                  maxLength: 2000,
                  buildCounter: (_, {required currentLength, required isFocused, maxLength}) =>
                      null,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    hintText: l.commentHint,
                    isDense: true,
                    // 48 dp de alto mínimo (zona táctil recomendada).
                    constraints: const BoxConstraints(minHeight: 48),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    border: const OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(22)),
                      borderSide: BorderSide(color: IcexColors.border),
                    ),
                    enabledBorder: const OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(22)),
                      borderSide: BorderSide(color: IcexColors.border),
                    ),
                    focusedBorder: const OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(22)),
                      borderSide: BorderSide(color: IcexColors.primary),
                    ),
                  ),
                ),
              ),
              TextButton(
                onPressed: canSend ? onSend : null,
                style: TextButton.styleFrom(foregroundColor: IcexColors.primary),
                child: sending
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(l.composerPublish),
              ),
            ],
          ),
        ),
      ),
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            customBorder: const CircleBorder(),
            onTap: () => context.push(Routes.profile(c.autor.slug)),
            child: Avatar.of(c.autor, size: 36, ring: true),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: const BoxDecoration(
                color: IcexColors.muted,
                borderRadius: BorderRadius.only(
                  topRight: Radius.circular(14),
                  bottomLeft: Radius.circular(14),
                  bottomRight: Radius.circular(14),
                  topLeft: Radius.circular(4),
                ),
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
