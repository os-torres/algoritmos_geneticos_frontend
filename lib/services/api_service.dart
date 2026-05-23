import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config.dart';
import '../models/materia.dart';
import '../models/profesor.dart';
import '../models/salon.dart';
import '../models/franja_horaria.dart';
import '../models/sesion_clase.dart';

class ApiService {
  static final ApiService _i = ApiService._();
  factory ApiService() => _i;
  ApiService._();

  String get _base => AppConfig.baseUrl;

  // -----------------------------------------------------------------------
  // Datos generales
  // -----------------------------------------------------------------------

  Future<Map<String, dynamic>> getDatos() => _get('/api/datos');
  Future<Map<String, dynamic>> getAcercaDe() => _get('/api/acerca-de');
  Future<void> resetDatos() => _post('/api/datos/reset', {});

  // -----------------------------------------------------------------------
  // Materias
  // -----------------------------------------------------------------------

  Future<List<Materia>> getMaterias() async {
    final list = await _getList('/api/materias');
    return list.map((e) => Materia.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Materia> createMateria(Map<String, dynamic> body) async {
    final json = await _post('/api/materias', body);
    return Materia.fromJson(json);
  }

  Future<Materia> updateMateria(int id, Map<String, dynamic> body) async {
    final json = await _put('/api/materias/$id', body);
    return Materia.fromJson(json);
  }

  Future<void> deleteMateria(int id) => _delete('/api/materias/$id');

  // -----------------------------------------------------------------------
  // Profesores
  // -----------------------------------------------------------------------

  Future<List<Profesor>> getProfesores() async {
    final list = await _getList('/api/profesores');
    return list.map((e) => Profesor.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Profesor> createProfesor(Map<String, dynamic> body) async {
    final json = await _post('/api/profesores', body);
    return Profesor.fromJson(json);
  }

  Future<Profesor> updateProfesor(int id, Map<String, dynamic> body) async {
    final json = await _put('/api/profesores/$id', body);
    return Profesor.fromJson(json);
  }

  Future<void> deleteProfesor(int id) => _delete('/api/profesores/$id');

  // -----------------------------------------------------------------------
  // Salones
  // -----------------------------------------------------------------------

  Future<List<Salon>> getSalones() async {
    final list = await _getList('/api/salones');
    return list.map((e) => Salon.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Salon> createSalon(Map<String, dynamic> body) async {
    final json = await _post('/api/salones', body);
    return Salon.fromJson(json);
  }

  Future<Salon> updateSalon(int id, Map<String, dynamic> body) async {
    final json = await _put('/api/salones/$id', body);
    return Salon.fromJson(json);
  }

  Future<void> deleteSalon(int id) => _delete('/api/salones/$id');

  // -----------------------------------------------------------------------
  // Franjas horarias
  // -----------------------------------------------------------------------

  Future<List<FranjaHoraria>> getFranjas() async {
    final list = await _getList('/api/franjas');
    return list.map((e) => FranjaHoraria.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<FranjaHoraria> createFranja(Map<String, dynamic> body) async {
    final json = await _post('/api/franjas', body);
    return FranjaHoraria.fromJson(json);
  }

  Future<FranjaHoraria> updateFranja(int id, Map<String, dynamic> body) async {
    final json = await _put('/api/franjas/$id', body);
    return FranjaHoraria.fromJson(json);
  }

  Future<void> deleteFranja(int id) => _delete('/api/franjas/$id');

  // -----------------------------------------------------------------------
  // Sesiones
  // -----------------------------------------------------------------------

  Future<List<SesionClase>> getSesiones() async {
    final list = await _getList('/api/sesiones');
    return list.map((e) => SesionClase.fromJson(e as Map<String, dynamic>)).toList();
  }

  // -----------------------------------------------------------------------
  // Importación masiva
  // -----------------------------------------------------------------------

  /// Envía el cuerpo JSON al endpoint /api/importar y devuelve el resultado.
  Future<Map<String, dynamic>> importarDatos(Map<String, dynamic> body) =>
      _post('/api/importar', body);

  // -----------------------------------------------------------------------
  // Optimización (síncrona)
  // -----------------------------------------------------------------------

  Future<Map<String, dynamic>> optimizar(Map<String, dynamic> params) =>
      _post('/api/optimizar', params);

  // -----------------------------------------------------------------------
  // HTTP helpers
  // -----------------------------------------------------------------------

  Map<String, String> get _headers => {'Content-Type': 'application/json'};

  Future<Map<String, dynamic>> _get(String path) async {
    final res = await http.get(Uri.parse('$_base$path'), headers: _headers);
    _check(res);
    return jsonDecode(res.body);
  }

  Future<List<dynamic>> _getList(String path) async {
    final res = await http.get(Uri.parse('$_base$path'), headers: _headers);
    _check(res);
    return jsonDecode(res.body);
  }

  Future<Map<String, dynamic>> _post(String path, Map<String, dynamic> body) async {
    final res = await http.post(
      Uri.parse('$_base$path'),
      headers: _headers,
      body: jsonEncode(body),
    );
    _check(res);
    return jsonDecode(res.body);
  }

  Future<Map<String, dynamic>> _put(String path, Map<String, dynamic> body) async {
    final res = await http.put(
      Uri.parse('$_base$path'),
      headers: _headers,
      body: jsonEncode(body),
    );
    _check(res);
    return jsonDecode(res.body);
  }

  Future<void> _delete(String path) async {
    final res = await http.delete(Uri.parse('$_base$path'), headers: _headers);
    _check(res);
  }

  void _check(http.Response res) {
    if (res.statusCode >= 400) {
      final body = jsonDecode(res.body);
      throw ApiException(body['detail']?.toString() ?? 'Error ${res.statusCode}');
    }
  }
}

class ApiException implements Exception {
  final String message;
  const ApiException(this.message);
  @override
  String toString() => message;
}
