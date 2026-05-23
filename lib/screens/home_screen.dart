import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/data_provider.dart';
import '../providers/optimization_provider.dart';
import '../widgets/stat_card.dart';

class HomeScreen extends StatefulWidget {
  final VoidCallback? onGoToDatos;
  final VoidCallback? onGoToOptimizar;

  const HomeScreen({super.key, this.onGoToDatos, this.onGoToOptimizar});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DataProvider>().cargarTodo();
    });
  }

  @override
  Widget build(BuildContext context) {
    final dp  = context.watch<DataProvider>();
    final opt = context.watch<OptimizationProvider>();
    final cs  = Theme.of(context).colorScheme;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            title: const Text('Horario Genético'),
            backgroundColor: cs.primaryContainer,
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                tooltip: 'Recargar datos',
                onPressed: dp.cargarTodo,
              ),
            ],
          ),
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // --- Banner de estado ---
                _StatusBanner(opt: opt),
                const SizedBox(height: 20),

                // --- Tarjetas de resumen ---
                Text('Datos actuales',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),

                if (dp.loading)
                  const Center(child: CircularProgressIndicator())
                else if (dp.error != null)
                  _ErrorCard(message: dp.error!, onRetry: dp.cargarTodo)
                else
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 1.15,
                    children: [
                      StatCard(
                        label: 'Materias',
                        value: '${dp.materias.length}',
                        icon: Icons.book,
                        color: cs.primary,
                        onTap: widget.onGoToDatos,
                      ),
                      StatCard(
                        label: 'Profesores',
                        value: '${dp.profesores.length}',
                        icon: Icons.person,
                        color: const Color(0xFF2E7D32),
                        onTap: widget.onGoToDatos,
                      ),
                      StatCard(
                        label: 'Salones',
                        value: '${dp.salones.length}',
                        icon: Icons.meeting_room,
                        color: const Color(0xFFE65100),
                        onTap: widget.onGoToDatos,
                      ),
                      StatCard(
                        label: 'Sesiones/sem.',
                        value: '${dp.sesiones.length}',
                        icon: Icons.event_note,
                        color: const Color(0xFF6A1B9A),
                        onTap: widget.onGoToDatos,
                      ),
                    ],
                  ),

                const SizedBox(height: 24),

                // --- Botón principal ---
                FilledButton.icon(
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Generar Horario'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(double.infinity, 52),
                  ),
                  onPressed: dp.loading ? null : widget.onGoToOptimizar,
                ),

                const SizedBox(height: 12),

                // --- Validación rápida ---
                if (!dp.loading && dp.error == null)
                  _ReadyChip(resumen: dp.resumen),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _StatusBanner extends StatelessWidget {
  final OptimizationProvider opt;
  const _StatusBanner({required this.opt});

  @override
  Widget build(BuildContext context) {
    if (opt.status == OptStatus.idle) return const SizedBox.shrink();

    final cs = Theme.of(context).colorScheme;
    final (color, icon, text) = switch (opt.status) {
      OptStatus.running => (
          cs.primaryContainer,
          Icons.science,
          'Generando horario… Gen. ${opt.generacionActual}'
        ),
      OptStatus.done => (
          const Color(0xFFE8F5E9),
          Icons.check_circle,
          'Horario listo · Fitness: ${opt.mejorFitness.toStringAsFixed(0)}'
        ),
      OptStatus.error => (
          cs.errorContainer,
          Icons.error,
          opt.errorMsg ?? 'Error'
        ),
      _ => (cs.surface, Icons.info, ''),
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
          color: color, borderRadius: BorderRadius.circular(10)),
      child: Row(
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

class _ReadyChip extends StatelessWidget {
  final Map<String, dynamic> resumen;
  const _ReadyChip({required this.resumen});

  @override
  Widget build(BuildContext context) {
    final listo = resumen['listo_para_optimizar'] == true;
    return Row(
      children: [
        Icon(
          listo ? Icons.check_circle_outline : Icons.warning_amber,
          size: 16,
          color: listo ? Colors.green : Colors.orange,
        ),
        const SizedBox(width: 6),
        Text(
          listo
              ? '${resumen['total_sesiones']} sesiones · ${resumen['total_ranuras']} ranuras disponibles'
              : 'Faltan datos para optimizar',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorCard({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            const Icon(Icons.cloud_off),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
            TextButton(onPressed: onRetry, child: const Text('Reintentar')),
          ],
        ),
      ),
    );
  }
}
