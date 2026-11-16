import 'package:sentry_flutter/sentry_flutter.dart';

final _email = RegExp(r'[\w.+-]+@[\w-]+\.[\w.-]+');
final _jwt = RegExp(r'eyJ[\w-]+\.[\w-]+\.[\w-]+');
final _uuid = RegExp(
  '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}',
  caseSensitive: false,
);

/// Elimina datos personales antes de enviar a Sentry (RGPD): sin usuario, sin emails,
/// sin tokens y sin identificadores; las rutas con slug se generalizan.
String scrubText(String input) => input
    .replaceAll(_email, '[email]')
    .replaceAll(_jwt, '[token]')
    .replaceAll(_uuid, '[id]')
    .replaceAll(RegExp('/perfil/[^/?#]+'), '/perfil/[slug]');

SentryEvent? scrubEvent(SentryEvent event, Hint hint) {
  event
    ..user = null
    ..request = null
    ..serverName = null;
  final msg = event.message;
  if (msg != null) {
    event.message = SentryMessage(
      scrubText(msg.formatted),
      template: msg.template,
      params: msg.params,
    );
  }
  for (final b in event.breadcrumbs ?? <Breadcrumb>[]) {
    if (b.message != null) b.message = scrubText(b.message!);
    b.data?.clear();
  }
  for (final ex in event.exceptions ?? <SentryException>[]) {
    if (ex.value != null) ex.value = scrubText(ex.value!);
  }
  return event;
}
