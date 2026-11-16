import 'dart:convert';

import 'package:icex_atlas/core/api/api_client.dart';

/// Derechos RGPD del socio: exportación (art. 15/20) y borrado completo (art. 17).
class AccountRepository {
  const AccountRepository(this._api);

  final ApiClient _api;

  static const deleteConfirmation = 'BORRAR MI CUENTA';

  /// JSON legible con todos los datos del socio.
  Future<String> exportData() async =>
      const JsonEncoder.withIndent('  ').convert(await _api.rpcJson('export_my_data'));

  /// Borra ficheros de Storage y la cuenta (Edge Function `account-delete`).
  Future<void> deleteAccount(String confirmation) async {
    if (confirmation.trim() != deleteConfirmation) {
      throw ArgumentError.value(confirmation, 'confirmation', 'Confirmación incorrecta');
    }
    await _api.invokeFunction('account-delete', body: {'confirmacion': deleteConfirmation});
  }
}
