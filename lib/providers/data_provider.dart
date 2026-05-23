import 'package:flutter/material.dart';
import '../models/materia.dart';
import '../models/profesor.dart';
import '../models/salon.dart';
import '../models/franja_horaria.dart';
import '../models/sesion_clase.dart';
import '../services/api_service.dart';

class DataProvider extends ChangeNotifier {
  final _api = ApiService();

  List<Materia> materias = [];
  List<Profesor> profesores = [];
  List<Salon> salones = [];
  List<FranjaHoraria> franjas = [];
  List<SesionClase> sesiones = [];
  Map<String, dynamic> resumen = {};

  bool loading = false;
  String? error;

  Future<void> cargarTodo() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      final data = await _api.getDatos();
      materias   = (data['materias']   as List).map((e) => Materia.fromJson(e as Map<String, dynamic>)).toList();
      profesores = (data['profesores'] as List).map((e) => Profesor.fromJson(e as Map<String, dynamic>)).toList();
      salones    = (data['salones']    as List).map((e) => Salon.fromJson(e as Map<String, dynamic>)).toList();
      franjas    = (data['franjas']    as List).map((e) => FranjaHoraria.fromJson(e as Map<String, dynamic>)).toList();
      sesiones   = (data['sesiones']   as List).map((e) => SesionClase.fromJson(e as Map<String, dynamic>)).toList();
      resumen    = data['resumen'] ?? {};
    } catch (e) {
      error = e.toString();
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  // -----------------------------------------------------------------------
  // Materias
  // -----------------------------------------------------------------------

  Future<bool> agregarMateria(Map<String, dynamic> body) async {
    try {
      final m = await _api.createMateria(body);
      materias.add(m);
      await _refreshSesiones();
      notifyListeners();
      return true;
    } catch (e) {
      error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> editarMateria(int id, Map<String, dynamic> body) async {
    try {
      final m = await _api.updateMateria(id, body);
      final idx = materias.indexWhere((x) => x.id == id);
      if (idx >= 0) materias[idx] = m;
      await _refreshSesiones();
      notifyListeners();
      return true;
    } catch (e) {
      error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> eliminarMateria(int id) async {
    try {
      await _api.deleteMateria(id);
      materias.removeWhere((x) => x.id == id);
      await _refreshSesiones();
      notifyListeners();
      return true;
    } catch (e) {
      error = e.toString();
      notifyListeners();
      return false;
    }
  }

  // -----------------------------------------------------------------------
  // Profesores
  // -----------------------------------------------------------------------

  Future<bool> agregarProfesor(Map<String, dynamic> body) async {
    try {
      final p = await _api.createProfesor(body);
      profesores.add(p);
      await _refreshSesiones();
      notifyListeners();
      return true;
    } catch (e) {
      error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> editarProfesor(int id, Map<String, dynamic> body) async {
    try {
      final p = await _api.updateProfesor(id, body);
      final idx = profesores.indexWhere((x) => x.id == id);
      if (idx >= 0) profesores[idx] = p;
      await _refreshSesiones();
      notifyListeners();
      return true;
    } catch (e) {
      error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> eliminarProfesor(int id) async {
    try {
      await _api.deleteProfesor(id);
      profesores.removeWhere((x) => x.id == id);
      await _refreshSesiones();
      notifyListeners();
      return true;
    } catch (e) {
      error = e.toString();
      notifyListeners();
      return false;
    }
  }

  // -----------------------------------------------------------------------
  // Salones
  // -----------------------------------------------------------------------

  Future<bool> agregarSalon(Map<String, dynamic> body) async {
    try {
      final s = await _api.createSalon(body);
      salones.add(s);
      notifyListeners();
      return true;
    } catch (e) {
      error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> editarSalon(int id, Map<String, dynamic> body) async {
    try {
      final s = await _api.updateSalon(id, body);
      final idx = salones.indexWhere((x) => x.id == id);
      if (idx >= 0) salones[idx] = s;
      notifyListeners();
      return true;
    } catch (e) {
      error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> eliminarSalon(int id) async {
    try {
      await _api.deleteSalon(id);
      salones.removeWhere((x) => x.id == id);
      notifyListeners();
      return true;
    } catch (e) {
      error = e.toString();
      notifyListeners();
      return false;
    }
  }

  // -----------------------------------------------------------------------
  // Franjas
  // -----------------------------------------------------------------------

  Future<bool> agregarFranja(Map<String, dynamic> body) async {
    try {
      final f = await _api.createFranja(body);
      franjas.add(f);
      notifyListeners();
      return true;
    } catch (e) {
      error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> editarFranja(int id, Map<String, dynamic> body) async {
    try {
      final f = await _api.updateFranja(id, body);
      final idx = franjas.indexWhere((x) => x.id == id);
      if (idx >= 0) franjas[idx] = f;
      notifyListeners();
      return true;
    } catch (e) {
      error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> eliminarFranja(int id) async {
    try {
      await _api.deleteFranja(id);
      franjas.removeWhere((x) => x.id == id);
      notifyListeners();
      return true;
    } catch (e) {
      error = e.toString();
      notifyListeners();
      return false;
    }
  }

  // -----------------------------------------------------------------------
  // Reset
  // -----------------------------------------------------------------------

  Future<void> resetearDatos() async {
    loading = true;
    notifyListeners();
    try {
      await _api.resetDatos();
      await cargarTodo();
    } catch (e) {
      error = e.toString();
      loading = false;
      notifyListeners();
    }
  }

  // -----------------------------------------------------------------------
  // Importar desde JSON
  // -----------------------------------------------------------------------

  /// Devuelve un mapa con el resumen de lo importado, o null si hubo error.
  Future<Map<String, dynamic>?> importarDesdeJson(Map<String, dynamic> jsonBody) async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      final resultado = await _api.importarDatos(jsonBody);
      await cargarTodo();   // recarga todo con los nuevos datos
      return resultado;
    } catch (e) {
      error = e.toString();
      loading = false;
      notifyListeners();
      return null;
    }
  }

  /// Lista de semestres únicos actualmente cargados (p.ej. [1, 2, 3]).
  List<int> get semestresDisponibles {
    final nums = (resumen['semestres_disponibles'] as List?)
        ?.map((e) => e as int)
        .toList() ?? [];
    return nums;
  }

  Future<void> _refreshSesiones() async {
    sesiones = await _api.getSesiones();
    final data = await _api.getDatos();
    resumen = data['resumen'] ?? {};
  }
}
