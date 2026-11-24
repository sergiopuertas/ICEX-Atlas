import 'package:flutter/material.dart';
import 'package:icex_atlas/l10n/app_localizations.dart';
import 'package:icex_atlas/shared/widgets/common.dart';
import 'package:url_launcher/url_launcher.dart';

/// Abre [url] en el navegador. Si no se puede (sin navegador, URL inválida), lo intenta
/// dentro de la app y, si tampoco, avisa al usuario. Antes el fallo era silencioso: el botón
/// parecía no hacer nada.
Future<void> openExternalUrl(BuildContext context, String url) async {
  final l = AppLocalizations.of(context);
  final uri = Uri.tryParse(url);
  var ok = false;
  if (uri != null && uri.hasScheme) {
    try {
      ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok) ok = await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
    } on Object {
      ok = false;
    }
  }
  if (!ok && context.mounted) showSnack(context, l.linkOpenError(url));
}
