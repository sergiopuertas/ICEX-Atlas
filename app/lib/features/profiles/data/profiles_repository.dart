import 'dart:typed_data';

import 'package:icex_atlas/core/api/api_client.dart';
import 'package:icex_atlas/core/api/page.dart';
import 'package:icex_atlas/features/profiles/domain/profile.dart';

class ProfileUpdate {
  const ProfileUpdate({
    this.nombre,
    this.cargo,
    this.empresa,
    this.fase,
    this.pais,
    this.paisCode,
    this.ciudad,
    this.sector,
    this.bio,
    this.lat,
    this.lng,
    this.fotoPath,
  });

  final String? nombre;
  final String? cargo;
  final String? empresa;
  final Fase? fase;
  final String? pais;
  final String? paisCode;
  final String? ciudad;
  final String? sector;
  final String? bio;
  final double? lat;
  final double? lng;
  final String? fotoPath;

  Map<String, dynamic> toParams() => {
    'p_nombre': nombre,
    'p_cargo': cargo,
    'p_empresa': empresa,
    'p_fase': fase?.code,
    'p_pais': pais,
    'p_pais_code': paisCode,
    'p_ciudad': ciudad,
    'p_sector': sector,
    'p_bio': bio,
    'p_lat': lat,
    'p_lng': lng,
    'p_foto_path': fotoPath,
  }..removeWhere((_, v) => v == null);
}

class ProfilesRepository {
  const ProfilesRepository(this._api);

  final ApiClient _api;

  Future<Me> me() async => Me.fromJson(await _api.rpcJson('me'));

  Future<ProfileDetail> getProfile({String? slug, String? userId}) async {
    assert(slug != null || userId != null, 'slug o userId');
    return ProfileDetail.fromJson(
      await _api.rpcJson('get_profile', {'p_slug': slug, 'p_user': userId}),
    );
  }

  Future<ProfileDetail> updateMyProfile(ProfileUpdate update) async =>
      ProfileDetail.fromJson(await _api.rpcJson('update_my_profile', update.toParams()));

  Future<ProfileDetail> setPrivacy({
    Map<String, Visibilidad>? visibilidad,
    bool? aceptaSugerencias,
  }) async => ProfileDetail.fromJson(
    await _api.rpcJson('set_privacy', {
      'p_visibilidad': visibilidad?.map((k, v) => MapEntry(k, v.code)),
      'p_acepta_sugerencias': aceptaSugerencias,
    }),
  );

  Future<ProfileDetail> upsertExperience({
    required String id,
    required String empresa,
    required String cargo,
    required DateTime desde,
    DateTime? hasta,
  }) async => ProfileDetail.fromJson(
    await _api.rpcJson('upsert_experience', {
      'p_id': id,
      'p_empresa': empresa,
      'p_cargo': cargo,
      'p_desde': _date(desde),
      'p_hasta': hasta == null ? null : _date(hasta),
    }),
  );

  Future<void> deleteExperience(String id) => _api.rpc('delete_experience', {'p_id': id});

  /// Sube la foto (la Edge Function valida y quita EXIF) y la asigna al perfil.
  Future<ProfileDetail> uploadAvatar(Uint8List bytes) async {
    final path = await _api.uploadImage(bytes, bucket: 'avatars');
    return await updateMyProfile(ProfileUpdate(fotoPath: path));
  }

  Future<CursorPage<ProfileCard>> listFollows(
    String userId, {
    required bool following,
    String? cursor,
  }) async => CursorPage.fromJson(
    await _api.rpcJson('list_follows', {
      'p_user': userId,
      'p_direction': following ? 'siguiendo' : 'seguidores',
      'p_cursor': cursor,
    }),
    ProfileCard.fromJson,
  );

  static String _date(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
