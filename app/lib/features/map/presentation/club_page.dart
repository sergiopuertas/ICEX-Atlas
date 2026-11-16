import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:icex_atlas/core/theme/icex_theme.dart';
import 'package:icex_atlas/core/utils/time_ago.dart';
import 'package:icex_atlas/features/map/application/map_controller.dart';
import 'package:icex_atlas/features/map/domain/map_models.dart';
import 'package:icex_atlas/l10n/app_localizations.dart';
import 'package:icex_atlas/shared/widgets/common.dart';

/// Club local: descripción, unirse/salir y próximos eventos con inscripción (aforo y lista de espera).
class ClubPage extends ConsumerWidget {
  const ClubPage({required this.clubId, super.key});

  final String clubId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final club = ref.watch(clubControllerProvider(clubId));
    final c = ref.read(clubControllerProvider(clubId).notifier);
    Future<void> guard(Future<void> f) async {
      try {
        await f;
      } on Object catch (e) {
        if (context.mounted) showSnack(context, ErrorView.messageFor(l, e));
      }
    }

    return Scaffold(
      appBar: AppBar(title: Text(club.value?.nombre ?? '')),
      body: switch (club) {
        AsyncData(:final value) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            IcexCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Semantics(header: true, child: Text(value.nombre, style: t.headlineSmall)),
                  Text(
                    '${value.ciudad}, ${value.pais} · ${l.clubMembers(value.miembrosCount)}',
                    style: t.bodySmall,
                  ),
                  if (value.descripcion != null) ...[
                    const SizedBox(height: 8),
                    Text(value.descripcion!, style: t.bodyLarge),
                  ],
                  const SizedBox(height: 12),
                  if (value.isMember)
                    OutlinedButton(
                      onPressed: () => guard(c.toggleMembership()),
                      child: Text(l.clubLeave),
                    )
                  else
                    FilledButton(
                      onPressed: () => guard(c.toggleMembership()),
                      child: Text(l.clubJoin),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Semantics(header: true, child: Text(l.clubUpcoming, style: t.titleMedium)),
            const SizedBox(height: 8),
            if (value.proximosEventos.isEmpty) Text(l.clubNoEvents, style: t.bodyMedium),
            for (final e in value.proximosEventos)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: EventCard(event: e, onToggle: () => guard(c.toggleRegistration(e))),
              ),
          ],
        ),
        AsyncError(:final error) => ErrorView(error: error),
        _ => const LoadingView(),
      },
    );
  }
}

class EventCard extends StatelessWidget {
  const EventCard({required this.event, required this.onToggle, super.key});

  final ClubEvent event;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final e = event;
    return IcexCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.calendar_month_outlined, size: 16, color: IcexColors.primary),
              const SizedBox(width: 6),
              Text(
                eventDate(e.inicio),
                style: const TextStyle(color: IcexColors.primary, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(e.titulo, style: t.titleMedium),
          if (e.lugar != null)
            Text(e.lugar == 'Online' ? l.eventOnline : e.lugar!, style: t.bodySmall),
          if (e.aforo != null) Text(l.eventSeats(e.inscritosCount, e.aforo!), style: t.bodySmall),
          const SizedBox(height: 10),
          switch (e.inscripcion) {
            Inscripcion.ninguna => FilledButton(onPressed: onToggle, child: Text(l.eventRegister)),
            Inscripcion.inscrito => Wrap(
              spacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Chip(avatar: const Icon(Icons.check, size: 16), label: Text(l.eventRegistered)),
                TextButton(onPressed: onToggle, child: Text(l.eventCancel)),
              ],
            ),
            Inscripcion.listaEspera => Wrap(
              spacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Chip(
                  avatar: const Icon(Icons.hourglass_top, size: 16),
                  label: Text(l.eventWaitlist),
                ),
                TextButton(onPressed: onToggle, child: Text(l.eventCancel)),
              ],
            ),
          },
        ],
      ),
    );
  }
}
