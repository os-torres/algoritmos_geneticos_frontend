import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/resultado_generacion.dart';
import '../providers/data_provider.dart';
import '../providers/optimization_provider.dart';
import '../widgets/fitness_chart.dart';
import '../widgets/schedule_grid.dart';
// ignore: unused_import
export '../models/resultado_generacion.dart' show ConflictoDetalle;

class OptimizationScreen extends StatelessWidget {
  const OptimizationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final opt = context.watch<OptimizationProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Algoritmo Genético'),
        actions: [
          if (opt.status == OptStatus.running)
            IconButton(
                icon: const Icon(Icons.stop_circle_outlined),
                tooltip: 'Detener',
                onPressed: opt.detener),
          if (opt.status != OptStatus.idle)
            IconButton(
                icon: const Icon(Icons.refresh),
                tooltip: 'Reiniciar',
                onPressed: opt.reiniciar),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── 1. Parámetros ──────────────────────────────────────────
          _ParamsCard(opt: opt),
          const SizedBox(height: 16),

          // ── 2. Barra de progreso ────────────────────────────────────
          if (opt.status != OptStatus.idle) ...[
            _ProgressCard(opt: opt),
            const SizedBox(height: 16),

            // ── 2b. Detalle de conflictos (solo si hay) ─────────────
            if (opt.conflictos > 0 &&
                opt.conflictosDetalle.isNotEmpty) ...[
              _ConflictosCard(conflictos: opt.conflictosDetalle),
              const SizedBox(height: 16),
            ],

            // ── 3. Gráfica de convergencia ──────────────────────────
            _ChartCard(opt: opt),
            const SizedBox(height: 16),

            // ── 4. Población actual (top-3) ─────────────────────────
            if (opt.topIndividuos.isNotEmpty) ...[
              _TopIndividuosCard(
                individuos: opt.topIndividuos,
                generacion: opt.generacionActual,
              ),
              const SizedBox(height: 16),
            ],

            // ── 5. Mejor horario actual ─────────────────────────────
            if (opt.horarioFinal.isNotEmpty) ...[
              _SectionTitle(
                  '📅 Mejor horario — Gen. ${opt.generacionActual}',
                  subtitle: 'Fitness: ${opt.mejorFitness.toStringAsFixed(0)}  '
                      '·  Conflictos: ${opt.conflictos}'),
              const SizedBox(height: 8),
              ScheduleGrid(horario: opt.horarioFinal),
              const SizedBox(height: 16),
            ],
          ],

          // ── Error ───────────────────────────────────────────────────
          if (opt.status == OptStatus.error)
            Card(
              color: Theme.of(context).colorScheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(children: [
                  const Icon(Icons.error_outline),
                  const SizedBox(width: 8),
                  Expanded(
                      child: Text(opt.errorMsg ?? 'Error desconocido')),
                ]),
              ),
            ),

          const SizedBox(height: 80), // espacio para el FAB
        ],
      ),
      floatingActionButton: opt.status == OptStatus.running
          ? null
          : FloatingActionButton.extended(
              icon: const Icon(Icons.play_arrow),
              label: const Text('Iniciar algoritmo'),
              onPressed: () => _validarEIniciar(context, opt),
            ),
    );
  }

  // ── Validación de datos antes de correr el GA ──────────────────────────────

  void _validarEIniciar(BuildContext context, OptimizationProvider opt) {
    final dp = context.read<DataProvider>();

    // 1. ¿Hay materias?
    if (dp.materias.isEmpty) {
      _mostrarAdvertencia(
        context,
        'No hay materias configuradas.\n\n'
        'Ve a la pestaña "Datos" y agrega al menos una materia.',
      );
      return;
    }

    // 2. ¿Hay franjas horarias?
    if (dp.franjas.isEmpty) {
      _mostrarAdvertencia(
        context,
        'No hay franjas horarias configuradas.\n\n'
        'Ve a la pestaña "Datos → Franjas" y agrega los horarios disponibles.',
      );
      return;
    }

    // 3. ¿Hay salones?
    if (dp.salones.isEmpty) {
      _mostrarAdvertencia(
        context,
        'No hay salones configurados.\n\n'
        'Ve a la pestaña "Datos → Salones" y agrega al menos un salón.',
      );
      return;
    }

    // 4. Materias a considerar (según filtro de semestres)
    //
    // Primero limpiar automáticamente cualquier semestre que ya no exista
    // en los datos actuales (p.ej. después de restaurar los predeterminados).
    // Esto evita el error cuando el usuario restaura datos pero el filtro
    // todavía tiene semestres de una carga anterior.
    final disponibles = dp.semestresDisponibles;
    final filtroValido = opt.semestresFiltro
        .where((s) => disponibles.contains(s))
        .toList();
    if (filtroValido.length != opt.semestresFiltro.length) {
      // Hay semestres obsoletos → limpiar sin mostrar error
      opt.semestresFiltro = filtroValido;
    }

    final filtro = filtroValido;
    final materiasActivas = filtro.isEmpty
        ? dp.materias
        : dp.materias
            .where((m) => filtro.contains(m.semestre))
            .toList();

    if (materiasActivas.isEmpty) {
      // Solo llega aquí si los datos están realmente vacíos
      _mostrarAdvertencia(
        context,
        'No hay materias configuradas para los semestres disponibles.\n\n'
        'Ve a la pestaña "Datos" e importa el pensum o agrega materias.',
      );
      return;
    }

    // 5. ¿Todas las materias activas tienen docente?
    final sinProfesor = materiasActivas
        .where((m) =>
            !dp.profesores.any((p) => p.materiasIds.contains(m.id)))
        .toList();

    if (sinProfesor.isNotEmpty) {
      final lista = sinProfesor
          .take(5)
          .map((m) => '• ${m.nombre} (Grupo ${m.grupo})')
          .join('\n');
      final extra = sinProfesor.length > 5
          ? '\n• … y ${sinProfesor.length - 5} más'
          : '';
      _mostrarAdvertencia(
        context,
        'Las siguientes materias no tienen docente asignado:\n\n'
        '$lista$extra\n\n'
        'Ve a "Datos → Profesores", edita el docente correspondiente '
        'y selecciona la(s) materia(s) que dicta.',
      );
      return;
    }

    // 6. ¿Suficientes ranuras?
    final totalSesiones = materiasActivas
        .fold<int>(0, (s, m) => s + m.bloques.length);
    final ranuras = dp.franjas.length * dp.salones.length;
    if (ranuras < totalSesiones) {
      _mostrarAdvertencia(
        context,
        'No hay suficientes ranuras ($ranuras) para las sesiones '
        '($totalSesiones).\n\n'
        'Agrega más salones o franjas horarias en la pestaña "Datos".',
      );
      return;
    }

    // Todo OK → iniciar
    opt.iniciar();
  }

  void _mostrarAdvertencia(BuildContext context, String mensaje) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        icon: const Icon(Icons.warning_amber_rounded,
            color: Colors.orange, size: 36),
        title: const Text('Datos incompletos'),
        content: Text(mensaje),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Parámetros
// ─────────────────────────────────────────────────────────────────────────────

class _ParamsCard extends StatelessWidget {
  final OptimizationProvider opt;
  const _ParamsCard({required this.opt});

  @override
  Widget build(BuildContext context) {
    final running = opt.status == OptStatus.running;

    // Semestres disponibles (del DataProvider)
    final semestres = context.watch<DataProvider>().semestresDisponibles;

    // ── Auto-limpiar semestres obsoletos ────────────────────────────────────
    // Cuando el DataProvider cambia (p.ej. restaurar datos, importar pensum),
    // puede que el filtro tenga semestres que ya no existen.
    // Se limpia vía post-frame para no llamar a setState() durante build.
    final selActual = opt.semestresFiltro;
    if (selActual.any((s) => !semestres.contains(s))) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.read<OptimizationProvider>().semestresFiltro =
            selActual.where((s) => semestres.contains(s)).toList();
      });
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Parámetros del algoritmo',
                style: Theme.of(context).textTheme.titleMedium!
                    .copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),

            // ── Filtro de semestres (multi-selección) ─────────────────────
            if (semestres.length > 1) ...[
              Row(children: [
                const Icon(Icons.filter_list, size: 18),
                const SizedBox(width: 6),
                const Text('Semestres a optimizar:',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                const Spacer(),
                if (opt.semestresFiltro.isNotEmpty)
                  TextButton.icon(
                    onPressed: running
                        ? null
                        : () => context
                            .read<OptimizationProvider>()
                            .limpiarSemestres(),
                    icon: const Icon(Icons.clear, size: 14),
                    label: const Text('Todos', style: TextStyle(fontSize: 12)),
                    style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                  ),
              ]),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: semestres.map((s) {
                  final selected = opt.semestresFiltro.isEmpty ||
                      opt.semestresFiltro.contains(s);
                  final active = opt.semestresFiltro.contains(s);
                  return FilterChip(
                    label: Text('Sem $s'),
                    selected: active,
                    showCheckmark: true,
                    onSelected: running
                        ? null
                        : (checked) {
                            final optP =
                                context.read<OptimizationProvider>();
                            optP.toggleSemestre(s);
                            _aplicarPresetSegunSeleccion(
                                context, optP, optP.semestresFiltro);
                          },
                    selectedColor: Theme.of(context)
                        .colorScheme
                        .primaryContainer,
                    labelStyle: TextStyle(
                      fontSize: 12,
                      fontWeight: active
                          ? FontWeight.bold
                          : FontWeight.normal,
                      color: running
                          ? Theme.of(context).disabledColor
                          : selected
                              ? Theme.of(context).colorScheme.onSurface
                              : Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 6),
              // Indicador informativo
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: opt.semestresFiltro.isEmpty
                      ? Colors.amber.shade50
                      : Colors.green.shade50,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: opt.semestresFiltro.isEmpty
                        ? Colors.amber.shade300
                        : Colors.green.shade300,
                  ),
                ),
                child: Row(children: [
                  Icon(
                    opt.semestresFiltro.isEmpty
                        ? Icons.info_outline
                        : Icons.check_circle_outline,
                    size: 15,
                    color: opt.semestresFiltro.isEmpty
                        ? Colors.amber.shade800
                        : Colors.green.shade700,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      opt.semestresFiltro.isEmpty
                          ? 'Se optimizarán todos los semestres. '
                              'Usa "Pensum Completo" o selecciona semestres específicos.'
                          : 'Optimizando ${opt.semestresFiltro.length} semestre(s): '
                              '${opt.semestresFiltro.map((s) => "Sem $s").join(", ")}.',
                      style: TextStyle(
                          fontSize: 11,
                          color: opt.semestresFiltro.isEmpty
                              ? Colors.amber.shade900
                              : Colors.green.shade800),
                    ),
                  ),
                ]),
              ),
              const Divider(height: 20),
            ],

            // ── Presets de parámetros ───────────────────────────────────────
            _PresetBar(opt: opt, running: running),
            const SizedBox(height: 4),

            _SliderRow(
              label: 'Población',
              value: opt.tamPoblacion.toDouble(),
              min: 20, max: 300, divisions: 28,
              display: '${opt.tamPoblacion}',
              disabled: running,
              onChanged: (v) =>
                  context.read<OptimizationProvider>().tamPoblacion = v.toInt(),
            ),
            _SliderRow(
              label: 'Generaciones',
              value: opt.numGeneraciones.toDouble(),
              min: 50, max: 500, divisions: 45,
              display: '${opt.numGeneraciones}',
              disabled: running,
              onChanged: (v) =>
                  context.read<OptimizationProvider>().numGeneraciones =
                      v.toInt(),
            ),
            _SliderRow(
              label: 'P. Cruzamiento',
              value: opt.probCruz,
              min: 0.3, max: 1.0, divisions: 14,
              display: opt.probCruz.toStringAsFixed(2),
              disabled: running,
              onChanged: (v) =>
                  context.read<OptimizationProvider>().probCruz = v,
            ),
            _SliderRow(
              label: 'P. Mutación',
              value: opt.probMut,
              min: 0.01, max: 0.5, divisions: 49,
              display: opt.probMut.toStringAsFixed(2),
              disabled: running,
              onChanged: (v) =>
                  context.read<OptimizationProvider>().probMut = v,
            ),
            _SliderRow(
              label: 'Élite',
              value: opt.numElite.toDouble(),
              min: 0, max: 10, divisions: 10,
              display: '${opt.numElite}',
              disabled: running,
              onChanged: (v) =>
                  context.read<OptimizationProvider>().numElite = v.toInt(),
            ),
            _SliderRow(
              label: 'Paciencia',
              value: opt.paciencia.toDouble(),
              min: 5, max: 100, divisions: 19,
              display: '${opt.paciencia}',
              disabled: running,
              onChanged: (v) =>
                  context.read<OptimizationProvider>().paciencia = v.toInt(),
            ),
          ],
        ),
      ),
    );
  }

  /// Aplica presets de parámetros según los semestres seleccionados.
  static void _aplicarPresetSegunSeleccion(
      BuildContext ctx, OptimizationProvider opt, List<int> seleccion) {
    final n = seleccion.length;
    if (n == 0) {
      // Todo el pensum: necesita más potencia
      opt.tamPoblacion    = 200;
      opt.numGeneraciones = 500;
      opt.probCruz        = 0.90;
      opt.probMut         = 0.15;
      opt.numElite        = 5;
      opt.paciencia       = 50;
    } else if (n == 1) {
      // 1 semestre: rápido y preciso
      opt.tamPoblacion    = 60;
      opt.numGeneraciones = 150;
      opt.probCruz        = 0.85;
      opt.probMut         = 0.10;
      opt.numElite        = 3;
      opt.paciencia       = 20;
    } else if (n <= 4) {
      // 2–4 semestres: balanceado
      opt.tamPoblacion    = 100;
      opt.numGeneraciones = 250;
      opt.probCruz        = 0.85;
      opt.probMut         = 0.12;
      opt.numElite        = 4;
      opt.paciencia       = 30;
    } else {
      // 5+ semestres: casi pensum completo
      opt.tamPoblacion    = 200;
      opt.numGeneraciones = 500;
      opt.probCruz        = 0.90;
      opt.probMut         = 0.15;
      opt.numElite        = 5;
      opt.paciencia       = 50;
    }
  }
}

// ── Barra de presets ──────────────────────────────────────────────────────────

class _PresetBar extends StatelessWidget {
  final OptimizationProvider opt;
  final bool running;
  const _PresetBar({required this.opt, required this.running});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          const Text('Presets rápidos:',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(width: 4),
          Tooltip(
            message: 'Los presets ajustan todos los parámetros automáticamente\n'
                'según la complejidad del problema.\n'
                'Puedes ajustarlos manualmente después.',
            child: Icon(Icons.help_outline,
                size: 15, color: Colors.grey.shade500),
          ),
        ]),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 4,
          children: [
            _PresetChip(
              icon: '⚡',
              label: '1 Semestre',
              sublabel: 'Pob:60  Gen:150  Pac:20',
              color: Colors.green,
              disabled: running,
              onTap: () {
                context.read<OptimizationProvider>()
                  ..tamPoblacion    = 60
                  ..numGeneraciones = 150
                  ..probCruz        = 0.85
                  ..probMut         = 0.10
                  ..numElite        = 3
                  ..paciencia       = 20;
              },
            ),
            _PresetChip(
              icon: '⚖️',
              label: '2–4 Semestres',
              sublabel: 'Pob:100  Gen:250  Pac:30',
              color: Colors.blue,
              disabled: running,
              onTap: () {
                context.read<OptimizationProvider>()
                  ..tamPoblacion    = 100
                  ..numGeneraciones = 250
                  ..probCruz        = 0.85
                  ..probMut         = 0.12
                  ..numElite        = 4
                  ..paciencia       = 30;
              },
            ),
            _PresetChip(
              icon: '🔬',
              label: 'Pensum Completo',
              sublabel: 'Pob:200  Gen:500  Pac:50',
              color: Colors.purple,
              disabled: running,
              onTap: () {
                context.read<OptimizationProvider>()
                  ..tamPoblacion    = 200
                  ..numGeneraciones = 500
                  ..probCruz        = 0.90
                  ..probMut         = 0.15
                  ..numElite        = 5
                  ..paciencia       = 50;
              },
            ),
          ],
        ),
      ],
    );
  }
}

class _PresetChip extends StatelessWidget {
  final String icon, label, sublabel;
  final Color color;
  final bool disabled;
  final VoidCallback onTap;

  const _PresetChip({
    required this.icon,
    required this.label,
    required this.sublabel,
    required this.color,
    required this.disabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: disabled ? null : onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: disabled ? Colors.grey.shade100 : color.withAlpha(20),
          border: Border.all(
            color: disabled ? Colors.grey.shade300 : color.withAlpha(100),
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$icon $label',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: disabled ? Colors.grey : color.withAlpha(220))),
            Text(sublabel,
                style: TextStyle(
                    fontSize: 10,
                    color: disabled
                        ? Colors.grey.shade400
                        : color.withAlpha(180))),
          ],
        ),
      ),
    );
  }
}

class _SliderRow extends StatefulWidget {
  final String label, display;
  final double value, min, max;
  final int divisions;
  final bool disabled;
  final ValueChanged<double> onChanged;

  const _SliderRow({
    required this.label, required this.value, required this.min,
    required this.max, required this.divisions, required this.display,
    required this.disabled, required this.onChanged,
  });

  @override
  State<_SliderRow> createState() => _SliderRowState();
}

class _SliderRowState extends State<_SliderRow> {
  late double _localValue;

  @override
  void initState() {
    super.initState();
    _localValue = widget.value;
  }

  @override
  void didUpdateWidget(_SliderRow old) {
    super.didUpdateWidget(old);
    // Sincronizar si el valor externo cambia por otro motivo (ej. reiniciar)
    if (old.value != widget.value) {
      _localValue = widget.value;
    }
  }

  @override
  Widget build(BuildContext context) => Row(
        children: [
          SizedBox(
              width: 112,
              child: Text(widget.label, style: const TextStyle(fontSize: 13))),
          Expanded(
            child: Slider(
              value: _localValue,
              min: widget.min, max: widget.max, divisions: widget.divisions,
              onChanged: widget.disabled
                  ? null
                  : (v) {
                      setState(() => _localValue = v); // visual inmediato
                      widget.onChanged(v);             // actualiza provider
                    },
            ),
          ),
          SizedBox(
            width: 44,
            child: Text(widget.display,
                textAlign: TextAlign.right,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600)),
          ),
        ],
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Progreso
// ─────────────────────────────────────────────────────────────────────────────

class _ProgressCard extends StatelessWidget {
  final OptimizationProvider opt;
  const _ProgressCard({required this.opt});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final progress = opt.numGeneraciones > 0
        ? (opt.generacionActual / opt.numGeneraciones).clamp(0.0, 1.0)
        : 0.0;

    return Card(
      color: cs.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
            _StatPill(label: 'Generación',
                value: '${opt.generacionActual}/${opt.numGeneraciones}'),
            _StatPill(label: 'Mejor fitness',
                value: opt.mejorFitness.toStringAsFixed(0)),
            _StatPill(
              label: 'Conflictos',
              value: '${opt.conflictos}',
              valueColor: opt.conflictos == 0 ? Colors.green : cs.error,
            ),
          ]),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: opt.status == OptStatus.done ? 1.0 : progress,
              minHeight: 8,
            ),
          ),
          if (opt.status == OptStatus.done) ...[
            const SizedBox(height: 8),
            _StopReasonBanner(razon: opt.razonParada),
          ],
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Banner de razón de parada
// ─────────────────────────────────────────────────────────────────────────────

class _StopReasonBanner extends StatelessWidget {
  final String razon;
  const _StopReasonBanner({required this.razon});

  @override
  Widget build(BuildContext context) {
    final (icon, color, texto) = switch (razon) {
      'optimo_encontrado' => (
          Icons.check_circle,
          Colors.green,
          '¡Solución óptima encontrada! El horario no tiene conflictos.',
        ),
      'estancamiento' => (
          Icons.pause_circle_outline,
          Colors.orange,
          'Parada por estancamiento: el fitness no mejoró en las últimas generaciones configuradas.',
        ),
      _ => (
          Icons.check_circle_outline,
          Colors.blue,
          '¡Optimización completada! Se ejecutaron todas las generaciones.',
        ),
    };

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            texto,
            style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 13),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}

class _StatPill extends StatelessWidget {
  final String label, value;
  final Color? valueColor;
  const _StatPill({required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) => Column(children: [
        Text(value,
            style: TextStyle(
                fontWeight: FontWeight.bold, fontSize: 20, color: valueColor)),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ]);
}

// ─────────────────────────────────────────────────────────────────────────────
// Gráfica de convergencia
// ─────────────────────────────────────────────────────────────────────────────

class _ChartCard extends StatelessWidget {
  final OptimizationProvider opt;
  const _ChartCard({required this.opt});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Convergencia del fitness',
                style: Theme.of(context).textTheme.titleMedium!
                    .copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Row(children: [
              _LegendDot(color: cs.primary, label: 'Mejor'),
              const SizedBox(width: 16),
              _LegendDot(color: cs.tertiary, label: 'Promedio', dashed: true),
            ]),
            const SizedBox(height: 14),
            SizedBox(
              height: 220,
              child: opt.historial.isEmpty
                  ? const Center(child: Text('Esperando datos…'))
                  : FitnessChart(historial: opt.historial),
            ),
            const SizedBox(height: 8),
            // Eje X label
            Center(
              child: Text('Generación →',
                  style: TextStyle(
                      fontSize: 11, color: cs.outline)),
            ),
          ],
        ),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  final bool dashed;
  const _LegendDot(
      {required this.color, required this.label, this.dashed = false});

  @override
  Widget build(BuildContext context) => Row(children: [
        Container(
          width: 20, height: 3,
          color: dashed ? Colors.transparent : color,
          child: dashed
              ? Row(children: List.generate(
                  4,
                  (i) => Expanded(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 1),
                      color: color,
                    ),
                  )))
              : null,
        ),
        const SizedBox(width: 5),
        Text(label, style: const TextStyle(fontSize: 12)),
      ]);
}

// ─────────────────────────────────────────────────────────────────────────────
// Población actual — top-3 individuos
// ─────────────────────────────────────────────────────────────────────────────

class _TopIndividuosCard extends StatelessWidget {
  final List<IndividuoTop> individuos;
  final int generacion;

  const _TopIndividuosCard({
    required this.individuos,
    required this.generacion,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('👥', style: TextStyle(fontSize: 18)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Población actual — Gen. $generacion',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium!
                        .copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                Text(
                  'Top ${individuos.length}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Los mejores individuos de la generación actual',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
            const SizedBox(height: 12),
            ...individuos.map((ind) => _IndividuoRow(ind: ind)),
          ],
        ),
      ),
    );
  }
}

class _IndividuoRow extends StatelessWidget {
  final IndividuoTop ind;
  const _IndividuoRow({required this.ind});

  static const _medallas = ['🥇', '🥈', '🥉'];
  static const _nombres  = ['Mejor', '2.°', '3.°'];
  static const _colores  = [Color(0xFFFFB300), Color(0xFF78909C), Color(0xFF8D6E63)];

  @override
  Widget build(BuildContext context) {
    final cs     = Theme.of(context).colorScheme;
    final medalla = ind.rank <= 3 ? _medallas[ind.rank - 1] : '#${ind.rank}';
    final nombre  = ind.rank <= 3 ? _nombres[ind.rank - 1]  : 'Ind. ${ind.rank}';
    final color   = ind.rank <= 3 ? _colores[ind.rank - 1]  : cs.outline;

    final sinConflictos = ind.conflictos == 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withAlpha(100), width: 1.5),
        color: color.withAlpha(14),
      ),
      child: Row(
        children: [
          // ── Medalla ──────────────────────────────────────────────
          Text(medalla, style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 10),

          // ── Info ─────────────────────────────────────────────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Fila 1: nombre + badge de conflictos
                Row(
                  children: [
                    Text(
                      nombre,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: color,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: (sinConflictos ? Colors.green : cs.error)
                            .withAlpha(20),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: (sinConflictos ? Colors.green : cs.error)
                              .withAlpha(80),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            sinConflictos
                                ? Icons.check_circle_outline
                                : Icons.warning_amber_outlined,
                            size: 11,
                            color: sinConflictos ? Colors.green : cs.error,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            sinConflictos
                                ? 'Sin conflictos'
                                : '${ind.conflictos} conflictos',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: sinConflictos ? Colors.green : cs.error,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                // Fila 2: fitness + sesiones
                Text(
                  'Fitness ${ind.fitness.toStringAsFixed(0)}'
                  '  ·  ${ind.horario.length} sesiones',
                  style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),

          // ── Botón ────────────────────────────────────────────────
          const SizedBox(width: 4),
          IconButton(
            onPressed: () => _verHorario(context, ind),
            icon: const Icon(Icons.open_in_new, size: 18),
            tooltip: 'Ver horario',
            style: IconButton.styleFrom(
              foregroundColor: color,
              backgroundColor: color.withAlpha(20),
              minimumSize: const Size(36, 36),
              padding: EdgeInsets.zero,
            ),
          ),
        ],
      ),
    );
  }

  void _verHorario(BuildContext context, IndividuoTop ind) {
    final medalla = ind.rank <= 3 ? _medallas[ind.rank - 1] : '#${ind.rank}';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.88,
        builder: (_, ctrl) => Column(
          children: [
            // Encabezado
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Row(
                children: [
                  Text(medalla, style: const TextStyle(fontSize: 24)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Individuo #${ind.rank}',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        Text(
                          'Fitness ${ind.fitness.toStringAsFixed(0)}'
                          ' · Conflictos ${ind.conflictos}',
                          style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context).colorScheme.outline),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // Horario
            Expanded(
              child: SingleChildScrollView(
                controller: ctrl,
                padding: const EdgeInsets.all(16),
                child: ScheduleGrid(horario: ind.horario),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Detalle de conflictos
// ─────────────────────────────────────────────────────────────────────────────

class _ConflictosCard extends StatefulWidget {
  final List<ConflictoDetalle> conflictos;
  const _ConflictosCard({required this.conflictos});

  @override
  State<_ConflictosCard> createState() => _ConflictosCardState();
}

class _ConflictosCardState extends State<_ConflictosCard> {
  bool _expandido = true;

  static const Map<String, IconData> _iconos = {
    'profesor':          Icons.person_off_outlined,
    'grupo':             Icons.group_off_outlined,
    'materia_mismo_dia': Icons.event_busy_outlined,
    'horario_invalido':  Icons.access_time_filled,
  };

  static const Map<String, Color> _colores = {
    'profesor':          Color(0xFFD32F2F), // rojo
    'grupo':             Color(0xFFF57C00), // naranja
    'materia_mismo_dia': Color(0xFF1565C0), // azul
    'horario_invalido':  Color(0xFF6A1B9A), // morado
  };

  static const Map<String, String> _etiquetas = {
    'profesor':          'Docente',
    'grupo':             'Grupo',
    'materia_mismo_dia': 'Misma materia',
    'horario_invalido':  'Fuera de jornada',
  };

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final conteo = <String, int>{};
    for (final c in widget.conflictos) {
      conteo[c.tipo] = (conteo[c.tipo] ?? 0) + 1;
    }

    return Card(
      color: const Color(0xFFFFF3E0),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Fila 1: título + botón colapsar ──────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 1),
                  child: Icon(Icons.warning_amber_rounded,
                      color: Colors.deepOrange, size: 20),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${widget.conflictos.length} conflicto(s) detectado(s) '
                    'en el mejor horario',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
                GestureDetector(
                  onTap: () => setState(() => _expandido = !_expandido),
                  child: Icon(
                    _expandido ? Icons.expand_less : Icons.expand_more,
                    size: 22,
                    color: Colors.orange.shade800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),

            // ── Fila 2: chips de resumen por tipo (Wrap, sin overflow) ─
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: conteo.entries.map((entry) {
                final col = _colores[entry.key] ?? cs.error;
                return Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: col.withAlpha(20),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: col.withAlpha(80)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _iconos[entry.key] ?? Icons.error_outline,
                        size: 11,
                        color: col,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${entry.value} ${_etiquetas[entry.key] ?? entry.key}',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: col,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),

            if (_expandido) ...[
              const SizedBox(height: 8),
              Text(
                'El GA no pudo eliminar todos los conflictos en las '
                'generaciones configuradas. Cada conflicto incluye una '
                'sugerencia para resolverlo.',
                style: TextStyle(
                    fontSize: 11, color: Colors.orange.shade900),
              ),
              const SizedBox(height: 10),
              const Divider(height: 1),
              const SizedBox(height: 8),
              ...widget.conflictos.asMap().entries.map((e) =>
                  _ConflictoItem(
                    idx:       e.key + 1,
                    conflicto: e.value,
                    icono:     _iconos[e.value.tipo] ?? Icons.error_outline,
                    color:     _colores[e.value.tipo] ?? cs.error,
                  )),
            ],
          ],
        ),
      ),
    );
  }
}

class _ConflictoItem extends StatelessWidget {
  final int idx;
  final ConflictoDetalle conflicto;
  final IconData icono;
  final Color color;

  const _ConflictoItem({
    required this.idx,
    required this.conflicto,
    required this.icono,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: color.withAlpha(12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withAlpha(60)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Cabecera: título + subtítulo ──────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Icon(icono, size: 15, color: color),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '#$idx  ${conflicto.titulo}',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: color),
                    ),
                  ),
                ]),
                const SizedBox(height: 3),
                Text(
                  conflicto.subtitulo,
                  style: TextStyle(
                      fontSize: 11,
                      color:
                          Theme.of(context).colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),

          // ── Detalle específico por tipo ───────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: _buildDetalle(context),
          ),

          // ── Sugerencia de solución ────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(120),
              borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(8)),
              border: Border(
                  top: BorderSide(color: color.withAlpha(40))),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.lightbulb_outline,
                    size: 13,
                    color: Colors.amber.shade700),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    conflicto.sugerencia,
                    style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade800,
                        height: 1.4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetalle(BuildContext context) {
    final datos = conflicto.datos;

    switch (conflicto.tipo) {
      case 'profesor':
      case 'grupo':
        final a = datos['sesion_a'] as Map;
        final b = datos['sesion_b'] as Map;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SesionChipRow(
              etiqueta: 'Clase A',
              materia:  a['materia'] as String,
              info:     conflicto.tipo == 'profesor'
                  ? 'Gr.${a['grupo']} · Sem.${a['semestre']}'
                  : (a['profesor'] as String),
              horario:  '${a['hora_inicio']}–${a['hora_fin']}',
              salon:    a['salon'] as String,
              color:    color,
            ),
            const SizedBox(height: 4),
            _SesionChipRow(
              etiqueta: 'Clase B',
              materia:  b['materia'] as String,
              info:     conflicto.tipo == 'profesor'
                  ? 'Gr.${b['grupo']} · Sem.${b['semestre']}'
                  : (b['profesor'] as String),
              horario:  '${b['hora_inicio']}–${b['hora_fin']}',
              salon:    b['salon'] as String,
              color:    color,
            ),
            const SizedBox(height: 4),
            Row(children: [
              const Icon(Icons.schedule, size: 12, color: Colors.grey),
              const SizedBox(width: 4),
              Text(
                'Solapamiento: ${datos['hora_solapamiento']}',
                style: const TextStyle(
                    fontSize: 10, color: Colors.grey),
              ),
            ]),
          ],
        );

      case 'materia_mismo_dia':
        final sesiones = (datos['sesiones'] as List);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Se programaron ${sesiones.length} sesiones de '
              '${datos['materia']} el mismo día (${datos['dia']}):',
              style: const TextStyle(fontSize: 11),
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: sesiones
                  .map((s) => _Chip(
                        text:
                            '${s['hora_inicio']}–${s['hora_fin']}  ${s['salon']}',
                        color: color,
                      ))
                  .toList(),
            ),
          ],
        );

      case 'horario_invalido':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.schedule, size: 13, color: color),
              const SizedBox(width: 4),
              Text(
                '${datos['hora_inicio']}–${datos['hora_fin']}  ·  ${datos['salon']}',
                style: TextStyle(fontSize: 11, color: color),
              ),
            ]),
            const SizedBox(height: 3),
            Row(children: [
              Icon(Icons.warning_outlined, size: 13, color: color),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  datos['razon'] as String,
                  style: const TextStyle(fontSize: 11),
                ),
              ),
            ]),
          ],
        );

      default:
        return const SizedBox.shrink();
    }
  }
}

class _SesionChipRow extends StatelessWidget {
  final String etiqueta, materia, info, horario, salon;
  final Color color;

  const _SesionChipRow({
    required this.etiqueta,
    required this.materia,
    required this.info,
    required this.horario,
    required this.salon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            padding:
                const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            decoration: BoxDecoration(
              color: color.withAlpha(20),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              etiqueta,
              style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  color: color),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              '$materia  ·  $info\n$horario  ·  $salon',
              style: const TextStyle(fontSize: 11),
            ),
          ),
        ],
      );
}

class _Chip extends StatelessWidget {
  final String text;
  final Color color;
  const _Chip({required this.text, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withAlpha(15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withAlpha(60)),
        ),
        child: Text(text,
            style: TextStyle(
                fontSize: 10,
                color: color,
                fontWeight: FontWeight.w500)),
      );
}

// ─────────────────────────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final String title;
  final String? subtitle;
  const _SectionTitle(this.title, {this.subtitle});

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: Theme.of(context).textTheme.titleMedium!
                  .copyWith(fontWeight: FontWeight.bold)),
          if (subtitle != null)
            Text(subtitle!,
                style: Theme.of(context).textTheme.bodySmall),
        ],
      );
}
