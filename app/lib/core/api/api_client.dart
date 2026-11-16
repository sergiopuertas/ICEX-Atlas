import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:icex_atlas/core/errors/failure.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

typedef Json = Map<String, dynamic>;

/// Única puerta de la app al backend. Todos los repositorios dependen de esta interfaz
/// (D-003): llamadas RPC al esquema `api`, Edge Functions y URLs firmadas de Storage.
/// En tests se sustituye por un doble (`FakeApiClient`).
abstract interface class ApiClient {
  Future<Object?> rpc(String function, [Json? params]);

  Future<Json> invokeFunction(
    String name, {
    Object? body,
    Map<String, String>? headers,
    Map<String, String>? query,
  });

  Future<String> signedUrl(String bucket, String path, {int? width, int? height});
}

extension ApiClientX on ApiClient {
  Future<Json> rpcJson(String function, [Json? params]) async =>
      Json.from((await rpc(function, params))! as Map);

  Future<List<Json>> rpcList(String function, [Json? params]) async =>
      ((await rpc(function, params)) as List? ?? const []).map((e) => Json.from(e as Map)).toList();
}

class SupabaseApiClient implements ApiClient {
  SupabaseApiClient(this._client);

  final SupabaseClient _client;
  final _signed = <String, ({String url, DateTime expires})>{};

  @override
  Future<Object?> rpc(String function, [Json? params]) => _guard(() async {
    final Object? res = await _client.rpc<dynamic>(function, params: params);
    return res;
  });

  @override
  Future<Json> invokeFunction(
    String name, {
    Object? body,
    Map<String, String>? headers,
    Map<String, String>? query,
  }) => _guard(() async {
    final res = await _client.functions.invoke(
      name,
      body: body,
      headers: headers,
      queryParameters: query,
    );
    final data = res.data;
    return data is Map ? Json.from(data) : <String, dynamic>{};
  });

  @override
  Future<String> signedUrl(String bucket, String path, {int? width, int? height}) async {
    final key = '$bucket/$path/$width/$height';
    final hit = _signed[key];
    if (hit != null && hit.expires.isAfter(DateTime.now())) return hit.url;
    final url = await _guard(
      () => _client.storage
          .from(bucket)
          .createSignedUrl(
            path,
            3600,
            transform: width == null && height == null
                ? null
                : TransformOptions(width: width, height: height, resize: ResizeMode.cover),
          ),
    );
    _signed[key] = (url: url, expires: DateTime.now().add(const Duration(minutes: 55)));
    return url;
  }

  Future<T> _guard<T>(Future<T> Function() run) async {
    try {
      return await run();
    } on PostgrestException catch (e) {
      throw AppFailure.fromCode(e.code, e.message, hint: e.hint);
    } on FunctionException catch (e) {
      final details = e.details;
      final msg = details is Map ? details['message']?.toString() : e.reasonPhrase;
      throw AppFailure.fromCode('${e.status}', msg);
    } on StorageException catch (e) {
      throw AppFailure.fromCode(e.statusCode, e.message);
    } on SocketException {
      throw const NetworkFailure();
    } on TimeoutException {
      throw const NetworkFailure();
    } on AuthException catch (e) {
      throw ForbiddenFailure(e.message);
    }
  }
}

/// Subida de imágenes a través de la Edge Function `media-upload` (valida y quita EXIF).
extension MediaUpload on ApiClient {
  Future<String> uploadImage(Uint8List bytes, {required String bucket}) async {
    final res = await invokeFunction(
      'media-upload',
      body: bytes,
      headers: const {'Content-Type': 'application/octet-stream'},
      query: {'bucket': bucket},
    );
    return res['path'] as String;
  }
}
