class Salon {
  final int id;
  final String nombre;
  final int capacidad;

  const Salon({required this.id, required this.nombre, required this.capacidad});

  factory Salon.fromJson(Map<String, dynamic> j) =>
      Salon(id: j['id'], nombre: j['nombre'], capacidad: j['capacidad']);

  Map<String, dynamic> toJson() => {'nombre': nombre, 'capacidad': capacidad};

  Salon copyWith({String? nombre, int? capacidad}) =>
      Salon(id: id, nombre: nombre ?? this.nombre, capacidad: capacidad ?? this.capacidad);
}
