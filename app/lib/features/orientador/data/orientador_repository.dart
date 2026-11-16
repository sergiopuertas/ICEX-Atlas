import 'package:icex_atlas/core/api/api_client.dart';
import 'package:icex_atlas/features/orientador/domain/orientador.dart';

class OrientadorRepository {
  const OrientadorRepository(this._api);

  final ApiClient _api;

  /// Edge Function `orientador` (IA con proveedor intercambiable y límite diario).
  Future<OrientadorResult> ask(OrientadorQuery query) async => OrientadorResult.fromJson(
    query,
    await _api.invokeFunction('orientador', body: query.toJson()),
  );
}
