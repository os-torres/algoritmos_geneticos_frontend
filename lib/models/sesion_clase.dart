class SesionClase {
  final int id;
  final String materia;
  final String profesor;
  final String grupo;

  const SesionClase({
    required this.id,
    required this.materia,
    required this.profesor,
    required this.grupo,
  });

  factory SesionClase.fromJson(Map<String, dynamic> j) => SesionClase(
        id: j['id'],
        materia: j['materia'],
        profesor: j['profesor'],
        grupo: j['grupo'],
      );
}
