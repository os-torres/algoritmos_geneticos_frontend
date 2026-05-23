class Asignacion {
  final int sesionId;
  final int materiaId;
  final String materia;
  final String profesor;
  final String grupo;
  final int semestre;
  final int duracionHoras;
  final String dia;
  final String horaInicio;
  final String horaFin;
  final String salon;
  final int salonCapacidad;

  const Asignacion({
    required this.sesionId,
    required this.materiaId,
    required this.materia,
    required this.profesor,
    required this.grupo,
    required this.semestre,
    required this.duracionHoras,
    required this.dia,
    required this.horaInicio,
    required this.horaFin,
    required this.salon,
    required this.salonCapacidad,
  });

  factory Asignacion.fromJson(Map<String, dynamic> j) => Asignacion(
        sesionId: j['sesion_id'],
        materiaId: j['materia_id'] ?? 0,
        materia: j['materia'],
        profesor: j['profesor'],
        grupo: j['grupo'],
        semestre: j['semestre'] ?? 1,
        duracionHoras: j['duracion_horas'] ?? 2,
        dia: j['dia'],
        horaInicio: j['hora_inicio'],
        horaFin: j['hora_fin'],
        salon: j['salon'],
        salonCapacidad: j['salon_capacidad'],
      );

  String get bloque => '$horaInicio–$horaFin';
}
