import 'package:flutter/material.dart';
import 'package:icex_atlas/core/theme/icex_theme.dart';
import 'package:icex_atlas/l10n/app_localizations.dart';

/// Diálogos con campos de texto.
///
/// Cada diálogo es un `StatefulWidget` que crea y libera su propio
/// [TextEditingController] en `initState`/`dispose`. Así el controlador vive exactamente lo
/// mismo que el `TextField`, incluida la animación de salida del diálogo.
///
/// El patrón anterior (`final c = TextEditingController(); await showDialog(...); c.dispose();`)
/// libera el controlador en cuanto se resuelve el `Future`, pero el diálogo sigue montado unos
/// 150 ms mientras se anima su cierre (y el teclado se oculta). En ese intervalo el `TextField`
/// usa un controlador liberado → «A TextEditingController was used after being disposed»,
/// seguido de las aserciones `_dependents.isEmpty` y `attached`.

/// Pide un texto libre. Devuelve `null` si se cancela.
Future<String?> showTextPromptDialog(
  BuildContext context, {
  required String title,
  required String confirmLabel,
  String? hint,
  String initialValue = '',
  int maxLines = 1,
  int? maxLength,
  bool allowEmpty = true,
}) => showDialog<String>(
  context: context,
  builder: (_) => _TextPromptDialog(
    title: title,
    confirmLabel: confirmLabel,
    hint: hint,
    initialValue: initialValue,
    maxLines: maxLines,
    maxLength: maxLength,
    allowEmpty: allowEmpty,
  ),
);

class _TextPromptDialog extends StatefulWidget {
  const _TextPromptDialog({
    required this.title,
    required this.confirmLabel,
    required this.initialValue,
    required this.maxLines,
    required this.allowEmpty,
    this.hint,
    this.maxLength,
  });

  final String title;
  final String confirmLabel;
  final String? hint;
  final String initialValue;
  final int maxLines;
  final int? maxLength;
  final bool allowEmpty;

  @override
  State<_TextPromptDialog> createState() => _TextPromptDialogState();
}

class _TextPromptDialogState extends State<_TextPromptDialog> {
  late final TextEditingController _c = TextEditingController(text: widget.initialValue);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _submit() => Navigator.of(context).pop(_c.text.trim());

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _c,
        autofocus: true,
        minLines: 1,
        maxLines: widget.maxLines,
        maxLength: widget.maxLength,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(hintText: widget.hint),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(l.cancel)),
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: _c,
          builder: (_, v, _) => FilledButton(
            onPressed: widget.allowEmpty || v.text.trim().isNotEmpty ? _submit : null,
            child: Text(widget.confirmLabel),
          ),
        ),
      ],
    );
  }
}

/// Datos de una experiencia nueva introducidos en [showAddExperienceDialog].
typedef NewExperience = ({String cargo, String empresa, DateTime desde});

Future<NewExperience?> showAddExperienceDialog(BuildContext context) =>
    showDialog<NewExperience>(context: context, builder: (_) => const _AddExperienceDialog());

class _AddExperienceDialog extends StatefulWidget {
  const _AddExperienceDialog();

  @override
  State<_AddExperienceDialog> createState() => _AddExperienceDialogState();
}

class _AddExperienceDialogState extends State<_AddExperienceDialog> {
  final _cargo = TextEditingController();
  final _empresa = TextEditingController();
  DateTime _desde = DateTime(DateTime.now().year);

  @override
  void initState() {
    super.initState();
    // Reconstruye para habilitar «Guardar» solo con ambos campos rellenos.
    _cargo.addListener(_changed);
    _empresa.addListener(_changed);
  }

  void _changed() => setState(() {});

  @override
  void dispose() {
    _cargo.dispose();
    _empresa.dispose();
    super.dispose();
  }

  bool get _valid => _cargo.text.trim().isNotEmpty && _empresa.text.trim().isNotEmpty;

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _desde,
      firstDate: DateTime(1975),
      lastDate: DateTime.now(),
      initialDatePickerMode: DatePickerMode.year,
    );
    if (d != null && mounted) setState(() => _desde = d);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l.addExperience),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _cargo,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(labelText: l.fieldRole),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _empresa,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(labelText: l.fieldCompany),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _pickDate,
              icon: const Icon(Icons.calendar_today_outlined, size: 18),
              label: Text('${l.fieldFrom}: ${_desde.month}/${_desde.year}'),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(l.cancel)),
        FilledButton(
          onPressed: _valid
              ? () => Navigator.of(context).pop<NewExperience>((
                  cargo: _cargo.text.trim(),
                  empresa: _empresa.text.trim(),
                  desde: _desde,
                ))
              : null,
          child: Text(l.save),
        ),
      ],
    );
  }
}

/// Confirmación de borrado de cuenta escribiendo [confirmWord]. Devuelve la palabra
/// escrita (que el servidor vuelve a comprobar) o `null` si se cancela.
Future<String?> showDeleteAccountDialog(BuildContext context, {required String confirmWord}) =>
    showDialog<String>(
      context: context,
      builder: (_) => _DeleteAccountDialog(confirmWord: confirmWord),
    );

class _DeleteAccountDialog extends StatefulWidget {
  const _DeleteAccountDialog({required this.confirmWord});

  final String confirmWord;

  @override
  State<_DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<_DeleteAccountDialog> {
  final _c = TextEditingController();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return AlertDialog(
      icon: const Icon(Icons.warning_amber_rounded, color: IcexColors.destructive, size: 32),
      title: Text(l.settingsDelete),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(l.settingsDeleteBody),
          const SizedBox(height: 12),
          TextField(
            controller: _c,
            autocorrect: false,
            decoration: InputDecoration(hintText: l.settingsDeleteConfirmWord),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(l.cancel)),
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: _c,
          builder: (_, v, _) => FilledButton(
            style: FilledButton.styleFrom(backgroundColor: IcexColors.destructive),
            onPressed: v.text.trim() == widget.confirmWord
                ? () => Navigator.of(context).pop(v.text.trim())
                : null,
            child: Text(l.delete),
          ),
        ),
      ],
    );
  }
}
