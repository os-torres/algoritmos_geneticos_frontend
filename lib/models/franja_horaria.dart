class FranjaHoraria {
  final int id;
  final String dia;
  final String horaInicio;
  final String horaFin;

  const FranjaHoraria({
    required this.id,
    required this.dia,
    required this.horaInicio,
    required this.horaFin,
  });

  factory FranjaHoraria.fromJson(Map<String, dynamic> j) => FranjaHoraria(
        id: j['id'],
        dia: j['dia'],
        horaInicio: j['hora_inicio'],
        horaFin: j['hora_fin'],
      );

  Map<String, dynamic> toJson() => {
        'dia': dia,
        'hora_inicio': horaInicio,
        'hora_fin': horaFin,
      };

  String get label => '$dia $horaInicio–$horaFin';

  FranjaHoraria copyWith({String? dia, String? horaInicio, String? horaFin}) =>
      FranjaHoraria(
        id: id,
        dia: dia ?? this.dia,
        horaInicio: horaInicio ?? this.horaInicio,
        horaFin: horaFin ?? this.horaFin,
      );
}
