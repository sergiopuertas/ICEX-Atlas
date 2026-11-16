import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:icex_atlas/core/providers.dart';
import 'package:icex_atlas/core/theme/icex_theme.dart';
import 'package:icex_atlas/features/feed/application/feed_controller.dart';
import 'package:icex_atlas/features/feed/domain/post.dart';
import 'package:icex_atlas/features/profiles/domain/profile.dart';
import 'package:icex_atlas/l10n/app_localizations.dart';
import 'package:icex_atlas/shared/widgets/avatar.dart';
import 'package:icex_atlas/shared/widgets/badges.dart';
import 'package:icex_atlas/shared/widgets/common.dart';
import 'package:image_picker/image_picker.dart';

/// Compositor del mockup: "Comparte una novedad…" con «Foto» y «Oferta».
class Composer extends ConsumerStatefulWidget {
  const Composer({required this.me, super.key});

  final ProfileCard me;

  @override
  ConsumerState<Composer> createState() => _ComposerState();
}

class _ComposerState extends ConsumerState<Composer> {
  final _text = TextEditingController();
  PostTipo _tipo = PostTipo.general;
  Uint8List? _image;
  bool _busy = false;
  String? _pendingId; // reutilizado en reintentos → idempotencia

  @override
  void initState() {
    super.initState();
    _text.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    // Reducimos y recomprimimos en el dispositivo; el servidor además valida y quita EXIF.
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 2048,
      imageQuality: 85,
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    if (mounted) setState(() => _image = bytes);
  }

  Future<void> _publish() async {
    final l = AppLocalizations.of(context);
    setState(() => _busy = true);
    try {
      _pendingId ??= ref.read(idGeneratorProvider).next();
      await ref
          .read(feedControllerProvider.notifier)
          .publish(texto: _text.text.trim(), tipo: _tipo, image: _image, id: _pendingId);
      _pendingId = null;
      _text.clear();
      setState(() {
        _image = null;
        _tipo = PostTipo.general;
      });
    } on Object catch (e) {
      if (mounted) showSnack(context, ErrorView.messageFor(l, e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final canPublish = _text.text.trim().isNotEmpty && !_busy;
    return IcexCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Avatar.of(widget.me),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  key: const Key('composer-text'),
                  controller: _text,
                  minLines: 1,
                  maxLines: 8,
                  maxLength: 5000,
                  buildCounter: (_, {required currentLength, required isFocused, maxLength}) =>
                      null,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    hintText: l.composerHint,
                    border: const OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(999)),
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (_tipo != PostTipo.general || _image != null) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (_tipo != PostTipo.general)
                  InputChip(
                    label: PostTypeBadge(_tipo),
                    onDeleted: () => setState(() => _tipo = PostTipo.general),
                  ),
                if (_image != null)
                  Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.memory(_image!, width: 72, height: 72, fit: BoxFit.cover),
                      ),
                      Positioned(
                        right: 0,
                        top: 0,
                        child: IconButton.filledTonal(
                          visualDensity: VisualDensity.compact,
                          tooltip: l.delete,
                          onPressed: () => setState(() => _image = null),
                          icon: const Icon(Icons.close, size: 16),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ],
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    TextButton.icon(
                      onPressed: _busy ? null : _pickImage,
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                      icon: const Icon(Icons.image_outlined, size: 20),
                      label: Text(l.composerPhoto),
                    ),
                    TextButton.icon(
                      onPressed: _busy
                          ? null
                          : () => setState(() => _tipo = PostTipo.oportunidadLaboral),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                      icon: const Icon(Icons.work_outline, size: 20),
                      label: Text(l.composerOffer),
                    ),
                    PopupMenuButton<PostTipo>(
                      tooltip: l.composerType,
                      icon: const Icon(Icons.more_horiz, color: IcexColors.mutedForeground),
                      onSelected: (t) => setState(() => _tipo = t),
                      itemBuilder: (_) => [
                        for (final t in PostTipo.publicables)
                          PopupMenuItem(value: t, child: Text(PostTypeBadge.describe(t).$2)),
                      ],
                    ),
                  ],
                ),
              ),
              FilledButton(
                key: const Key('composer-publish'),
                onPressed: canPublish ? _publish : null,
                style: FilledButton.styleFrom(
                  disabledBackgroundColor: IcexColors.primary.withValues(alpha: 0.35),
                  disabledForegroundColor: Colors.white,
                ),
                child: Text(_busy ? l.composerPublishing : l.composerPublish),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
