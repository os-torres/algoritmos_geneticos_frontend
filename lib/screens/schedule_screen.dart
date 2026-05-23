import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import '../config.dart';
import '../models/asignacion.dart';
import '../models/resultado_generacion.dart';
import '../providers/optimization_provider.dart';
import '../services/pdf_service.dart';
import '../widgets/schedule_grid.dart';

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  int?    _semestreFiltro;
  String? _grupoFiltro;

  @override
  Widget build(BuildContext context) {
    final opt = context.watch<OptimizationProvider>();

    final semestres = opt.horarioFinal
        .map((a) => a.semestre)
        .toSet()
        .toList()
      ..sort();

    final grupos = opt.horarioFinal
        .map((a) => a.grupo)
        .toSet()
        .toList()
      ..sort();

    final horarioFiltrado = opt.horarioFinal.where((a) {
      if (_semestreFiltro != null && a.semestre != _semestreFiltro) return false;
      if (_grupoFiltro != null && a.grupo != _grupoFiltro) return false;
      return true;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Horario Generado'),
        actions: [
          if (opt.horarioFinal.isNotEmpty) ...[
            IconButton(
              icon: const Icon(Icons.table_rows),
              tooltip: 'Vista por materia',
              onPressed: () => _showMateriaView(context, horarioFiltrado),
            ),
            IconButton(
              icon: const Icon(Icons.ios_share_outlined),
              tooltip: 'Exportar horario',
              onPressed: () => _showExportSheet(context, horarioFiltrado),
            ),
          ],
        ],
      ),
      body: opt.horarioFinal.isEmpty
          ? _EmptyState(isRunning: opt.status == OptStatus.running)
          : Column(
              children: [
                if (semestres.length > 1)
                  _SemestresFilter(
                    semestres: semestres,
                    seleccionado: _semestreFiltro,
                    onChanged: (s) => setState(() => _semestreFiltro = s),
                  ),
                if (grupos.length > 1)
                  _GruposFilter(
                    grupos: grupos,
                    seleccionado: _grupoFiltro,
                    onChanged: (g) => setState(() => _grupoFiltro = g),
                  ),
                Expanded(
                  child: horarioFiltrado.isEmpty
                      ? _NoResultsState(
                          onClear: () => setState(() {
                            _semestreFiltro = null;
                            _grupoFiltro    = null;
                          }),
                        )
                      : _HorarioContent(
                          opt: opt,
                          horario: horarioFiltrado,
                        ),
                ),
              ],
            ),
    );
  }

  // ── Vista por materia ────────────────────────────────────────────────────

  void _showMateriaView(BuildContext context, List<Asignacion> horario) {
    final sorted = [...horario]
      ..sort((a, b) => a.materia.compareTo(b.materia));

    final Map<String, List<Asignacion>> porMateria = {};
    for (final a in sorted) {
      porMateria.putIfAbsent(a.materia, () => []).add(a);
    }
    for (final l in porMateria.values) {
      l.sort((a, b) => a.dia.compareTo(b.dia));
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.88,
        builder: (_, ctrl) => ListView(
          controller: ctrl,
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
          children: [
            Text('Clases por materia',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            for (final entry in porMateria.entries) ...[
              _MateriaSectionHeader(
                nombre: entry.key,
                grupo: entry.value.first.grupo,
                semestre: entry.value.first.semestre,
              ),
              for (final a in entry.value)
                _CompactRow(asig: a),
              const SizedBox(height: 10),
            ],
          ],
        ),
      ),
    );
  }

  // ── Exportar ─────────────────────────────────────────────────────────────

  void _showExportSheet(BuildContext context, List<Asignacion> horario) {
    final opt = context.read<OptimizationProvider>();
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Exportar horario',
                style: Theme.of(context).textTheme.titleLarge),
            Text(
              '${horario.length} sesiones'
              '${_semestreFiltro != null ? ' · Sem. $_semestreFiltro' : ''}'
              '${_grupoFiltro != null ? ' · Grupo $_grupoFiltro' : ''}',
              style: TextStyle(
                  color: Theme.of(context).colorScheme.outline, fontSize: 13),
            ),
            const SizedBox(height: 20),
            _ExportOption(
              icon: Icons.picture_as_pdf_outlined,
              title: 'Generar PDF',
              subtitle: 'Horario, gráficas y resultados completos',
              color: Colors.red.shade700,
              onTap: () {
                Navigator.pop(context);
                _abrirPdfPreview(context, horario, opt);
              },
            ),
            const SizedBox(height: 10),
            _ExportOption(
              icon: Icons.text_snippet_outlined,
              title: 'Copiar como texto',
              subtitle: 'Formato legible por día y hora',
              onTap: () {
                Navigator.pop(context);
                _copyText(context, horario);
              },
            ),
            const SizedBox(height: 10),
            _ExportOption(
              icon: Icons.table_chart_outlined,
              title: 'Copiar como CSV',
              subtitle: 'Para abrir en Excel o Google Sheets',
              onTap: () {
                Navigator.pop(context);
                _copyCsv(context, horario);
              },
            ),
          ],
        ),
      ),
    );
  }

  // ── Previsualización y descarga del PDF ───────────────────────────────────
  void _abrirPdfPreview(
    BuildContext context,
    List<Asignacion> horario,
    OptimizationProvider opt,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _PdfPreviewScreen(
          horario:          horario,
          historial:        opt.historial,
          mejorFitness:     opt.mejorFitness,
          conflictos:       opt.conflictos,
          generacionActual: opt.generacionActual,
          numGeneraciones:  opt.numGeneraciones,
          tamPoblacion:     opt.tamPoblacion,
          probCruz:         opt.probCruz,
          probMut:          opt.probMut,
          numElite:         opt.numElite,
        ),
      ),
    );
  }

  void _copyText(BuildContext context, List<Asignacion> horario) {
    const dias = ['Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes'];
    final Map<String, List<Asignacion>> porDia = {};
    for (final a in horario) {
      porDia.putIfAbsent(a.dia, () => []).add(a);
    }
    for (final l in porDia.values) {
      l.sort((a, b) => a.horaInicio.compareTo(b.horaInicio));
    }

    final buf = StringBuffer();
    buf.writeln('HORARIO UNIVERSITARIO — Universidad de la Amazonia');
    buf.writeln('Facultad de Ingeniería · Ingeniería de Sistemas');
    buf.writeln('─' * 50);
    for (final dia in dias) {
      final clases = porDia[dia];
      if (clases == null || clases.isEmpty) continue;
      buf.writeln('\n$dia'.toUpperCase());
      for (final a in clases) {
        buf.writeln(
          '  ${a.horaInicio}-${a.horaFin}  ${a.materia} '
          '(Sem.${a.semestre}, Grupo ${a.grupo}) [${a.duracionHoras}h]',
        );
        buf.writeln('             ${a.profesor} — ${a.salon}');
      }
    }

    Clipboard.setData(ClipboardData(text: buf.toString()));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(children: [
            Icon(Icons.check_circle, color: Colors.white, size: 18),
            SizedBox(width: 8),
            Text('Texto copiado al portapapeles'),
          ]),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _copyCsv(BuildContext context, List<Asignacion> horario) {
    final sorted = [...horario]
      ..sort((a, b) {
        final d = a.dia.compareTo(b.dia);
        return d != 0 ? d : a.horaInicio.compareTo(b.horaInicio);
      });

    final buf = StringBuffer();
    buf.writeln(
        'Día,Hora Inicio,Hora Fin,Duración (h),Semestre,Materia,Grupo,Profesor,Salón,Capacidad');
    for (final a in sorted) {
      buf.writeln(
        '"${a.dia}","${a.horaInicio}","${a.horaFin}",${a.duracionHoras},'
        '${a.semestre},"${a.materia}","${a.grupo}","${a.profesor}",'
        '"${a.salon}",${a.salonCapacidad}',
      );
    }

    Clipboard.setData(ClipboardData(text: buf.toString()));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(children: [
            Icon(Icons.check_circle, color: Colors.white, size: 18),
            SizedBox(width: 8),
            Text('CSV copiado al portapapeles'),
          ]),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Filtro de semestres con colores
// ─────────────────────────────────────────────────────────────────────────────

class _SemestresFilter extends StatelessWidget {
  final List<int> semestres;
  final int? seleccionado;
  final ValueChanged<int?> onChanged;
  const _SemestresFilter({
    required this.semestres,
    required this.seleccionado,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: FilterChip(
              label: const Text('Todos'),
              selected: seleccionado == null,
              onSelected: (_) => onChanged(null),
            ),
          ),
          for (final s in semestres)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: _SemesterChip(
                semestre: s,
                selected: seleccionado == s,
                onSelected: () => onChanged(seleccionado == s ? null : s),
              ),
            ),
        ],
      ),
    );
  }
}

class _SemesterChip extends StatelessWidget {
  final int semestre;
  final bool selected;
  final VoidCallback onSelected;
  const _SemesterChip(
      {required this.semestre,
      required this.selected,
      required this.onSelected});

  @override
  Widget build(BuildContext context) {
    final color = semesterColor(semestre);
    return GestureDetector(
      onTap: onSelected,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: selected ? color : color.withAlpha(20),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: selected ? color : color.withAlpha(100), width: 1.5),
        ),
        child: Text(
          'Sem. $semestre',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: selected ? Colors.white : color,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Filtro de grupos con colores
// ─────────────────────────────────────────────────────────────────────────────

class _GruposFilter extends StatelessWidget {
  final List<String> grupos;
  final String? seleccionado;
  final ValueChanged<String?> onChanged;
  const _GruposFilter({
    required this.grupos,
    required this.seleccionado,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerLowest,
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: FilterChip(
              label: const Text('Todos los grupos'),
              selected: seleccionado == null,
              onSelected: (_) => onChanged(null),
            ),
          ),
          for (final g in grupos)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: _GrupoChip(
                grupo: g,
                selected: seleccionado == g,
                onSelected: () => onChanged(seleccionado == g ? null : g),
              ),
            ),
        ],
      ),
    );
  }
}

class _GrupoChip extends StatelessWidget {
  final String grupo;
  final bool selected;
  final VoidCallback onSelected;
  const _GrupoChip(
      {required this.grupo,
      required this.selected,
      required this.onSelected});

  @override
  Widget build(BuildContext context) {
    final color = groupColor(grupo);
    return GestureDetector(
      onTap: onSelected,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        decoration: BoxDecoration(
          color: selected ? color : color.withAlpha(20),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: selected ? color : color.withAlpha(100), width: 1.5),
        ),
        child: Text(
          'Grupo $grupo',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: selected ? Colors.white : color,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sin resultados con filtros activos
// ─────────────────────────────────────────────────────────────────────────────

class _NoResultsState extends StatelessWidget {
  final VoidCallback onClear;
  const _NoResultsState({required this.onClear});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.filter_alt_off_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.outline),
          const SizedBox(height: 12),
          Text(
            'Sin clases con los filtros aplicados',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 12),
          FilledButton.tonal(
            onPressed: onClear,
            child: const Text('Limpiar filtros'),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _HorarioContent extends StatelessWidget {
  final OptimizationProvider opt;
  final List<Asignacion> horario;
  const _HorarioContent({required this.opt, required this.horario});

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (opt.status == OptStatus.done) _MetricsRow(opt: opt),
                const SizedBox(height: 12),
                _Legends(horario: horario),
                const SizedBox(height: 16),
                Text('Horario semanal',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium!
                        .copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
        SliverFillRemaining(
          hasScrollBody: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: ScheduleGrid(horario: horario),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Leyenda: grupos + semestres
// ─────────────────────────────────────────────────────────────────────────────

class _Legends extends StatelessWidget {
  final List<Asignacion> horario;
  const _Legends({required this.horario});

  @override
  Widget build(BuildContext context) {
    final grupos = horario.map((a) => a.grupo).toSet().toList()..sort();
    final semestres = horario.map((a) => a.semestre).toSet().toList()..sort();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Grupos
        Wrap(
          spacing: 6,
          runSpacing: 4,
          children: grupos.map((g) {
            final c = groupColor(g);
            return Chip(
              avatar: CircleAvatar(backgroundColor: c, radius: 8),
              label: Text('Grupo $g',
                  style: const TextStyle(fontSize: 12)),
              visualDensity: VisualDensity.compact,
              backgroundColor: c.withAlpha(18),
            );
          }).toList(),
        ),
        if (semestres.length > 1) ...[
          const SizedBox(height: 6),
          // Semestres — con su color correspondiente
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: semestres.map((s) {
              final c = semesterColor(s);
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: c.withAlpha(18),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: c.withAlpha(100)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                        width: 8, height: 8,
                        decoration: BoxDecoration(
                            color: c, shape: BoxShape.circle)),
                    const SizedBox(width: 5),
                    Text('Sem. $s',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: c)),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _ExportOption extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  final VoidCallback onTap;
  final Color? color;
  const _ExportOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          border: Border.all(color: cs.outlineVariant),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color != null
                    ? color!.withAlpha(20)
                    : cs.primaryContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon,
                  color: color ?? cs.onPrimaryContainer, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 14)),
                  Text(subtitle,
                      style: TextStyle(
                          fontSize: 12, color: cs.onSurfaceVariant)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: cs.outline),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final bool isRunning;
  const _EmptyState({required this.isRunning});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.calendar_today_outlined,
              size: 80, color: Theme.of(context).colorScheme.outline),
          const SizedBox(height: 16),
          Text(
            isRunning
                ? 'Generando horario…'
                : 'Aún no hay horario generado.\n'
                    'Ve a la pestaña Optimizar e inicia el algoritmo.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          if (isRunning) ...[
            const SizedBox(height: 16),
            const CircularProgressIndicator(),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _MetricsRow extends StatelessWidget {
  final OptimizationProvider opt;
  const _MetricsRow({required this.opt});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _Metric(label: 'Fitness',
            value: opt.mejorFitness.toStringAsFixed(0)),
        const SizedBox(width: 8),
        _Metric(label: 'Conflictos',
            value: '${opt.conflictos}', ok: opt.conflictos == 0),
        const SizedBox(width: 8),
        _Metric(label: 'Generaciones',
            value: '${opt.generacionActual}'),
      ],
    );
  }
}

class _Metric extends StatelessWidget {
  final String label, value;
  final bool? ok;
  const _Metric({required this.label, required this.value, this.ok});

  @override
  Widget build(BuildContext context) {
    Color? color;
    if (ok == true) color = Colors.green;
    if (ok == false) color = Theme.of(context).colorScheme.error;
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Column(children: [
            Text(value,
                style: TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 18, color: color)),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
          ]),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _MateriaSectionHeader extends StatelessWidget {
  final String nombre, grupo;
  final int semestre;
  const _MateriaSectionHeader(
      {required this.nombre, required this.grupo, required this.semestre});

  @override
  Widget build(BuildContext context) {
    final gc = groupColor(grupo);
    final sc = semesterColor(semestre);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: gc.withAlpha(18),
        borderRadius: BorderRadius.circular(8),
        border: Border(left: BorderSide(color: sc, width: 3)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(nombre,
                style: TextStyle(fontWeight: FontWeight.bold, color: gc)),
          ),
          Text('Sem. $semestre',
              style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.bold, color: sc)),
          const SizedBox(width: 8),
          Text('Grupo $grupo',
              style: TextStyle(fontSize: 12, color: gc)),
        ],
      ),
    );
  }
}

class _CompactRow extends StatelessWidget {
  final Asignacion asig;
  const _CompactRow({required this.asig});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
        child: Row(
          children: [
            SizedBox(
              width: 108,
              child: Text('${asig.dia.substring(0, 3)} ${asig.horaInicio}',
                  style: const TextStyle(fontSize: 12)),
            ),
            const SizedBox(width: 4),
            Icon(Icons.timer_outlined, size: 13,
                color: Theme.of(context).colorScheme.outline),
            const SizedBox(width: 2),
            Text('${asig.duracionHoras}h',
                style: const TextStyle(fontSize: 12)),
            const SizedBox(width: 8),
            Icon(Icons.meeting_room_outlined, size: 13,
                color: Theme.of(context).colorScheme.outline),
            const SizedBox(width: 4),
            Text(asig.salon, style: const TextStyle(fontSize: 12)),
          ],
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Pantalla de previsualización y descarga del PDF
// ─────────────────────────────────────────────────────────────────────────────

class _PdfPreviewScreen extends StatelessWidget {
  final List<Asignacion>          horario;
  final List<ResultadoGeneracion> historial;
  final double  mejorFitness;
  final int     conflictos;
  final int     generacionActual;
  final int     numGeneraciones;
  final int     tamPoblacion;
  final double  probCruz;
  final double  probMut;
  final int     numElite;

  const _PdfPreviewScreen({
    required this.horario,
    required this.historial,
    required this.mejorFitness,
    required this.conflictos,
    required this.generacionActual,
    required this.numGeneraciones,
    required this.tamPoblacion,
    required this.probCruz,
    required this.probMut,
    required this.numElite,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vista previa PDF'),
        backgroundColor:
            Theme.of(context).colorScheme.primaryContainer,
      ),
      body: PdfPreview(
        // Genera el PDF en cada llamada (botón de recarga en el AppBar de PdfPreview)
        build: (_) => PdfService.generar(
          horario:          horario,
          historial:        historial,
          mejorFitness:     mejorFitness,
          conflictos:       conflictos,
          generacionActual: generacionActual,
          numGeneraciones:  numGeneraciones,
          tamPoblacion:     tamPoblacion,
          probCruz:         probCruz,
          probMut:          probMut,
          numElite:         numElite,
        ),
        // Nombre del archivo al guardar/compartir
        initialPageFormat: PdfPageFormat.a4,
        pdfFileName:
            'horario_uniamazonia_${DateTime.now().millisecondsSinceEpoch}.pdf',
        // PdfPreview ya incluye botones de compartir e imprimir por defecto
        canChangePageFormat: false,
        canChangeOrientation: false,
        canDebug: false,
        loadingWidget: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Generando PDF…'),
            ],
          ),
        ),
      ),
    );
  }
}
