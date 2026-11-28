import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:icex_atlas/core/auth/session_controller.dart';
import 'package:icex_atlas/core/providers.dart';
import 'package:icex_atlas/core/router/app_router.dart';
import 'package:icex_atlas/core/theme/icex_theme.dart';
import 'package:icex_atlas/features/notifications/domain/app_notification.dart';
import 'package:icex_atlas/features/profiles/domain/profile.dart';
import 'package:icex_atlas/features/settings/data/account_repository.dart';
import 'package:icex_atlas/l10n/app_localizations.dart';
import 'package:icex_atlas/shared/widgets/avatar.dart';
import 'package:icex_atlas/shared/widgets/common.dart';
import 'package:icex_atlas/shared/widgets/dialogs.dart';
import 'package:icex_atlas/shared/widgets/links.dart';
import 'package:share_plus/share_plus.dart';

/// Ajustes: notificaciones, privacidad, bloqueados, exportar datos, borrar cuenta, cerrar sesión.
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final env = ref.watch(appEnvProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l.settingsTitle)),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.notifications_outlined),
            title: Text(l.settingsNotifications),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('${Routes.settings}/notificaciones'),
          ),
          ListTile(
            leading: const Icon(Icons.lock_outline),
            title: Text(l.settingsPrivacy),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('${Routes.settings}/privacidad'),
          ),
          ListTile(
            leading: const Icon(Icons.block),
            title: Text(l.settingsBlocked),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('${Routes.settings}/bloqueados'),
          ),
          if (env.feedbackUrl.isNotEmpty)
            ListTile(
              key: const Key('feedback'),
              leading: const Icon(Icons.rate_review_outlined),
              title: Text(l.settingsFeedback),
              trailing: const Icon(Icons.open_in_new, size: 18),
              onTap: () => openExternalUrl(context, env.feedbackUrl),
            ),
          if (env.privacyUrl.isNotEmpty)
            ListTile(
              leading: const Icon(Icons.policy_outlined),
              title: Text(l.settingsPrivacyPolicy),
              trailing: const Icon(Icons.open_in_new, size: 18),
              onTap: () => openExternalUrl(context, env.privacyUrl),
            ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.download_outlined),
            title: Text(l.settingsExport),
            onTap: () => _export(context, ref),
          ),
          ListTile(
            leading: const Icon(Icons.delete_forever_outlined, color: IcexColors.destructive),
            title: Text(l.settingsDelete, style: const TextStyle(color: IcexColors.destructive)),
            onTap: () => _delete(context, ref),
          ),
          const Divider(),
          ListTile(
            key: const Key('sign-out'),
            leading: const Icon(Icons.logout),
            title: Text(l.settingsSignOut),
            onTap: () => ref.read(sessionControllerProvider.notifier).signOut(),
          ),
        ],
      ),
    );
  }

  Future<void> _export(BuildContext context, WidgetRef ref) async {
    final l = AppLocalizations.of(context);
    try {
      final json = await ref.read(accountRepositoryProvider).exportData();
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile.fromData(utf8.encode(json), mimeType: 'application/json')],
          fileNameOverrides: const ['icex-atlas-mis-datos.json'],
          text: l.settingsExportDone,
        ),
      );
    } on Object catch (e) {
      if (context.mounted) showSnack(context, ErrorView.messageFor(l, e));
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final l = AppLocalizations.of(context);
    final confirmation = await showDeleteAccountDialog(
      context,
      confirmWord: AccountRepository.deleteConfirmation,
    );
    if (confirmation == null) return;
    try {
      await ref.read(accountRepositoryProvider).deleteAccount(confirmation);
      await ref.read(sessionControllerProvider.notifier).signOut();
    } on Object catch (e) {
      if (context.mounted) showSnack(context, ErrorView.messageFor(l, e));
    }
  }
}

final FutureProvider<NotificationPreferences> _prefsProvider =
    FutureProvider.autoDispose<NotificationPreferences>(
      (ref) => ref.watch(notificationsRepositoryProvider).preferences(),
    );

class NotificationPrefsPage extends ConsumerStatefulWidget {
  const NotificationPrefsPage({super.key});

  @override
  ConsumerState<NotificationPrefsPage> createState() => _NotificationPrefsPageState();
}

class _NotificationPrefsPageState extends ConsumerState<NotificationPrefsPage> {
  NotificationPreferences? _p;

  Future<void> _save(NotificationPreferences p) async {
    setState(() => _p = p);
    try {
      final saved = await ref.read(notificationsRepositoryProvider).updatePreferences(p);
      if (mounted) setState(() => _p = saved);
    } on Object catch (e) {
      if (mounted) showSnack(context, ErrorView.messageFor(AppLocalizations.of(context), e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final loaded = ref.watch(_prefsProvider);
    final p = _p ?? loaded.value;
    NotificationPreferences copy({
      bool? pm,
      bool? ps,
      bool? pe,
      bool? pn,
      bool? en,
      bool? ed,
      bool? consent,
    }) => NotificationPreferences(
      pushMensajes: pm ?? p!.pushMensajes,
      pushSocial: ps ?? p!.pushSocial,
      pushEventos: pe ?? p!.pushEventos,
      pushNovedades: pn ?? p!.pushNovedades,
      emailNovedades: en ?? p!.emailNovedades,
      emailResumenSemanal: ed ?? p!.emailResumenSemanal,
      consentimientoComunicaciones: consent ?? p!.consentimientoComunicaciones,
    );
    return Scaffold(
      appBar: AppBar(title: Text(l.settingsNotifications)),
      body: p == null
          ? (loaded.hasError ? ErrorView(error: loaded.error!) : const LoadingView())
          : ListView(
              children: [
                ListTile(
                  title: Text(l.prefPushSection, style: Theme.of(context).textTheme.titleSmall),
                ),
                SwitchListTile(
                  title: Text(l.prefPushMessages),
                  value: p.pushMensajes,
                  onChanged: (v) => _save(copy(pm: v)),
                ),
                SwitchListTile(
                  title: Text(l.prefPushSocial),
                  value: p.pushSocial,
                  onChanged: (v) => _save(copy(ps: v)),
                ),
                SwitchListTile(
                  title: Text(l.prefPushEvents),
                  value: p.pushEventos,
                  onChanged: (v) => _save(copy(pe: v)),
                ),
                SwitchListTile(
                  title: Text(l.prefPushNews),
                  value: p.pushNovedades,
                  onChanged: (v) => _save(copy(pn: v)),
                ),
                const Divider(),
                ListTile(
                  title: Text(l.prefEmailSection, style: Theme.of(context).textTheme.titleSmall),
                ),
                CheckboxListTile(
                  title: Text(l.prefEmailConsent),
                  value: p.consentimientoComunicaciones,
                  onChanged: (v) => _save(copy(consent: v ?? false)),
                ),
                SwitchListTile(
                  title: Text(l.prefEmailNews),
                  value: p.emailNovedades,
                  onChanged: p.consentimientoComunicaciones ? (v) => _save(copy(en: v)) : null,
                ),
                SwitchListTile(
                  title: Text(l.prefEmailDigest),
                  value: p.emailResumenSemanal,
                  onChanged: p.consentimientoComunicaciones ? (v) => _save(copy(ed: v)) : null,
                ),
              ],
            ),
    );
  }
}

class PrivacyPage extends ConsumerStatefulWidget {
  const PrivacyPage({super.key});

  @override
  ConsumerState<PrivacyPage> createState() => _PrivacyPageState();
}

class _PrivacyPageState extends ConsumerState<PrivacyPage> {
  ProfileDetail? _me;

  /// Fuerza a recrear los desplegables tras cada guardado: `initialValue` solo se lee al
  /// crearlos, así reflejan el valor del servidor (también si el guardado falla).
  int _rev = 0;

  @override
  void initState() {
    super.initState();
    final s = ref.read(sessionControllerProvider);
    _me = s is SignedIn ? s.me.profile : null;
  }

  Future<void> _set({Map<String, Visibilidad>? vis, bool? sugerencias}) async {
    try {
      final p = await ref
          .read(profilesRepositoryProvider)
          .setPrivacy(visibilidad: vis, aceptaSugerencias: sugerencias);
      if (mounted) setState(() => _me = p);
      await ref.read(sessionControllerProvider.notifier).refreshMe();
    } on Object catch (e) {
      if (mounted) showSnack(context, ErrorView.messageFor(AppLocalizations.of(context), e));
    } finally {
      if (mounted) setState(() => _rev++);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final me = _me;
    if (me == null) return const Scaffold(body: LoadingView());
    final fields = {
      'cargo': l.fieldRole,
      'empresa': l.fieldCompany,
      'ciudad': l.fieldCity,
      'ubicacion': l.privacyLocation,
      'bio': l.fieldBio,
      'trayectoria': l.profileTrajectory,
    };
    final labels = {
      Visibilidad.socios: l.privacyEveryone,
      Visibilidad.seguidores: l.privacyFollowers,
      Visibilidad.soloYo: l.privacyOnlyMe,
    };
    return Scaffold(
      appBar: AppBar(title: Text(l.settingsPrivacy)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(l.privacyIntro, style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: 12),
          for (final e in fields.entries)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: DropdownButtonFormField<Visibilidad>(
                key: ValueKey('${e.key}-$_rev'),
                initialValue: me.visibilidad[e.key] ?? Visibilidad.socios,
                decoration: InputDecoration(labelText: e.value),
                items: [
                  for (final v in Visibilidad.values)
                    DropdownMenuItem(value: v, child: Text(labels[v]!)),
                ],
                onChanged: (v) => v == null ? null : _set(vis: {e.key: v}),
              ),
            ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l.privacySuggestions),
            value: me.aceptaSugerencias ?? true,
            onChanged: (v) => _set(sugerencias: v),
          ),
        ],
      ),
    );
  }
}

final FutureProvider<List<ProfileCard>> _blockedProvider =
    FutureProvider.autoDispose<List<ProfileCard>>(
      (ref) => ref.watch(socialRepositoryProvider).blocked(),
    );

class BlockedPage extends ConsumerWidget {
  const BlockedPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final list = ref.watch(_blockedProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l.settingsBlocked)),
      body: list.when(
        data: (people) => people.isEmpty
            ? EmptyState(message: l.noResults, icon: Icons.block)
            : ListView(
                children: [
                  for (final p in people)
                    ListTile(
                      leading: Avatar.of(p),
                      title: Text(p.nombre),
                      trailing: TextButton(
                        onPressed: () async {
                          try {
                            await ref.read(socialRepositoryProvider).unblock(p.userId);
                            ref.invalidate(_blockedProvider);
                          } on Object catch (e) {
                            if (context.mounted) showSnack(context, ErrorView.messageFor(l, e));
                          }
                        },
                        child: Text(l.profileUnblock),
                      ),
                    ),
                ],
              ),
        error: (e, _) => ErrorView(error: e),
        loading: LoadingView.new,
      ),
    );
  }
}
