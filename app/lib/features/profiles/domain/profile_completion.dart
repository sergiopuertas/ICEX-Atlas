import 'package:icex_atlas/features/profiles/domain/profile.dart';

/// Lo que falta para que un perfil esté completo. Un perfil completo recibe más
/// visitas y mejores sugerencias (la promoción, la ciudad, la empresa y el sector
/// alimentan «Personas que quizá conozcas»).
enum ProfileItem { photo, position, location, sector, bio, experience }

class ProfileCompletion {
  const ProfileCompletion._(this.missing);

  factory ProfileCompletion.of(ProfileDetail p) {
    final c = p.card;
    bool has(String? v) => v != null && v.trim().isNotEmpty;
    return ProfileCompletion._([
      if (!has(c.fotoPath)) ProfileItem.photo,
      if (!has(c.cargo) && !has(c.empresa)) ProfileItem.position,
      if (!has(c.ciudad) && !has(c.pais)) ProfileItem.location,
      if (!has(c.sector)) ProfileItem.sector,
      if (!has(p.bio)) ProfileItem.bio,
      if (p.experiences.isEmpty) ProfileItem.experience,
    ]);
  }

  /// En el orden en que más ayudan: foto y puesto primero.
  final List<ProfileItem> missing;

  int get total => ProfileItem.values.length;
  int get done => total - missing.length;
  double get ratio => done / total;
  int get percent => (ratio * 100).round();
  bool get isComplete => missing.isEmpty;

  /// En Inicio solo se insiste cuando falta lo básico (la mitad o más). Con algún
  /// detalle pendiente basta el aviso en el propio perfil.
  bool get worthNudgingOnHome => done <= total ~/ 2;
}
