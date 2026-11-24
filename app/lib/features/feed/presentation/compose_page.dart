import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:icex_atlas/core/auth/session_controller.dart';
import 'package:icex_atlas/core/providers.dart';
import 'package:icex_atlas/core/theme/icex_theme.dart';
import 'package:icex_atlas/features/feed/application/feed_controller.dart';
import 'package:icex_atlas/features/feed/domain/post.dart';
import 'package:icex_atlas/l10n/app_localizations.dart';
import 'package:icex_atlas/shared/widgets/avatar.dart';
import 'package:icex_atlas/shared/widgets/badges.dart';
import 'package:icex_atlas/shared/widgets/common.dart';
import 'package:image_picker/image_picker.dart';

/// Cómo se abre el compositor (tipo preseleccionado, abrir la galería, publicación citada).
class ComposeArgs {
  const ComposeArgs({this.tipo, this.pickImage = false, this.shared});

  final PostTipo? tipo;
  final bool pickImage;
  final SharedPost? shared;
}

/// Crear publicación a pantalla completa (como LinkedIn o Instagram).
///
/// Sustituye al campo de texto incrustado en el feed: allí el teclado tapaba el contenido,
/// el texto largo quedaba en una caja de pocas líneas y era fácil perder lo escrito al hacer
/// scroll. Aquí hay espacio, una barra de herramientas sobre el teclado y aviso al descartar.
class ComposePage extends ConsumerStatefulWidget {
  // ignore: prefer_const_constructors_in_immutables (recibe `extra` del router, no constante)
  ComposePage({Object? initial, super.key})
    : args = initial is ComposeArgs ? initial : const ComposeArgs();

  final ComposeArgs args;

  @override
  ConsumerState<ComposePage> createState() => _ComposePageState();
}

class _ComposePageState extends ConsumerState<ComposePage> {
  static const _maxLength = 5000;

  final _text = TextEditingController();
  late PostTipo _tipo = widget.args.tipo ?? PostTipo.general;
  Uint8List? _image;
  bool _busy = false;
  String? _pendingId; // reutilizado en reintentos → idempotencia

  @override
  void initState() {
    super.initState();
    _text.addListener(_onText);
    if (widget.args.pickImage) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _pickImage());
    }
  }

  void _onText() => setState(() {});

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  bool get _isShare => widget.args.shared != null;

  bool get _dirty => _text.text.trim().isNotEmpty || _image != null;

  bool get _canPublish => !_busy && (_text.text.trim().isNotEmpty || _isShare);

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
    FocusScope.of(context).unfocus();
    setState(() => _busy = true);
    try {
      _pendingId ??= ref.read(idGeneratorProvider).next();
      final texto = _text.text.trim();
      await ref
          .read(feedControllerProvider.notifier)
          .publish(
            texto: texto.isEmpty && _isShare ? l.shareDefaultText : texto,
            tipo: _tipo,
            image: _image,
            id: _pendingId,
            compartidoDe: widget.args.shared?.id,
          );
      if (mounted) Navigator.of(context).pop(true);
    } on Object catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        showSnack(context, ErrorView.messageFor(l, e));
      }
    }
  }

  Future<bool> _confirmDiscard() async {
    final l = AppLocalizations.of(context);
    final discard = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(l.composeDiscardTitle),
        content: Text(l.composeDiscardBody),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(l.keepEditing)),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(l.discard)),
        ],
      ),
    );
    return discard ?? false;
  }

  Future<void> _pickType() async {
    final t = await showModalBottomSheet<PostTipo>(
      context: context,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final tipo in PostTipo.publicables)
              ListTile(
                leading: Icon(PostTypeBadge.describe(tipo).$1, color: IcexColors.primary),
                title: Text(PostTypeBadge.describe(tipo).$2),
                trailing: tipo == _tipo ? const Icon(Icons.check, color: IcexColors.primary) : null,
                onTap: () => Navigator.pop(c, tipo),
              ),
          ],
        ),
      ),
    );
    if (t != null && mounted) setState(() => _tipo = t);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final session = ref.watch(sessionControllerProvider);
    final me = session is SignedIn ? session.me.profile.card : null;
    final remaining = _maxLength - _text.text.length;

    return PopScope(
      canPop: !_dirty || _busy,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _confirmDiscard() && context.mounted) Navigator.of(context).pop(false);
      },
      child: Scaffold(
        backgroundColor: IcexColors.card,
        appBar: AppBar(
          leading: IconButton(
            tooltip: l.close,
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          title: Text(_isShare ? l.shareInNetwork : l.composeTitle),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: FilledButton(
                key: const Key('composer-publish'),
                onPressed: _canPublish ? _publish : null,
                // Sobre la barra roja: botón blanco con texto rojo.
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 36),
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  backgroundColor: Colors.white,
                  foregroundColor: IcexColors.primary,
                  disabledBackgroundColor: Colors.white.withValues(alpha: 0.35),
                  disabledForegroundColor: Colors.white,
                ),
                child: _busy
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: IcexColors.primary),
                      )
                    : Text(l.composerPublish),
              ),
            ),
          ],
        ),
        body: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                children: [
                  if (me != null)
                    Row(
                      children: [
                        Avatar.of(me, ring: true),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(me.nombre, style: t.titleSmall),
                              const SizedBox(height: 4),
                              if (!_isShare)
                                InkWell(
                                  borderRadius: BorderRadius.circular(999),
                                  onTap: _busy ? null : _pickType,
                                  child: Container(
                                    padding: const EdgeInsets.fromLTRB(10, 4, 6, 4),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(999),
                                      border: Border.all(color: IcexColors.border),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          PostTypeBadge.describe(_tipo).$1,
                                          size: 16,
                                          color: IcexColors.primary,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          PostTypeBadge.describe(_tipo).$2,
                                          style: t.labelLarge?.copyWith(fontSize: 13),
                                        ),
                                        const Icon(Icons.arrow_drop_down, size: 20),
                                      ],
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  TextField(
                    key: const Key('composer-text'),
                    controller: _text,
                    autofocus: !widget.args.pickImage,
                    minLines: 5,
                    maxLines: null,
                    maxLength: _maxLength,
                    buildCounter: (_, {required currentLength, required isFocused, maxLength}) =>
                        null,
                    textCapitalization: TextCapitalization.sentences,
                    keyboardType: TextInputType.multiline,
                    style: t.bodyLarge?.copyWith(fontSize: 17),
                    decoration: InputDecoration(
                      hintText: _isShare ? l.shareInNetworkHint : l.composeHint,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      filled: false,
                      contentPadding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                  if (widget.args.shared case final s?)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: IcexColors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Avatar.of(s.autor, size: 24),
                              const SizedBox(width: 8),
                              Expanded(child: Text(s.autor.nombre, style: t.titleSmall)),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(s.texto, maxLines: 5, overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                  if (_image != null)
                    Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.memory(_image!, width: double.infinity, fit: BoxFit.cover),
                        ),
                        Positioned(
                          right: 8,
                          top: 8,
                          child: IconButton.filled(
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.black54,
                              foregroundColor: Colors.white,
                            ),
                            tooltip: l.removePhoto,
                            onPressed: _busy ? null : () => setState(() => _image = null),
                            icon: const Icon(Icons.close, size: 18),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            // Barra de herramientas pegada al teclado.
            DecoratedBox(
              decoration: const BoxDecoration(
                color: IcexColors.card,
                border: Border(top: BorderSide(color: IcexColors.border)),
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Row(
                    children: [
                      if (!_isShare) ...[
                        IconButton(
                          tooltip: l.composerPhoto,
                          onPressed: _busy ? null : _pickImage,
                          icon: const Icon(Icons.image_outlined, color: IcexColors.primary),
                        ),
                        IconButton(
                          tooltip: l.composerOffer,
                          isSelected: _tipo == PostTipo.oportunidadLaboral,
                          onPressed: _busy
                              ? null
                              : () => setState(() => _tipo = PostTipo.oportunidadLaboral),
                          icon: const Icon(Icons.work_outline),
                        ),
                        IconButton(
                          tooltip: PostTypeBadge.describe(PostTipo.evento).$2,
                          isSelected: _tipo == PostTipo.evento,
                          onPressed: _busy ? null : () => setState(() => _tipo = PostTipo.evento),
                          icon: const Icon(Icons.calendar_month_outlined),
                        ),
                        IconButton(
                          tooltip: PostTypeBadge.describe(PostTipo.logro).$2,
                          isSelected: _tipo == PostTipo.logro,
                          onPressed: _busy ? null : () => setState(() => _tipo = PostTipo.logro),
                          icon: const Icon(Icons.emoji_events_outlined),
                        ),
                      ],
                      const Spacer(),
                      if (remaining < 500)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Text(
                            '$remaining',
                            style: t.bodySmall?.copyWith(
                              color: remaining < 100
                                  ? IcexColors.destructive
                                  : IcexColors.mutedForeground,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
