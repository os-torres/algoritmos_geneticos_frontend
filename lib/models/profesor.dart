class Profesor {
  final int id;
  final String nombre;
  final List<int> materiasIds;
  final List<int> franjasPreferidas;

  const Profesor({
    required this.id,
    required this.nombre,
    required this.materiasIds,
    required this.franjasPreferidas,
  });

  factory Profesor.fromJson(Map<String, dynamic> j) => Profesor(
        id: j['id'],
        nombre: j['nombre'],
        materiasIds: List<int>.from(j['materias_ids'] ?? []),
        franjasPreferidas: List<int>.from(j['franjas_preferidas'] ?? []),
      );

  Map<String, dynamic> toJson() => {
        'nombre': nombre,
        'materias_ids': materiasIds,
        'franjas_preferidas': franjasPreferidas,
      };

  Profesor copyWith({
    String? nombre,
    List<int>? materiasIds,
    List<int>? franjasPreferidas,
  }) =>
      Profesor(
        id: id,
        nombre: nombre ?? this.nombre,
        materiasIds: materiasIds ?? this.materiasIds,
        franjasPreferidas: franjasPreferidas ?? this.franjasPreferidas,
      );
}
