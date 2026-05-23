class Materia {
  final int id;
  final String nombre;
  final int semestre;
  final String grupo;
  final int creditos;
  final List<int> bloques;

  const Materia({
    required this.id,
    required this.nombre,
    required this.semestre,
    required this.grupo,
    required this.creditos,
    required this.bloques,
  });

  int get sesionesPorSemana => bloques.length;
  int get horasSemanales => bloques.fold(0, (s, b) => s + b);

  factory Materia.fromJson(Map<String, dynamic> j) => Materia(
        id: j['id'],
        nombre: j['nombre'],
        semestre: j['semestre'] ?? 1,
        grupo: j['grupo'],
        creditos: j['creditos'],
        bloques: (j['bloques'] as List<dynamic>).map((e) => e as int).toList(),
      );

  Map<String, dynamic> toJson() => {
        'nombre': nombre,
        'semestre': semestre,
        'grupo': grupo,
        'creditos': creditos,
        'bloques': bloques,
      };

  Materia copyWith({
    String? nombre,
    int? semestre,
    String? grupo,
    int? creditos,
    List<int>? bloques,
  }) =>
      Materia(
        id: id,
        nombre: nombre ?? this.nombre,
        semestre: semestre ?? this.semestre,
        grupo: grupo ?? this.grupo,
        creditos: creditos ?? this.creditos,
        bloques: bloques ?? this.bloques,
      );
}
