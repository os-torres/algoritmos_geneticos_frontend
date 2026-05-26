import 'dart:async';
import 'package:flutter/material.dart';
import '../models/resultado_generacion.dart';
import '../models/asignacion.dart';
import '../services/api_service.dart';
// ignore: unused_import — ConflictoDetalle se usa en conflictosDetalle
export '../models/resultado_generacion.dart' show ConflictoDetalle;

enum OptStatus { idle, running, done, error }

class OptimizationProvider extends ChangeNotifier {
  OptStatus status = OptStatus.idle;
  String? errorMsg;

  // ── Parámetros del AG ─────────────────────────────────────────────────────
  int    _tamPoblacion    = 100;
  int    _numGeneraciones = 200;
  double _probCruz        = 0.85;
  double _probMut         = 0.10;
  int    _numElite        = 2;
  int    _tamTorneo       = 5;
  int    _paciencia       = 30;
  List<int> _semestresFiltro = [];

  int       get tamPoblacion    => _tamPoblacion;
  int       get numGeneraciones => _numGeneraciones;
  double    get probCruz        => _probCruz;
  double    get probMut         => _probMut;
  int       get numElite        => _numElite;
  int       get tamTorneo       => _tamTorneo;
  int       get paciencia       => _paciencia;
  List<int> get semestresFiltro => List.unmodifiable(_semestresFiltro);

  set tamPoblacion(int v)         { _tamPoblacion    = v; notifyListeners(); }
  set numGeneraciones(int v)      { _numGeneraciones = v; notifyListeners(); }
  set probCruz(double v)          { _probCruz        = v; notifyListeners(); }
  set probMut(double v)           { _probMut         = v; notifyListeners(); }
  set numElite(int v)             { _numElite        = v; notifyListeners(); }
  set tamTorneo(int v)            { _tamTorneo       = v; notifyListeners(); }
  set paciencia(int v)            { _paciencia       = v; notifyListeners(); }

  void toggleSemestre(int s) {
    if (_semestresFiltro.contains(s)) {
      _semestresFiltro.remove(s);
    } else {
      _semestresFiltro.add(s);
      _semestresFiltro.sort();
    }
    notifyListeners();
  }

  void limpiarSemestres() {
    _semestresFiltro.clear();
    notifyListeners();
  }

  set semestresFiltro(List<int> v) {
    _semestresFiltro = List.of(v);
    notifyListeners();
  }

  // ── Estado de la optimización ─────────────────────────────────────────────
  final List<ResultadoGeneracion> historial = [];
  List<Asignacion>       horarioFinal      = [];
  List<IndividuoTop>     topIndividuos     = [];
  List<ConflictoDetalle> conflictosDetalle = [];
  double  mejorFitness     = 0;
  int     conflictos       = 0;
  int     generacionActual = 0;
  String  razonParada      = "";

  // Tiempo transcurrido (para mostrar en la UI mientras espera)
  int    _elapsedSec = 0;
  Timer? _timer;
  int    _runId      = 0;   // token para ignorar respuestas de runs anteriores

  int get elapsedSec => _elapsedSec;

  // ── Ciclo de vida ─────────────────────────────────────────────────────────

  void iniciar() {
    _resetState();
    status = OptStatus.running;
    notifyListeners();

    // Contador de segundos transcurridos (feedback visual)
    _elapsedSec = 0;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _elapsedSec++;
      notifyListeners();
    });

    _runREST(++_runId);
  }

  Future<void> _runREST(int myRunId) async {
    try {
      final result = await ApiService().optimizar({
        'tam_poblacion':    _tamPoblacion,
        'num_generaciones': _numGeneraciones,
        'prob_cruzamiento': _probCruz,
        'prob_mutacion':    _probMut,
        'num_elite':        _numElite,
        'tam_torneo':       _tamTorneo,
        'paciencia':        _paciencia,
        if (_semestresFiltro.isNotEmpty)
          'semestres_filtro': _semestresFiltro,
      });

      if (myRunId != _runId) return; // fue cancelado

      // ── Historial de generaciones (para la gráfica) ──
      final rawHistorial = result['historial'] as List? ?? [];
      historial.addAll(rawHistorial.map(
        (e) => ResultadoGeneracion.fromHistorialItem(e as Map<String, dynamic>),
      ));

      // ── Resultado final ──────────────────────────────
      generacionActual = result['generaciones_ejecutadas'] as int? ?? 0;
      mejorFitness     = (result['mejor_fitness'] as num? ?? 0).toDouble();
      conflictos       = result['conflictos_finales'] as int? ?? 0;
      razonParada      = result['razon_parada'] as String? ?? '';

      final rawHorario = result['mejor_horario'] as List? ?? [];
      horarioFinal = rawHorario
          .map((e) => Asignacion.fromJson(e as Map<String, dynamic>))
          .toList();

      final rawConflictos = result['conflictos_detalle'] as List? ?? [];
      conflictosDetalle = rawConflictos
          .map((e) => ConflictoDetalle.fromJson(e as Map<String, dynamic>))
          .toList();

      status = OptStatus.done;
    } on TimeoutException {
      if (myRunId != _runId) return;
      errorMsg = 'La optimización tardó demasiado. '
          'Reduce las generaciones o el tamaño de población e intenta de nuevo.';
      status = OptStatus.error;
    } catch (e) {
      if (myRunId != _runId) return;
      errorMsg = e.toString();
      status = OptStatus.error;
    } finally {
      if (myRunId == _runId) {
        _timer?.cancel();
        _timer = null;
      }
    }

    if (myRunId == _runId) notifyListeners();
  }

  void detener() {
    _runId++;           // invalida el run actual
    _timer?.cancel();
    _timer = null;
    if (status == OptStatus.running) {
      status = OptStatus.idle;
      notifyListeners();
    }
  }

  void reiniciar() {
    _runId++;
    _timer?.cancel();
    _timer = null;
    _resetState();
    status   = OptStatus.idle;
    errorMsg = null;
    notifyListeners();
  }

  void _resetState() {
    historial.clear();
    horarioFinal.clear();
    topIndividuos.clear();
    conflictosDetalle.clear();
    mejorFitness     = 0;
    conflictos       = 0;
    generacionActual = 0;
    razonParada      = '';
    errorMsg         = null;
    _elapsedSec      = 0;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
