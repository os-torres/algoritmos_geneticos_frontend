import 'asignacion.dart';

// ── Un individuo del top-3 de la población ────────────────────────────────────
class IndividuoTop {
  final int rank;
  final double fitness;
  final int conflictos;
  final List<Asignacion> horario;

  const IndividuoTop({
    required this.rank,
    required this.fitness,
    required this.conflictos,
    required this.horario,
  });

  factory IndividuoTop.fromJson(Map<String, dynamic> j) => IndividuoTop(
        rank:       j['rank'] as int,
        fitness:    (j['fitness'] as num).toDouble(),
        conflictos: j['conflictos'] as int,
        horario:    (j['horario'] as List)
            .map((e) => Asignacion.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

// ── Detalle de un conflicto individual ───────────────────────────────────────
class ConflictoDetalle {
  final String tipo;         // "profesor" | "grupo" | "materia_mismo_dia"
  final String dia;
  final Map<String, dynamic> datos;   // campos específicos según tipo

  const ConflictoDetalle({
    required this.tipo,
    required this.dia,
    required this.datos,
  });

  factory ConflictoDetalle.fromJson(Map<String, dynamic> j) => ConflictoDetalle(
        tipo:  j['tipo'] as String,
        dia:   j['dia'] as String,
        datos: Map<String, dynamic>.from(j),
      );

  // Texto principal legible según el tipo de conflicto
  String get titulo {
    switch (tipo) {
      case 'profesor':
        return 'Docente con doble clase — ${datos['profesor']}';
      case 'grupo':
        return 'Grupo ${datos['grupo']} sem.${datos['semestre']} con doble clase';
      case 'materia_mismo_dia':
        return '${datos['materia']} (Gr. ${datos['grupo']}) repetida el mismo día';
      case 'horario_invalido':
        return '${datos['materia']} (Gr.${datos['grupo']}) fuera de jornada';
      default:
        return 'Conflicto desconocido';
    }
  }

  String get subtitulo {
    switch (tipo) {
      case 'profesor':
      case 'grupo':
        final a = datos['sesion_a'] as Map;
        final b = datos['sesion_b'] as Map;
        return '$dia  ${datos['hora_solapamiento']}  •  '
            '${a['materia']} vs ${b['materia']}';
      case 'materia_mismo_dia':
        final sesiones = (datos['sesiones'] as List);
        final horas = sesiones.map((s) => s['hora_inicio']).join(' y ');
        return '$dia  •  Sesiones a las $horas';
      case 'horario_invalido':
        return '$dia  ${datos['hora_inicio']}–${datos['hora_fin']}  •  '
            '${datos['razon']}';
      default:
        return dia;
    }
  }

  /// Sugerencia práctica para resolver este conflicto.
  String get sugerencia {
    switch (tipo) {
      case 'profesor':
        final prof = datos['profesor'] as String? ?? 'el docente';
        final matA = (datos['sesion_a'] as Map?)?['materia'] ?? '';
        final matB = (datos['sesion_b'] as Map?)?['materia'] ?? '';
        if (matA == matB) {
          // Mismo curso, distintos grupos → el AG debe separarlos
          return 'El docente enseña "$matA" a dos grupos al mismo tiempo. '
              'Aumenta las generaciones/población para que el GA los separe, '
              'o asigna un segundo docente a uno de los grupos en '
              'Datos → Profesores.';
        }
        return '"$prof" tiene dos materias distintas a la misma hora. '
            'Asigna otro docente a "$matB" en Datos → Profesores, '
            'o aumenta generaciones/población para mejorar la convergencia.';

      case 'grupo':
        return 'El grupo tiene dos clases simultáneas. '
            'Puede deberse a pocas ranuras disponibles: agrega un salón '
            'en Datos → Salones (más salones = más ranuras = más opciones), '
            'o aumenta las generaciones para que el GA encuentre mejor distribución.';

      case 'materia_mismo_dia':
        final mat = datos['materia'] as String? ?? 'la materia';
        return '"$mat" tiene dos sesiones programadas el mismo día. '
            'El GA debería evitarlo; si persiste, '
            'aumenta la población y el número de generaciones.';

      case 'horario_invalido':
        final razon = datos['razon'] as String? ?? '';
        if (razon.contains('almuerzo')) {
          return 'Una sesión de 3h se asignó a las 10:00 (terminaría a las 13:00, '
              'cruzando el almuerzo). '
              'El GA debería evitarlo con la penalización activa; '
              'si persiste, aumenta las generaciones para que converja mejor.';
        }
        return 'Una sesión de 3h se asignó a las 16:00 (terminaría después de las 18:00). '
            'Aumenta generaciones/población para que el GA use los slots '
            'válidos para sesiones de 3h (06:00–09:00 mañana, 14:00–15:00 tarde).';

      default:
        return 'Revisa la configuración en la pestaña Datos '
            'e intenta optimizar de nuevo con más generaciones.';
    }
  }
}

// ── Resultado de una generación completa ──────────────────────────────────────
class ResultadoGeneracion {
  final int numero;
  final double mejorFitness;
  final double promedioFitness;
  final double peorFitness;
  final int conflictos;
  final List<Asignacion> mejorHorario;
  final List<IndividuoTop> topIndividuos;
  final List<ConflictoDetalle> conflictosDetalle;

  const ResultadoGeneracion({
    required this.numero,
    required this.mejorFitness,
    required this.promedioFitness,
    required this.peorFitness,
    required this.conflictos,
    required this.mejorHorario,
    required this.topIndividuos,
    this.conflictosDetalle = const [],
  });

  factory ResultadoGeneracion.fromJson(Map<String, dynamic> j) =>
      ResultadoGeneracion(
        numero:          j['numero'] as int,
        mejorFitness:    (j['mejor_fitness'] as num).toDouble(),
        promedioFitness: (j['promedio_fitness'] as num).toDouble(),
        peorFitness:     (j['peor_fitness'] as num).toDouble(),
        conflictos:      j['conflictos_mejor'] as int,
        mejorHorario: (j['mejor_horario'] as List)
            .map((e) => Asignacion.fromJson(e as Map<String, dynamic>))
            .toList(),
        topIndividuos: (j['top_individuos'] as List? ?? [])
            .map((e) => IndividuoTop.fromJson(e as Map<String, dynamic>))
            .toList(),
        conflictosDetalle: (j['conflictos_detalle'] as List? ?? [])
            .map((e) => ConflictoDetalle.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
