import 'package:flutter/material.dart';
import '../models/resultado_generacion.dart';
import '../models/asignacion.dart';
import '../services/websocket_service.dart';
// ignore: unused_import — ConflictoDetalle se usa en conflictosDetalle
export '../models/resultado_generacion.dart' show ConflictoDetalle;

enum OptStatus { idle, running, done, error }

class OptimizationProvider extends ChangeNotifier {
  final _ws = WebSocketService();

  OptStatus status = OptStatus.idle;
  String? errorMsg;

  // Parámetros del AG — setters que notifican al listener para reflejar
  // el cambio visualmente en tiempo real mientras se mueve el slider.
  int    _tamPoblacion    = 100;
  int    _numGeneraciones = 200;
  double _probCruz        = 0.85;
  double _probMut         = 0.10;
  int    _numElite        = 2;
  int    _tamTorneo       = 5;
  int    _paciencia       = 30;
  // Lista de semestres seleccionados; vacía = todos los semestres
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

  /// Reemplaza la selección de semestres completa.
  set semestresFiltro(List<int> v) {
    _semestresFiltro = List.of(v);
    notifyListeners();
  }

  /// Activa o desactiva un semestre individual (toggle).
  void toggleSemestre(int s) {
    if (_semestresFiltro.contains(s)) {
      _semestresFiltro.remove(s);
    } else {
      _semestresFiltro.add(s);
      _semestresFiltro.sort();
    }
    notifyListeners();
  }

  /// Limpia el filtro (= todos los semestres).
  void limpiarSemestres() {
    _semestresFiltro.clear();
    notifyListeners();
  }

  // Historial de generaciones (para la gráfica)
  final List<ResultadoGeneracion> historial = [];

  // Horario final y población
  List<Asignacion>        horarioFinal        = [];
  List<IndividuoTop>      topIndividuos       = [];   // Top-3 de la generación actual
  List<ConflictoDetalle>  conflictosDetalle   = [];   // Detalle de conflictos del mejor
  double mejorFitness  = 0;
  int conflictos       = 0;
  int generacionActual = 0;
  /// Razón por la que terminó el AG (vacío mientras corre)
  String razonParada   = "";

  void iniciar() {
    historial.clear();
    horarioFinal.clear();
    topIndividuos.clear();
    conflictosDetalle.clear();
    mejorFitness  = 0;
    conflictos    = 0;
    generacionActual = 0;
    razonParada   = "";
    errorMsg = null;
    status   = OptStatus.running;
    notifyListeners();

    _ws.connect(
      params: {
        'tam_poblacion':    tamPoblacion,
        'num_generaciones': numGeneraciones,
        'prob_cruzamiento': probCruz,
        'prob_mutacion':    probMut,
        'num_elite':        numElite,
        'tam_torneo':       tamTorneo,
        'paciencia':        paciencia,
        if (_semestresFiltro.isNotEmpty)
          'semestres_filtro': _semestresFiltro,
      },
      onGeneration: (gen) {
        historial.add(gen);
        generacionActual = gen.numero;
        mejorFitness     = gen.mejorFitness;
        conflictos       = gen.conflictos;
        horarioFinal     = gen.mejorHorario;
        topIndividuos    = gen.topIndividuos;
        if (gen.conflictosDetalle.isNotEmpty) {
          conflictosDetalle = gen.conflictosDetalle;
        }
        notifyListeners();
      },
      onDone: (final_) {
        horarioFinal      = final_.mejorHorario;
        mejorFitness      = final_.mejorFitness;
        conflictos        = final_.conflictos;
        topIndividuos     = final_.topIndividuos;
        conflictosDetalle = final_.conflictosDetalle;
        razonParada       = final_.razonParada;
        status            = OptStatus.done;
        notifyListeners();
      },
      onError: (msg) {
        errorMsg = msg;
        status   = OptStatus.error;
        notifyListeners();
      },
    );
  }

  void detener() {
    _ws.disconnect();
    if (status == OptStatus.running) {
      status = OptStatus.idle;
      notifyListeners();
    }
  }

  void reiniciar() {
    detener();
    historial.clear();
    horarioFinal.clear();
    topIndividuos.clear();
    conflictosDetalle.clear();
    mejorFitness  = 0;
    conflictos    = 0;
    generacionActual = 0;
    razonParada   = "";
    errorMsg = null;
    status   = OptStatus.idle;
    notifyListeners();
  }

  @override
  void dispose() {
    _ws.disconnect();
    super.dispose();
  }
}
