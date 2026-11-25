import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:icex_atlas/core/router/app_router.dart';
import 'package:icex_atlas/core/theme/icex_theme.dart';
import 'package:icex_atlas/features/messaging/application/chat_controller.dart';
import 'package:icex_atlas/features/messaging/domain/messaging.dart';
import 'package:icex_atlas/features/messaging/presentation/chat_page.dart';
import 'package:icex_atlas/features/notifications/application/unread_counts.dart';
import 'package:icex_atlas/l10n/app_localizations.dart';
import 'package:icex_atlas/shared/widgets/app_shell.dart';
import 'package:icex_atlas/shared/widgets/avatar.dart';
import 'package:icex_atlas/shared/widgets/brand.dart';
import 'package:icex_atlas/shared/widgets/common.dart';
import 'package:intl/intl.dart';

/// Lista de conversaciones con no leídos y filtro por categoría.
///
/// Lista a todo el ancho (WhatsApp / LinkedIn): avatar, nombre, hora, vista previa y
/// contador; los filtros en una sola fila desplazable en lugar de un bloque de 7 chips.
class ConversationsPage extends ConsumerStatefulWidget {
  const ConversationsPage({super.key});

  @override
  ConsumerState<ConversationsPage> createState() => _ConversationsPageState();
}

class _ConversationsPageState extends ConsumerState<ConversationsPage> {
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    listenScrollToTop(ref, AppTab.messages, _scroll);
    final l = AppLocalizations.of(context);
    final s = ref.watch(conversationsControllerProvider);
    final value = s.value;
    return RefreshIndicator(
      onRefresh: () => ref.refresh(conversationsControllerProvider.future),
      child: CustomScrollView(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: HeroHeader(
              title: l.messagesTitle,
              subtitle: value == null
                  ? null
                  : l.messagesSubtitle(
                      value.items.length,
                      ref.watch(unreadProvider).value?.mensajes ?? 0,
                    ),
            ),
          ),
          SliverToBoxAdapter(
            child: CategoryChips(
              selected: value?.categoria,
              allLabel: l.tabAll,
              onSelected: (c) => ref.read(conversationsControllerProvider.notifier).filter(c),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 8)),
          ...switch (s) {
            AsyncValue(:final value?) when value.items.isEmpty => [
              SliverFillRemaining(
                hasScrollBody: false,
                child: EmptyState(
                  message: value.categoria == null ? l.noConversations : l.noConversationsFilter,
                  icon: Icons.forum_outlined,
                  action: value.categoria == null
                      ? FilledButton.tonal(
                          onPressed: () =>
                              StatefulNavigationShell.maybeOf(context)
                                  ?.goBranch(AppTab.network.index),
                          child: Text(l.exploreNetwork),
                        )
                      : null,
                ),
              ),
            ],
            AsyncValue(:final value?) => [
              SliverList.builder(
                itemCount: value.items.length,
                itemBuilder: (_, i) => ConversationTile(
                  key: ValueKey(value.items[i].id),
                  conversation: value.items[i],
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],
            AsyncValue(:final error?) => [
              SliverFillRemaining(
                hasScrollBody: false,
                child: ErrorView(
                  error: error,
                  onRetry: () => ref.invalidate(conversationsControllerProvider),
                ),
              ),
            ],
            _ => [const SliverFillRemaining(hasScrollBody: false, child: LoadingView())],
          },
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
  Widget build(BuildContext context) => SizedBox(
    height: 44,
    child: ListView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        _chip(allLabel, null, selected == null, () => onSelected(null)),
        for (final c in Categoria.values)
          _chip(c.label, categoriaIcon(c), selected == c, () => onSelected(c)),
      ],
    ),
  );

  Widget _chip(String label, IconData? icon, bool on, VoidCallback tap) => Padding(
    padding: const EdgeInsets.only(right: 8),
    child: ChoiceChip(
      avatar: icon == null
          ? null
          : Icon(icon, size: 16, color: on ? Colors.white : IcexColors.mutedForeground),
      label: Text(label),
      selected: on,
      onSelected: (_) => tap(),
      labelStyle: TextStyle(color: on ? Colors.white : IcexColors.foreground, fontSize: 13),
      visualDensity: VisualDensity.compact,
    ),
  );
}

/// Hora corta para la lista: «14:05», «ayer», «lun», «12 nov».
String conversationTime(AppLocalizations l, DateTime date, {DateTime? now}) {
  final d = date.toLocal();
  final n = now ?? DateTime.now();
  final days = DateTime(n.year, n.month, n.day).difference(DateTime(d.year, d.month, d.day)).inDays;
  if (days == 0) return DateFormat.Hm('es').format(d);
  if (days == 1) return l.timeYesterday;
  if (days < 7) return DateFormat.E('es').format(d).replaceAll('.', '');
  return DateFormat('d MMM', 'es').format(d).replaceAll('.', '');
}

class ConversationTile extends StatelessWidget {
  const ConversationTile({required this.conversation, super.key});

  final Conversation conversation;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final c = conversation;
    final unread = c.noLeidos > 0;
    return Material(
      color: unread ? IcexColors.primary.withValues(alpha: 0.035) : IcexColors.card,
      child: InkWell(
        onTap: () => context.push(Routes.chat(c.id)),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: IcexColors.border)),
          ),
          child: Row(
            children: [
              Avatar.of(c.otro, size: 54, ring: true),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            c.otro.nombre,
                            style: t.titleSmall?.copyWith(
                              fontWeight: unread ? FontWeight.w700 : FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (c.ultimoMensajeEn != null)
                          Text(
                            conversationTime(l, c.ultimoMensajeEn!),
                            style: t.bodySmall?.copyWith(
                              color: unread ? IcexColors.primary : IcexColors.mutedForeground,
                              fontWeight: unread ? FontWeight.w700 : FontWeight.w400,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        if (c.silenciado)
                          const Padding(
                            padding: EdgeInsets.only(right: 4),
                            child: Icon(
                              Icons.notifications_off_outlined,
                              size: 14,
                              color: IcexColors.mutedForeground,
                            ),
                          ),
                        Expanded(
                          child: Text(
                            c.ultimoMensajePreview ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: t.bodyMedium?.copyWith(
                              color: unread ? IcexColors.foreground : IcexColors.mutedForeground,
                              fontWeight: unread ? FontWeight.w600 : FontWeight.w400,
                            ),
                          ),
                        ),
                        if (unread)
                          Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: Badge(
                              label: Text(c.noLeidos > 99 ? '99+' : '${c.noLeidos}'),
                              backgroundColor: IcexColors.primary,
                              largeSize: 20,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    CategoryTag(c.categoria),
                  ],
                ),
              ),
            ],
          ),
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
    padding: const EdgeInsets.fromLTRB(6, 1, 8, 1),
    decoration: BoxDecoration(color: IcexColors.promoTag, borderRadius: BorderRadius.circular(6)),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(categoriaIcon(categoria), size: 12, color: IcexColors.onAccent),
        const SizedBox(width: 4),
        Text(
          categoria.label,
          style: const TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: IcexColors.onAccent,
          ),
        ),
      ],
    ),
  );
}
