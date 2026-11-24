import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
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

/// Icono por categoría de conversación.
IconData categoriaIcon(Categoria c) => switch (c) {
  Categoria.solicitudInformacion => Icons.help_outline_rounded,
  Categoria.oportunidadLaboral => Icons.work_outline_rounded,
  Categoria.mentoria => Icons.school_outlined,
  Categoria.networking => Icons.handshake_outlined,
  Categoria.evento => Icons.event_outlined,
  Categoria.colaboracionEmpresarial => Icons.business_outlined,
};

/// Vista de chat: cabecera con fase/promoción/empresa del contacto y categoría.
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
    _scroll.addListener(() {
      if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 300) {
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
    if (v.trim().isEmpty) return;
    _text.clear();
    unawaited(HapticFeedback.selectionClick());
    try {
      await ref.read(_provider.notifier).send(v);
    } on Object catch (e) {
      if (mounted) showSnack(context, ErrorView.messageFor(AppLocalizations.of(context), e));
    }
    if (_scroll.hasClients && _scroll.offset > 0) {
      await _scroll.animateTo(
        0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _pickCategory(Categoria current) async {
    final l = AppLocalizations.of(context);
    final c = await showModalBottomSheet<Categoria>(
      context: context,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Text(l.messageCategory, style: Theme.of(c).textTheme.titleMedium),
            ),
            for (final cat in Categoria.values)
              ListTile(
                leading: Icon(categoriaIcon(cat)),
                title: Text(cat.label),
                trailing: cat == current
                    ? const Icon(Icons.check, color: IcexColors.primary)
                    : null,
                onTap: () => Navigator.pop(c, cat),
              ),
          ],
        ),
      ),
    );
    if (c == null || !mounted) return;
    try {
      await ref.read(_provider.notifier).setCategory(c);
    } on Object catch (e) {
      if (mounted) showSnack(context, ErrorView.messageFor(l, e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final chat = ref.watch(_provider);
    final me = ref.watch(sessionUserIdProvider) ?? '';
    final value = chat.value;
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(
          onPressed: () => context.canPop() ? context.pop() : context.go(Routes.messages),
        ),
        titleSpacing: 0,
        title: value == null ? null : _ChatHeader(state: value),
        bottom: value == null
            ? null
            : PreferredSize(
                preferredSize: const Size.fromHeight(40),
                child: _CategoryStrip(
                  categoria: value.categoria,
                  onTap: () => _pickCategory(value.categoria),
                ),
              ),
      ),
      body: switch (chat) {
        AsyncValue(:final value?) => Column(
          children: [
            if (value.offline)
              Material(
                color: IcexColors.promoTag,
                child: InkWell(
                  onTap: () => ref.read(_provider.notifier).catchUp().ignore(),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        const Icon(Icons.cloud_off_outlined, size: 18),
                        const SizedBox(width: 8),
                        Expanded(child: Text(l.errorNetwork)),
                        Text(l.retry, style: const TextStyle(fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                ),
              ),
            Expanded(
              child: GestureDetector(
                // Solo para cerrar el teclado: no es un control para el lector de pantalla.
                excludeFromSemantics: true,
                onTap: () => FocusScope.of(context).unfocus(),
                child: value.messages.isEmpty
                    ? _EmptyChat(state: value)
                    : _MessageList(
                        state: value,
                        me: me,
                        controller: _scroll,
                        onRetry: (id) => ref.read(_provider.notifier).retry(id).ignore(),
                      ),
              ),
            ),
            _ChatInput(controller: _text, onSend: _send),
          ],
        ),
        AsyncValue(:final error?) => ErrorView(
          error: error,
          onRetry: () => ref.invalidate(_provider),
        ),
        _ => const LoadingView(),
      },
    );
  }
}

/// Lista invertida con separadores de día y agrupación de mensajes consecutivos del
/// mismo remitente (menos espacio y una sola «cola» por grupo, como en WhatsApp).
class _MessageList extends StatelessWidget {
  const _MessageList({
    required this.state,
    required this.me,
    required this.controller,
    required this.onRetry,
  });

  final ChatState state;
  final String me;
  final ScrollController controller;
  final ValueChanged<String> onRetry;

  static bool _sameDay(DateTime a, DateTime b) {
    final x = a.toLocal();
    final y = b.toLocal();
    return x.year == y.year && x.month == y.month && x.day == y.day;
  }

  static bool _grouped(Message a, Message b) =>
      a.remitenteId == b.remitenteId &&
      _sameDay(a.createdAt, b.createdAt) &&
      b.createdAt.difference(a.createdAt).abs() < const Duration(minutes: 5);

  @override
  Widget build(BuildContext context) {
    final msgs = state.messages;
    return ListView.builder(
      controller: controller,
      reverse: true,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      itemCount: msgs.length,
      itemBuilder: (_, i) {
        // i = 0 es el último mensaje (lista invertida).
        final idx = msgs.length - 1 - i;
        final m = msgs[idx];
        final prev = idx > 0 ? msgs[idx - 1] : null;
        final next = idx < msgs.length - 1 ? msgs[idx + 1] : null;
        final newDay = prev == null || !_sameDay(prev.createdAt, m.createdAt);
        final firstOfGroup = prev == null || newDay || !_grouped(prev, m);
        final lastOfGroup = next == null || !_grouped(m, next);
        return Column(
          key: ValueKey(m.id),
          children: [
            if (newDay) _DaySeparator(m.createdAt),
            Padding(
              padding: EdgeInsets.only(top: firstOfGroup ? 8 : 2),
              child: MessageBubble(
                message: m,
                mine: m.remitenteId == me,
                status: state.statusOf(m),
                tail: lastOfGroup,
                onRetry: () => onRetry(m.id),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _DaySeparator extends StatelessWidget {
  const _DaySeparator(this.date);

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final d = date.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(d.year, d.month, d.day);
    final diff = today.difference(day).inDays;
    final label = switch (diff) {
      0 => l.today,
      1 => l.yesterday,
      < 7 => toBeginningOfSentenceCase(DateFormat.EEEE('es').format(d)),
      _ => DateFormat(d.year == now.year ? 'd MMM' : 'd MMM y', 'es').format(d),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: IcexColors.muted,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }
}

/// Categoría de la conversación, visible y modificable bajo la cabecera.
class _CategoryStrip extends StatelessWidget {
  const _CategoryStrip({required this.categoria, required this.onTap});

  final Categoria categoria;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    return Semantics(
      button: true,
      label: '${l.messageCategory}: ${categoria.label}',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: const BoxDecoration(
            color: IcexColors.card,
            border: Border(bottom: BorderSide(color: IcexColors.border)),
          ),
          child: Row(
            children: [
              Icon(categoriaIcon(categoria), size: 16, color: IcexColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  categoria.label,
                  style: t.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(l.change, style: t.bodySmall?.copyWith(color: IcexColors.primary)),
              const Icon(Icons.expand_more, size: 18, color: IcexColors.primary),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyChat extends StatelessWidget {
  const _EmptyChat({required this.state});

  final ChatState state;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final o = state.other;
    return ListView(
      padding: const EdgeInsets.all(32),
      children: [
        const SizedBox(height: 24),
        Center(child: Avatar.of(o, size: 88, ring: true)),
        const SizedBox(height: 12),
        Text(o.nombre, style: t.titleLarge, textAlign: TextAlign.center),
        if (o.headline.isNotEmpty)
          Text(o.headline, style: t.bodyMedium, textAlign: TextAlign.center),
        const SizedBox(height: 8),
        Center(
          child: PhasePromoRow(fase: o.fase, promocion: o.promocion),
        ),
        const SizedBox(height: 20),
        Text(
          l.newConversation(o.nombre),
          style: t.bodyMedium?.copyWith(color: IcexColors.mutedForeground),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

/// Campo de mensaje: píldora + botón circular. Solo se reconstruye el botón al escribir
/// (antes cada tecla reconstruía toda la página, lista de mensajes incluida).
class _ChatInput extends StatelessWidget {
  const _ChatInput({required this.controller, required this.onSend});

  final TextEditingController controller;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    const radius = BorderRadius.all(Radius.circular(24));
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: IcexColors.card,
        border: Border(top: BorderSide(color: IcexColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  key: const Key('chat-input'),
                  controller: controller,
                  minLines: 1,
                  maxLines: 5,
                  maxLength: 4000,
                  buildCounter: (_, {required currentLength, required isFocused, maxLength}) =>
                      null,
                  textCapitalization: TextCapitalization.sentences,
                  keyboardType: TextInputType.multiline,
                  decoration: InputDecoration(
                    hintText: l.messageHint,
                    isDense: true,
                    fillColor: IcexColors.muted,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    border: const OutlineInputBorder(
                      borderRadius: radius,
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: const OutlineInputBorder(
                      borderRadius: radius,
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: const OutlineInputBorder(
                      borderRadius: radius,
                      borderSide: BorderSide(color: IcexColors.primary),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: controller,
                builder: (_, v, _) => IconButton.filled(
                  key: const Key('chat-send'),
                  tooltip: l.messageSend,
                  onPressed: v.text.trim().isEmpty ? null : onSend,
                  icon: const Icon(Icons.send_rounded),
                ),
              ),
            ],
          ),
        ),
      ),
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
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Avatar.of(o, size: 38, ring: true),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    o.nombre,
                    style: t.titleSmall?.copyWith(color: Colors.white),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      PhaseBadge(o.fase, compact: true, onDark: true),
                      const SizedBox(width: 4),
                      PromoBadge(o.promocion, compact: true),
                      if (o.empresa != null) ...[
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            o.empresa!,
                            style: t.bodySmall?.copyWith(
                              color: Colors.white.withValues(alpha: 0.85),
                            ),
                            maxLines: 1,
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
    this.tail = true,
    super.key,
  });

  final Message message;
  final bool mine;
  final DeliveryStatus status;
  final VoidCallback onRetry;

  /// Último mensaje de un grupo: lleva la esquina «de cola».
  final bool tail;

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
    const r = Radius.circular(18);
    const small = Radius.circular(4);
    final bubble = Container(
      constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.78),
      padding: const EdgeInsets.fromLTRB(12, 8, 10, 6),
      decoration: BoxDecoration(
        color: mine ? IcexColors.primary : IcexColors.card,
        border: mine ? null : Border.all(color: IcexColors.border),
        borderRadius: BorderRadius.only(
          topLeft: r,
          topRight: r,
          bottomLeft: !mine && tail ? small : r,
          bottomRight: mine && tail ? small : r,
        ),
      ),
      child: Wrap(
        alignment: WrapAlignment.end,
        crossAxisAlignment: WrapCrossAlignment.end,
        spacing: 8,
        children: [
          Text(message.cuerpo, style: TextStyle(color: fg, fontSize: 15, height: 1.35)),
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(time, style: TextStyle(color: fg.withValues(alpha: 0.75), fontSize: 11)),
                if (mine) ...[
                  const SizedBox(width: 3),
                  Icon(
                    icon,
                    size: 14,
                    color: status == DeliveryStatus.leido
                        ? IcexColors.accent
                        : fg.withValues(alpha: 0.85),
                    semanticLabel: statusLabel,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
    final failed = status == DeliveryStatus.error;
    Future<void> copy() async {
      await Clipboard.setData(ClipboardData(text: message.cuerpo));
      if (context.mounted) showSnack(context, l.copied);
    }

    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      // Copiar (pulsación larga) llega al lector de pantalla como acción «Copiar» del
      // mensaje; el gesto en sí no se anuncia como un botón diminuto.
      child: Semantics(
        customSemanticsActions: {CustomSemanticsAction(label: l.copyText): copy},
        onTap: failed ? onRetry : null,
        child: GestureDetector(
          excludeFromSemantics: true,
          onTap: failed ? onRetry : null,
          onLongPress: copy,
          child: Column(
            crossAxisAlignment: mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              Opacity(opacity: failed ? 0.7 : 1, child: bubble),
              if (failed)
                Padding(
                  padding: const EdgeInsets.only(top: 2, right: 4),
                  child: Text(
                    l.messageFailedTapRetry,
                    style: const TextStyle(color: IcexColors.destructive, fontSize: 12),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
