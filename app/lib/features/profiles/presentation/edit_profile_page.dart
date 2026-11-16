import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:icex_atlas/core/auth/session_controller.dart';
import 'package:icex_atlas/core/providers.dart';
import 'package:icex_atlas/features/profiles/data/profiles_repository.dart';
import 'package:icex_atlas/features/profiles/domain/profile.dart';
import 'package:icex_atlas/l10n/app_localizations.dart';
import 'package:icex_atlas/shared/widgets/avatar.dart';
import 'package:icex_atlas/shared/widgets/common.dart';
import 'package:image_picker/image_picker.dart';

/// Edición del perfil propio (datos, foto y trayectoria).
class EditProfilePage extends ConsumerStatefulWidget {
  const EditProfilePage({super.key});

  @override
  ConsumerState<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends ConsumerState<EditProfilePage> {
  final _form = GlobalKey<FormState>();
  late final Map<String, TextEditingController> _c;
  Fase _fase = Fase.activo;
  bool _saving = false;
  ProfileDetail? _me;

  @override
  void initState() {
    super.initState();
    final s = ref.read(sessionControllerProvider);
    _me = s is SignedIn ? s.me.profile : null;
    final p = _me?.card;
    _c = {
      'nombre': TextEditingController(text: p?.nombre),
      'cargo': TextEditingController(text: p?.cargo),
      'empresa': TextEditingController(text: p?.empresa),
      'pais': TextEditingController(text: p?.pais),
      'ciudad': TextEditingController(text: p?.ciudad),
      'sector': TextEditingController(text: p?.sector),
      'bio': TextEditingController(text: _me?.bio),
    };
    _fase = p?.fase ?? Fase.activo;
  }

  @override
  void dispose() {
    for (final c in _c.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    final l = AppLocalizations.of(context);
    setState(() => _saving = true);
    try {
      await ref
          .read(profilesRepositoryProvider)
          .updateMyProfile(
            ProfileUpdate(
              nombre: _c['nombre']!.text,
              cargo: _c['cargo']!.text,
              empresa: _c['empresa']!.text,
              fase: _fase,
              pais: _c['pais']!.text,
              ciudad: _c['ciudad']!.text,
              sector: _c['sector']!.text,
              bio: _c['bio']!.text,
            ),
          );
      await ref.read(sessionControllerProvider.notifier).refreshMe();
      if (mounted) {
        showSnack(context, l.saved);
        context.pop();
      }
    } on Object catch (e) {
      if (mounted) showSnack(context, ErrorView.messageFor(l, e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _changePhoto() async {
    final l = AppLocalizations.of(context);
    final f = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      imageQuality: 85,
    );
    if (f == null) return;
    try {
      await ref.read(profilesRepositoryProvider).uploadAvatar(await f.readAsBytes());
      await ref.read(sessionControllerProvider.notifier).refreshMe();
      final s = ref.read(sessionControllerProvider);
      if (mounted && s is SignedIn) setState(() => _me = s.me.profile);
    } on Object catch (e) {
      if (mounted) showSnack(context, ErrorView.messageFor(l, e));
    }
  }

  Future<void> _addExperience() async {
    final l = AppLocalizations.of(context);
    final empresa = TextEditingController();
    final cargo = TextEditingController();
    var desde = DateTime(DateTime.now().year);
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(l.addExperience),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: cargo,
              decoration: InputDecoration(labelText: l.fieldRole),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: empresa,
              decoration: InputDecoration(labelText: l.fieldCompany),
            ),
            const SizedBox(height: 8),
            StatefulBuilder(
              builder: (c, set) => OutlinedButton(
                onPressed: () async {
                  final d = await showDatePicker(
                    context: c,
                    initialDate: desde,
                    firstDate: DateTime(1975),
                    lastDate: DateTime.now(),
                  );
                  if (d != null) set(() => desde = d);
                },
                child: Text('${l.fieldFrom}: ${desde.month}/${desde.year}'),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(l.cancel)),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(l.save)),
        ],
      ),
    );
    if ((ok ?? false) && empresa.text.trim().isNotEmpty && cargo.text.trim().isNotEmpty) {
      try {
        final p = await ref
            .read(profilesRepositoryProvider)
            .upsertExperience(
              id: ref.read(idGeneratorProvider).next(),
              empresa: empresa.text.trim(),
              cargo: cargo.text.trim(),
              desde: desde,
            );
        if (mounted) setState(() => _me = p);
      } on Object catch (e) {
        if (mounted) showSnack(context, ErrorView.messageFor(l, e));
      }
    }
    empresa.dispose();
    cargo.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final me = _me;
    if (me == null) return const Scaffold(body: LoadingView());
    String? required(String? v) => (v ?? '').trim().isEmpty ? l.requiredField : null;
    Widget field(String key, String label, {int lines = 1, String? Function(String?)? validator}) =>
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: TextFormField(
            controller: _c[key],
            minLines: lines,
            maxLines: lines == 1 ? 1 : 8,
            validator: validator,
            decoration: InputDecoration(labelText: label),
          ),
        );
    return Scaffold(
      appBar: AppBar(
        title: Text(l.profileEdit),
        actions: [TextButton(onPressed: _saving ? null : _save, child: Text(l.save))],
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Center(
              child: Column(
                children: [
                  Avatar.of(me.card, size: 96, ring: true),
                  TextButton.icon(
                    onPressed: _changePhoto,
                    icon: const Icon(Icons.photo_camera_outlined),
                    label: Text(l.changePhoto),
                  ),
                ],
              ),
            ),
            field('nombre', l.fieldName, validator: required),
            field('cargo', l.fieldRole),
            field('empresa', l.fieldCompany),
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: DropdownButtonFormField<Fase>(
                initialValue: _fase,
                decoration: InputDecoration(labelText: l.fieldPhase),
                items: [
                  for (final f in Fase.values) DropdownMenuItem(value: f, child: Text(f.label)),
                ],
                onChanged: (f) => setState(() => _fase = f ?? _fase),
              ),
            ),
            field('pais', l.fieldCountry),
            field('ciudad', l.fieldCity),
            field('sector', l.fieldSector),
            field('bio', l.fieldBio, lines: 4),
            const SizedBox(height: 8),
            Text(l.profileTrajectory, style: Theme.of(context).textTheme.titleMedium),
            for (final e in me.experiences)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(e.cargo),
                subtitle: Text(e.empresa),
                trailing: IconButton(
                  tooltip: l.delete,
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () async {
                    await ref.read(profilesRepositoryProvider).deleteExperience(e.id);
                    final p = await ref
                        .read(profilesRepositoryProvider)
                        .getProfile(userId: me.card.userId);
                    if (mounted) setState(() => _me = p);
                  },
                ),
              ),
            OutlinedButton.icon(
              onPressed: _addExperience,
              icon: const Icon(Icons.add),
              label: Text(l.addExperience),
            ),
          ],
        ),
      ),
    );
  }
}
