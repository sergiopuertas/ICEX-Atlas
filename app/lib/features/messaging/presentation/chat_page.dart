import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:icex_atlas/core/auth/session_controller.dart';
import 'package:icex_atlas/core/router/app_router.dart';
import 'package:icex_atlas/core/theme/icex_theme.dart';
import 'package:icex_atlas/features/messaging/application/chat_controller.dart';
import 'package:icex_atlas/features/messaging/domain/messaging.dart';
import 'package:icex_atlas/l10n/app_localizations.dart';
import 'package:icex_atlas/shared/widgets/avatar.dart';
import 'package:icex_atlas/shared/widgets/badges.dart';
import 'package:icex_atlas/shared/widgets/common.dart';
import 'package:intl/intl.dart';

/// Vista de chat: cabecera con fase/promoción/empresa del contacto y selector de categoría.
class ChatPage extends ConsumerStatefulWidget {
  const ChatPage({this.conversationId, this.toUserId, super.key});

  final String? conversationId;
  final String? toUserId;

  @override
  ConsumerState<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends ConsumerState<ChatPage> {
  final _text = TextEditingController();
  final _scroll = ScrollController();

  ChatControllerProvider get _provider =>
      chatControllerProvider(conversationId: widget.conversationId, toUserId: widget.toUserId);

  @override
  void initState() {
    super.initState();
    _text.addListener(() => setState(() {}));
    _scroll.addListener(() {
      if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 200) {
        ref.read(_provider.notifier).loadOlder().ignore();
      }
    });
  }

  @override
  void dispose() {
    _text.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final v = _text.text;
    _text.clear();
    await ref.read(_provider.notifier).send(v);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final chat = ref.watch(_provider);
    final session = ref.watch(sessionControllerProvider);
    final me = session is SignedIn ? session.me.userId : '';
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(
          onPressed: () => context.canPop() ? context.pop() : context.go(Routes.messages),
        ),
        titleSpacing: 0,
        title: chat.value == null ? null : _ChatHeader(state: chat.value!),
      ),
      body: switch (chat) {
        AsyncError(:final error) => ErrorView(
          error: error,
          onRetry: () => ref.invalidate(_provider),
        ),
        AsyncData(:final value) => Column(
          children: [
            _CategoryBar(
              value: value.categoria,
              onChanged: (c) => ref.read(_provider.notifier).setCategory(c),
            ),
            if (value.offline)
              MaterialBanner(
                content: Text(l.errorNetwork),
                actions: [
                  TextButton(
                    onPressed: () => ref.read(_provider.notifier).catchUp(),
                    child: Text(l.retry),
                  ),
                ],
              ),
            Expanded(
              child: value.messages.isEmpty
                  ? EmptyState(
                      message: l.newConversation(value.other.nombre),
                      icon: Icons.waving_hand_outlined,
                    )
                  : ListView.builder(
                      controller: _scroll,
                      reverse: true,
                      padding: const EdgeInsets.all(12),
                      itemCount: value.messages.length,
                      itemBuilder: (_, i) {
                        final m = value.messages[value.messages.length - 1 - i];
                        return MessageBubble(
                          key: ValueKey(m.id),
                          message: m,
                          mine: m.remitenteId == me,
                          status: value.statusOf(m),
                          onRetry: () => ref.read(_provider.notifier).retry(m.id),
                        );
                      },
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
                        key: const Key('chat-input'),
                        controller: _text,
                        minLines: 1,
                        maxLines: 5,
                        maxLength: 4000,
                        buildCounter: (
                          _, {
                          required currentLength,
                          required isFocused,
                          maxLength,
                        }) => null,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: InputDecoration(hintText: l.messageHint),
                        onSubmitted: (_) => _send(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      key: const Key('chat-send'),
                      tooltip: l.messageSend,
                      onPressed: _text.text.trim().isEmpty ? null : _send,
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

class _ChatHeader extends StatelessWidget {
  const _ChatHeader({required this.state});

  final ChatState state;

  @override
  Widget build(BuildContext context) {
    final o = state.other;
    final t = Theme.of(context).textTheme;
    return InkWell(
      onTap: () => context.push(Routes.profile(o.slug)),
      child: Row(
        children: [
          Avatar.of(o, size: 36, ring: true),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(o.nombre, style: t.titleSmall, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Row(
                  children: [
                    PhaseBadge(o.fase),
                    const SizedBox(width: 4),
                    PromoBadge(o.promocion),
                    if (o.empresa != null) ...[
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          o.empresa!,
                          style: t.bodySmall,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryBar extends StatelessWidget {
  const _CategoryBar({required this.value, required this.onChanged});

  final Categoria value;
  final ValueChanged<Categoria> onChanged;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Container(
      color: IcexColors.card,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Row(
        children: [
          const Icon(Icons.label_outline, size: 18, color: IcexColors.mutedForeground),
          const SizedBox(width: 8),
          Expanded(
            child: DropdownButton<Categoria>(
              value: value,
              isExpanded: true,
              underline: const SizedBox.shrink(),
              hint: Text(l.messageCategory),
              items: [
                for (final c in Categoria.values) DropdownMenuItem(value: c, child: Text(c.label)),
              ],
              onChanged: (c) => c == null ? null : onChanged(c),
            ),
          ),
        ],
      ),
    );
  }
}

class MessageBubble extends StatelessWidget {
  const MessageBubble({
    required this.message,
    required this.mine,
    required this.status,
    required this.onRetry,
    super.key,
  });

  final Message message;
  final bool mine;
  final DeliveryStatus status;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final time = DateFormat.Hm('es').format(message.createdAt.toLocal());
    final fg = mine ? Colors.white : IcexColors.foreground;
    final (icon, statusLabel) = switch (status) {
      DeliveryStatus.enviando => (Icons.schedule, l.messageSending),
      DeliveryStatus.enviado => (Icons.done, l.messageSent),
      DeliveryStatus.leido => (Icons.done_all, l.messageRead),
      DeliveryStatus.error => (Icons.error_outline, l.messageFailed),
    };
    final bubble = Container(
      constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.78),
      margin: const EdgeInsets.symmetric(vertical: 3),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
      decoration: BoxDecoration(
        color: mine ? IcexColors.primary : IcexColors.card,
        border: mine ? null : Border.all(color: IcexColors.border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(message.cuerpo, style: TextStyle(color: fg, fontSize: 15, height: 1.35)),
          const SizedBox(height: 2),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(time, style: TextStyle(color: fg.withValues(alpha: 0.8), fontSize: 11)),
              if (mine) ...[
                const SizedBox(width: 4),
                Icon(icon, size: 14, color: fg.withValues(alpha: 0.9), semanticLabel: statusLabel),
              ],
            ],
          ),
        ],
      ),
    );
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: status == DeliveryStatus.error
          ? Tooltip(
              message: l.messageFailed,
              child: InkWell(
                onTap: onRetry,
                child: Opacity(opacity: 0.7, child: bubble),
              ),
            )
          : bubble,
    );
  }
}
