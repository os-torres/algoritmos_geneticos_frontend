import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../models/resultado_generacion.dart';

class FitnessChart extends StatelessWidget {
  final List<ResultadoGeneracion> historial;

  const FitnessChart({super.key, required this.historial});

  @override
  Widget build(BuildContext context) {
    if (historial.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    final cs       = Theme.of(context).colorScheme;
    final mejores  = historial.map((h) => h.mejorFitness).toList();
    final promedios = historial.map((h) => h.promedioFitness).toList();
    final maxY     =
        (mejores.reduce((a, b) => a > b ? a : b) * 1.08).clamp(100.0, 2000.0);
    final n        = historial.length;

    List<FlSpot> spots(List<double> vals) =>
        [for (int i = 0; i < vals.length; i++) FlSpot(i.toDouble(), vals[i])];

    final interval = (n / 5).clamp(1.0, 200.0);

    return LineChart(
      duration: const Duration(milliseconds: 100),
      LineChartData(
        minX: 0,
        maxX: (n - 1).toDouble(),
        minY: 0,
        maxY: maxY,
        clipData: const FlClipData.all(),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) =>
              FlLine(color: cs.outlineVariant, strokeWidth: 0.5),
        ),
        borderData: FlBorderData(
          show: true,
          border: Border(
            bottom: BorderSide(color: cs.outline, width: 0.8),
            left: BorderSide(color: cs.outline, width: 0.8),
          ),
        ),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 48,
              getTitlesWidget: (v, _) => Text(
                v.toInt().toString(),
                style: TextStyle(fontSize: 10, color: cs.outline),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: interval,
              getTitlesWidget: (v, _) => Text(
                v.toInt().toString(),
                style: TextStyle(fontSize: 10, color: cs.outline),
              ),
            ),
          ),
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        lineBarsData: [
          // Línea de mejor fitness
          LineChartBarData(
            spots: spots(mejores),
            isCurved: true,
            color: cs.primary,
            barWidth: 2.5,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: cs.primary.withAlpha(20),
            ),
          ),
          // Línea de promedio (punteada)
          LineChartBarData(
            spots: spots(promedios),
            isCurved: true,
            color: cs.tertiary,
            barWidth: 2,
            dashArray: [5, 4],
            dotData: const FlDotData(show: false),
          ),
        ],
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => cs.surface,
            getTooltipItems: (spots) => spots.map((s) {
              final label = s.barIndex == 0 ? 'Mejor' : 'Prom.';
              final color = s.barIndex == 0 ? cs.primary : cs.tertiary;
              return LineTooltipItem(
                '$label: ${s.y.toStringAsFixed(0)}',
                TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w600),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}
