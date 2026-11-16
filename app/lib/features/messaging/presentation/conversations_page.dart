import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:icex_atlas/core/router/app_router.dart';
import 'package:icex_atlas/core/theme/icex_theme.dart';
import 'package:icex_atlas/features/messaging/application/chat_controller.dart';
import 'package:icex_atlas/features/messaging/domain/messaging.dart';
import 'package:icex_atlas/l10n/app_localizations.dart';
import 'package:icex_atlas/shared/widgets/avatar.dart';
import 'package:icex_atlas/shared/widgets/common.dart';

/// Lista de conversaciones con no leídos y filtro por categoría (mockup).
class ConversationsPage extends ConsumerWidget {
  const ConversationsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final s = ref.watch(conversationsControllerProvider);
    final value = s.value;
    return RefreshIndicator(
      onRefresh: () => ref.refresh(conversationsControllerProvider.future),
      child: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          PageHeader(
            title: l.messagesTitle,
            subtitle: value == null
                ? null
                : l.messagesSubtitle(value.items.length, value.totalUnread),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: IcexCard(
              padding: EdgeInsets.zero,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Semantics(
                          header: true,
                          child: Text(
                            l.conversationsTitle,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                        const SizedBox(height: 8),
                        CategoryChips(
                          selected: value?.categoria,
                          allLabel: l.tabAll,
                          onSelected: (c) =>
                              ref.read(conversationsControllerProvider.notifier).filter(c),
                        ),
                      ],
                    ),
                  ),
                  const Divider(),
                  ...switch (s) {
                    AsyncData(:final value) when value.items.isEmpty => [
                      EmptyState(message: l.noConversations, icon: Icons.forum_outlined),
                    ],
                    AsyncData(:final value) => [
                      for (final c in value.items) ConversationTile(conversation: c),
                    ],
                    AsyncError(:final error) => [
                      ErrorView(
                        error: error,
                        onRetry: () => ref.invalidate(conversationsControllerProvider),
                      ),
                    ],
                    _ => [const Padding(padding: EdgeInsets.all(24), child: LoadingView())],
                  },
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class CategoryChips extends StatelessWidget {
  const CategoryChips({
    required this.selected,
    required this.onSelected,
    required this.allLabel,
    super.key,
  });

  final Categoria? selected;
  final ValueChanged<Categoria?> onSelected;
  final String allLabel;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 6,
    runSpacing: 6,
    children: [
      _chip(allLabel, selected == null, () => onSelected(null)),
      for (final c in Categoria.values) _chip(c.label, selected == c, () => onSelected(c)),
    ],
  );

  Widget _chip(String label, bool on, VoidCallback tap) => ChoiceChip(
    label: Text(label),
    selected: on,
    onSelected: (_) => tap(),
    labelStyle: TextStyle(color: on ? Colors.white : IcexColors.foreground, fontSize: 13),
    visualDensity: VisualDensity.compact,
  );
}

class ConversationTile extends StatelessWidget {
  const ConversationTile({required this.conversation, super.key});

  final Conversation conversation;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final c = conversation;
    final unread = c.noLeidos > 0;
    return InkWell(
      onTap: () => context.push(Routes.chat(c.id)),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: unread ? IcexColors.secondary : null,
          border: const Border(bottom: BorderSide(color: IcexColors.border)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Avatar.of(c.otro),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(c.otro.nombre, style: t.titleSmall)),
                      if (unread)
                        Badge(
                          label: Text('${c.noLeidos}'),
                          backgroundColor: IcexColors.primary,
                          largeSize: 20,
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  CategoryTag(c.categoria),
                  const SizedBox(height: 4),
                  Text(
                    c.ultimoMensajePreview ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.bodyMedium?.copyWith(
                      color: unread ? IcexColors.foreground : IcexColors.mutedForeground,
                      fontWeight: unread ? FontWeight.w600 : FontWeight.w400,
                    ),
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

class CategoryTag extends StatelessWidget {
  const CategoryTag(this.categoria, {super.key});

  final Categoria categoria;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
    decoration: BoxDecoration(color: IcexColors.promoTag, borderRadius: BorderRadius.circular(6)),
    child: Text(
      categoria.label,
      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: IcexColors.onAccent),
    ),
  );
}
