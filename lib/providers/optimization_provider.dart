import 'dart:async';
import 'package:flutter/material.dart';
import '../models/resultado_generacion.dart';
import '../models/asignacion.dart';
import '../services/api_service.dart';
// ignore: unused_import — ConflictoDetalle se usa en conflictosDetalle
export '../models/resultado_generacion.dart' show ConflictoDetalle;

/// Intervalo entre consultas de estado al servidor (polling).
const _kPollInterval = Duration(seconds: 3);

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
  double  mejorFitness          = 0;
  int     conflictos            = 0;
  int     generacionActual      = 0;
  int     numGeneracionesTotal  = 0;  // de la respuesta del servidor
  String  razonParada           = '';

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

  // ── Flujo asíncrono: POST /api/optimizar → job_id → polling ──────────────

  Future<void> _runREST(int myRunId) async {
    try {
      // 1. Iniciar el job; el servidor responde en <1 s con {job_id, estado}
      final jobResp = await ApiService().iniciarOptimizacion({
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

      if (myRunId != _runId) return;

      final jobId = jobResp['job_id'] as String?;
      if (jobId == null || jobId.isEmpty) {
        throw const ApiException('El servidor no devolvió un job_id válido.');
      }
      // 2. Polling hasta completado o error
      await _pollEstado(myRunId, jobId);

    } on TimeoutException {
      if (myRunId != _runId) return;
      errorMsg = 'Tiempo de espera agotado al iniciar la optimización. '
          'Verifica la conexión con el servidor.';
      status = OptStatus.error;
    } catch (e) {
      if (myRunId != _runId) return;
      errorMsg = e.toString();
      status = OptStatus.error;
    } finally {
      if (myRunId == _runId) {
        _timer?.cancel();
        _timer = null;
        notifyListeners();
      }
    }
  }

  /// Consulta el estado del job cada [_kPollInterval] hasta completado/error.
  Future<void> _pollEstado(int myRunId, String jobId) async {
    while (myRunId == _runId) {
      await Future.delayed(_kPollInterval);
      if (myRunId != _runId) return;

      try {
        final estado = await ApiService().estadoOptimizacion(jobId);
        if (myRunId != _runId) return;

        // Actualizar progreso en tiempo real (visible en la UI)
        final genAct = estado['generacion_actual'] as int? ?? 0;
        final fitAct = (estado['fitness_actual'] as num? ?? 0).toDouble();
        final confAct = estado['conflictos_actual'] as int? ?? 0;
        final numGen  = estado['num_generaciones'] as int? ?? _numGeneraciones;

        if (genAct > 0 || fitAct > 0) {
          generacionActual     = genAct;
          mejorFitness         = fitAct;
          conflictos           = confAct;
          numGeneracionesTotal = numGen;
          notifyListeners();
        }

        final estadoStr = estado['estado'] as String? ?? '';

        if (estadoStr == 'completado') {
          final result = estado['resultado'] as Map<String, dynamic>?;
          if (result == null) {
            errorMsg = 'El servidor indicó éxito pero el resultado está vacío.';
            status = OptStatus.error;
          } else {
            _procesarResultado(result);
            status = OptStatus.done;
          }
          return;

        } else if (estadoStr == 'error') {
          errorMsg = estado['error'] as String? ?? 'Error en el servidor.';
          status = OptStatus.error;
          return;
        }
        // 'en_progreso' → continuar polling

      } on ApiException catch (e) {
        if (myRunId != _runId) return;
        errorMsg = e.message;
        status = OptStatus.error;
        return;
      } catch (_) {
        // Error de red transitorio — seguir intentando
        if (myRunId != _runId) return;
      }
    }
  }

  /// Parsea el objeto `resultado` del endpoint de estado y rellena los campos del provider.
  void _procesarResultado(Map<String, dynamic> result) {
    final rawHistorial = result['historial'] as List? ?? [];
    historial.addAll(rawHistorial.map(
      (e) => ResultadoGeneracion.fromHistorialItem(e as Map<String, dynamic>),
    ));

    generacionActual     = result['generaciones_ejecutadas'] as int? ?? generacionActual;
    mejorFitness         = (result['mejor_fitness'] as num? ?? mejorFitness).toDouble();
    conflictos           = result['conflictos_finales'] as int? ?? conflictos;
    razonParada          = result['razon_parada'] as String? ?? '';

    final rawHorario = result['mejor_horario'] as List? ?? [];
    horarioFinal = rawHorario
        .map((e) => Asignacion.fromJson(e as Map<String, dynamic>))
        .toList();

    final rawConflictos = result['conflictos_detalle'] as List? ?? [];
    conflictosDetalle = rawConflictos
        .map((e) => ConflictoDetalle.fromJson(e as Map<String, dynamic>))
        .toList();

    final rawTop = result['top_individuos'] as List? ?? [];
    topIndividuos = rawTop
        .map((e) => IndividuoTop.fromJson(e as Map<String, dynamic>))
        .toList();
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
    mejorFitness         = 0;
    conflictos           = 0;
    generacionActual     = 0;
    numGeneracionesTotal = 0;
    razonParada          = '';
    errorMsg             = null;
    _elapsedSec          = 0;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
