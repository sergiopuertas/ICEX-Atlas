import 'package:icex_atlas/features/profiles/domain/profile.dart';

class OrientadorQuery {
  const OrientadorQuery({
    required this.fase,
    required this.pais,
    required this.sector,
    required this.consulta,
  });

  final Fase fase;
  final String pais;
  final String sector;
  final String consulta;

  Map<String, dynamic> toJson() => {
    'fase': fase.code,
    'pais': pais,
    'sector': sector,
    'consulta': consulta,
  };

  OrientadorQuery copyWith({Fase? fase, String? pais, String? sector, String? consulta}) =>
      OrientadorQuery(
        fase: fase ?? this.fase,
        pais: pais ?? this.pais,
        sector: sector ?? this.sector,
        consulta: consulta ?? this.consulta,
      );
}

class SuggestedAlumni {
  const SuggestedAlumni({
    required this.userId,
    required this.slug,
    required this.nombre,
    required this.motivo,
    this.fase,
    this.promocion,
  });

  factory SuggestedAlumni.fromJson(Map<String, dynamic> j) => SuggestedAlumni(
    userId: j['user_id'] as String,
    slug: j['slug'] as String,
    nombre: j['nombre'] as String,
    motivo: j['motivo'] as String? ?? '',
    fase: j['fase'] == null ? null : Fase.parse(j['fase'] as String),
    promocion: (j['promocion'] as num?)?.toInt(),
  );

  final String userId;
  final String slug;
  final String nombre;
  final String motivo;
  final Fase? fase;
  final int? promocion;
}

class OrientadorResult {
  const OrientadorResult({
    required this.query,
    required this.resumen,
    required this.pasos,
    required this.alumni,
    required this.aviso,
    this.restantes,
  });

  factory OrientadorResult.fromJson(OrientadorQuery query, Map<String, dynamic> j) =>
      OrientadorResult(
        query: query,
        resumen: j['resumen'] as String? ?? '',
        pasos: (j['pasos'] as List? ?? const []).cast<String>(),
        alumni: (j['alumni'] as List? ?? const [])
            .map((e) => SuggestedAlumni.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        aviso: j['aviso'] as String? ?? '',
        restantes: (j['restantes'] as num?)?.toInt(),
      );

  final OrientadorQuery query;
  final String resumen;
  final List<String> pasos;
  final List<SuggestedAlumni> alumni;
  final String aviso;
  final int? restantes;
}

/// Catálogos del mockup.
abstract final class OrientadorCatalog {
  static const paises = [
    'Alemania', 'Arabia Saudí', 'Argentina', 'Australia', 'Brasil', 'Bélgica', 'Canadá', 'Chile',
    'China', 'Colombia', 'Corea del Sur', 'EAU', 'EE. UU.', 'España', 'Francia', 'India',
    'Indonesia', 'Italia', 'Japón', 'Marruecos', 'México', 'Nigeria', 'Países Bajos', 'Perú',
    'Polonia', 'Reino Unido', 'Singapur', 'Sudáfrica', 'Suecia', 'Turquía', //
  ];

  static const sectores = [
    'Energía', 'Agroalimentario', 'Infraestructuras', 'Banca', 'Tecnología', 'Moda', 'Industria',
    'Turismo', 'Salud', 'Consultoría', //
  ];

  /// Atajos: (etiqueta, fase, país, sector, consulta)
}
