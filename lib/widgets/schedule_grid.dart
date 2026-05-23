import 'package:flutter/material.dart';
import '../models/asignacion.dart';
import '../config.dart';

/// Vista de horario semanal.
/// Muestra una barra de días (Lun–Vie) y, para el día seleccionado,
/// una lista de tarjetas con franja, materia, profesor, grupo y salón.
class ScheduleGrid extends StatefulWidget {
  final List<Asignacion> horario;

  const ScheduleGrid({super.key, required this.horario});

  @override
  State<ScheduleGrid> createState() => _ScheduleGridState();
}

class _ScheduleGridState extends State<ScheduleGrid> {
  static const _dias = ['Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes'];
  int _diaIdx = 0;

  @override
  Widget build(BuildContext context) {
    // Agrupar por día y ordenar por hora de inicio
    final Map<String, List<Asignacion>> porDia = {};
    for (final a in widget.horario) {
      porDia.putIfAbsent(a.dia, () => []).add(a);
    }
    for (final lst in porDia.values) {
      lst.sort((a, b) => a.horaInicio.compareTo(b.horaInicio));
    }

    final diaActual = _dias[_diaIdx];
    final clases = porDia[diaActual] ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Selector de día ──────────────────────────────────────────
        SizedBox(
          height: 44,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            itemCount: _dias.length,
            separatorBuilder: (ctx, i2) => const SizedBox(width: 6),
            itemBuilder: (_, i) {
              final selected = i == _diaIdx;
              final tieneClases = porDia.containsKey(_dias[i]);
              return ChoiceChip(
                label: Text(
                  _dias[i].substring(0, 3),
                  style: TextStyle(
                    fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                    fontSize: 13,
                  ),
                ),
                selected: selected,
                avatar: tieneClases && !selected
                    ? const CircleAvatar(
                        radius: 4,
                        backgroundColor: Colors.green,
                      )
                    : null,
                onSelected: (selected) => setState(() => _diaIdx = i),
              );
            },
          ),
        ),
        const SizedBox(height: 10),

        // ── Lista de clases del día ───────────────────────────────────
        if (clases.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text(
                'Sin clases el $diaActual',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.outline,
                  fontSize: 14,
                ),
              ),
            ),
          )
        else
          ...clases.map((a) => _ClaseCard(asig: a)),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _ClaseCard extends StatelessWidget {
  final Asignacion asig;
  const _ClaseCard({required this.asig});

  @override
  Widget build(BuildContext context) {
    final groupC   = groupColor(asig.grupo);
    final semC     = semesterColor(asig.semestre);
    final cs       = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: groupC.withAlpha(80), width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Borde superior de color semestre ─────────────────────
          Container(height: 4, color: semC),

          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Franja de color izquierda (grupo) + hora
                Container(
                  width: 72,
                  decoration: BoxDecoration(
                    color: groupC.withAlpha(30),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        asig.horaInicio,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: groupC,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Icon(Icons.arrow_downward, size: 12, color: groupC),
                      const SizedBox(height: 2),
                      Text(
                        asig.horaFin,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: groupC,
                        ),
                      ),
                    ],
                  ),
                ),
                // Contenido
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Materia + badge semestre
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                asig.materia,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: semC.withAlpha(20),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: semC.withAlpha(120)),
                              ),
                              child: Text(
                                'Sem. ${asig.semestre}',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: semC,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        // Profesor
                        Row(
                          children: [
                            Icon(Icons.person_outline,
                                size: 13, color: cs.outline),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                asig.profesor,
                                style: TextStyle(
                                    fontSize: 12, color: cs.onSurfaceVariant),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        // Salón + duración + grupo
                        Row(
                          children: [
                            Icon(Icons.meeting_room_outlined,
                                size: 13, color: cs.outline),
                            const SizedBox(width: 4),
                            Text(
                              asig.salon,
                              style: TextStyle(
                                  fontSize: 12, color: cs.onSurfaceVariant),
                            ),
                            const SizedBox(width: 8),
                            Icon(Icons.timer_outlined,
                                size: 13, color: cs.outline),
                            const SizedBox(width: 2),
                            Text(
                              '${asig.duracionHoras}h',
                              style: TextStyle(
                                  fontSize: 12, color: cs.onSurfaceVariant),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: groupC.withAlpha(25),
                                borderRadius: BorderRadius.circular(20),
                                border:
                                    Border.all(color: groupC.withAlpha(100)),
                              ),
                              child: Text(
                                'Grupo ${asig.grupo}',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: groupC,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
