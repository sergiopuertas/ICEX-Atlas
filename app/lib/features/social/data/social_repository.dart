import 'package:icex_atlas/core/api/api_client.dart';
import 'package:icex_atlas/features/profiles/domain/profile.dart';

enum ReportTarget { post, comentario, perfil, mensaje }

enum ReportMotivo { spam, acoso, contenidoInapropiado, datosPersonales, suplantacion, otro }

extension on ReportMotivo {
  String get code => switch (this) {
    ReportMotivo.spam => 'spam',
    ReportMotivo.acoso => 'acoso',
    ReportMotivo.contenidoInapropiado => 'contenido_inapropiado',
    ReportMotivo.datosPersonales => 'datos_personales',
    ReportMotivo.suplantacion => 'suplantacion',
    ReportMotivo.otro => 'otro',
  };
}

class FollowResult {
  const FollowResult({required this.isFollowing, required this.seguidoresCount});

  factory FollowResult.fromJson(Map<String, dynamic> j) => FollowResult(
    isFollowing: j['is_following'] as bool? ?? false,
    seguidoresCount: (j['seguidores_count'] as num?)?.toInt() ?? 0,
  );

  final bool isFollowing;
  final int seguidoresCount;
}

class SocialRepository {
  const SocialRepository(this._api);

  final ApiClient _api;

  Future<FollowResult> follow(String userId) async =>
      FollowResult.fromJson(await _api.rpcJson('follow', {'p_user': userId}));

  Future<FollowResult> unfollow(String userId) async =>
      FollowResult.fromJson(await _api.rpcJson('unfollow', {'p_user': userId}));

  Future<void> block(String userId) => _api.rpc('block', {'p_user': userId});

  Future<void> unblock(String userId) => _api.rpc('unblock', {'p_user': userId});

  Future<List<ProfileCard>> blocked() async =>
      (await _api.rpcList('list_blocked')).map(ProfileCard.fromJson).toList();

  Future<List<ProfileCard>> suggestions({int limit = 5}) async =>
      (await _api.rpcList('suggestions', {'p_limit': limit})).map(ProfileCard.fromJson).toList();

  Future<CommunityStats> communityStats() async =>
      CommunityStats.fromJson(await _api.rpcJson('community_stats'));

  Future<void> report(ReportTarget target, String id, ReportMotivo motivo, {String? detalle}) =>
      _api.rpc('report', {
        'p_target_tipo': target.name,
        'p_target_id': id,
        'p_motivo': motivo.code,
        'p_detalle': detalle,
      });
}
