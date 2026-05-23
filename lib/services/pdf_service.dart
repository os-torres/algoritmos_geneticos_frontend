import 'dart:math' as math;
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/asignacion.dart';
import '../models/resultado_generacion.dart';

// ── Paleta PDF ─────────────────────────────────────────────────────────────
const _kAzul        = PdfColor.fromInt(0xFF1565C0);
const _kAzulClaro   = PdfColor.fromInt(0xFFE3F2FD);
const _kVerde       = PdfColor.fromInt(0xFF2E7D32);
const _kRojo        = PdfColor.fromInt(0xFFC62828);
const _kGris        = PdfColor.fromInt(0xFF757575);
const _kGrisClaro   = PdfColor.fromInt(0xFFF5F5F5);
const _kGrisBorde   = PdfColor.fromInt(0xFFE0E0E0);
const _kNaranja     = PdfColor.fromInt(0xFFE65100);
const _kBlancoSemi  = PdfColor(1, 1, 1, 0.75); // blanco semi-transparente

const _dias = ['Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes'];

// ────────────────────────────────────────────────────────────────────────────

class PdfService {
  /// Genera el PDF completo y devuelve los bytes.
  /// Usa NotoSans (Google Fonts) para soportar caracteres con tilde/ñ.
  static Future<Uint8List> generar({
    required List<Asignacion> horario,
    required List<ResultadoGeneracion> historial,
    required double mejorFitness,
    required int conflictos,
    required int generacionActual,
    required int numGeneraciones,
    required int tamPoblacion,
    required double probCruz,
    required double probMut,
    required int numElite,
  }) async {
    // Fuentes con soporte Unicode completo
    final regular = await PdfGoogleFonts.notoSansRegular();
    final bold    = await PdfGoogleFonts.notoSansBold();
    final italic  = await PdfGoogleFonts.notoSansItalic();

    final theme = pw.ThemeData.withFont(
      base: regular, bold: bold, italic: italic,
    );

    final doc = pw.Document(theme: theme);

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 36, vertical: 40),
        header: (ctx) => _encabezado(ctx, bold),
        footer: (ctx) => _pie(ctx, regular),
        build: (ctx) => [
          _tituloSeccion('Resultados del Algoritmo', bold),
          pw.SizedBox(height: 8),
          _cajaResultados(mejorFitness, conflictos, generacionActual,
              numGeneraciones, bold, regular),
          pw.SizedBox(height: 16),

          _tituloSeccion('Parámetros Utilizados', bold),
          pw.SizedBox(height: 8),
          _tablaParametros(tamPoblacion, numGeneraciones, probCruz, probMut,
              numElite, regular, bold),
          pw.SizedBox(height: 16),

          if (historial.isNotEmpty) ...[
            _tituloSeccion('Convergencia del Fitness', bold),
            pw.SizedBox(height: 6),
            _leyendaGrafica(regular),
            pw.SizedBox(height: 6),
            _graficaConvergencia(historial),
            pw.SizedBox(height: 20),
          ],

          _tituloSeccion(
              'Horario Generado — ${horario.length} sesiones', bold),
          pw.SizedBox(height: 8),
          ..._tablaHorarioPorSemestre(horario, regular, bold),
        ],
      ),
    );

    return doc.save();
  }

  // ── Encabezado de página ───────────────────────────────────────────────────

  static pw.Widget _encabezado(pw.Context ctx, pw.Font bold) {
    if (ctx.pageNumber == 1) {
      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: const pw.BoxDecoration(color: _kAzul),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('HORARIO GENÉTICO',
                        style: pw.TextStyle(
                            font: bold,
                            fontSize: 18,
                            color: PdfColors.white)),
                    pw.Text('Universidad de la Amazonia',
                        style: const pw.TextStyle(
                            fontSize: 10,
                            color: _kBlancoSemi)),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('Inteligencia Artificial',
                        style: const pw.TextStyle(
                            fontSize: 9, color: _kBlancoSemi)),
                    pw.Text('Algoritmos Genéticos',
                        style: const pw.TextStyle(
                            fontSize: 9, color: _kBlancoSemi)),
                  ],
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 16),
        ],
      );
    }
    // Páginas siguientes: encabezado pequeño
    return pw.Column(
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('Horario Genético — Universidad de la Amazonia',
                style: const pw.TextStyle(fontSize: 8, color: _kGris)),
            pw.Text(
                '${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}',
                style: const pw.TextStyle(fontSize: 8, color: _kGris)),
          ],
        ),
        pw.Divider(color: _kGrisBorde, height: 6),
        pw.SizedBox(height: 8),
      ],
    );
  }

  // ── Pie de página ──────────────────────────────────────────────────────────

  static pw.Widget _pie(pw.Context ctx, pw.Font regular) {
    return pw.Column(
      children: [
        pw.Divider(color: _kGrisBorde, height: 6),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
                'Oscar Ivan Torres · Andres Carrillo · Mercy Florez',
                style: const pw.TextStyle(fontSize: 7, color: _kGris)),
            pw.Text('Página ${ctx.pageNumber} de ${ctx.pagesCount}',
                style: const pw.TextStyle(fontSize: 7, color: _kGris)),
          ],
        ),
      ],
    );
  }

  // ── Título de sección ──────────────────────────────────────────────────────

  static pw.Widget _tituloSeccion(String titulo, pw.Font bold) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(titulo,
            style: pw.TextStyle(
                font: bold, fontSize: 13, color: _kAzul)),
        pw.Container(
            height: 2, color: _kAzul, margin: const pw.EdgeInsets.only(top: 3)),
      ],
    );
  }

  // ── Caja de resultados ─────────────────────────────────────────────────────

  static pw.Widget _cajaResultados(
    double fitness,
    int conflic,
    int genActual,
    int genTotal,
    pw.Font bold,
    pw.Font regular,
  ) {
    final items = [
      ('Fitness', fitness.toStringAsFixed(1), conflic == 0 ? _kVerde : _kAzul),
      ('Conflictos', '$conflic', conflic == 0 ? _kVerde : _kRojo),
      ('Generaciones', '$genActual / $genTotal', _kAzul),
    ];

    return pw.Container(
      decoration: pw.BoxDecoration(
        color: _kAzulClaro,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
        border: pw.Border.all(color: _kAzul, width: 0.5),
      ),
      padding: const pw.EdgeInsets.all(12),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
        children: items.map((item) {
          return pw.Column(
            children: [
              pw.Text(item.$1,
                  style: const pw.TextStyle(fontSize: 9, color: _kGris)),
              pw.SizedBox(height: 4),
              pw.Text(item.$2,
                  style: pw.TextStyle(
                      font: bold, fontSize: 20, color: item.$3)),
            ],
          );
        }).toList(),
      ),
    );
  }

  // ── Tabla de parámetros ────────────────────────────────────────────────────

  static pw.Widget _tablaParametros(
    int tamPob,
    int numGen,
    double pCruz,
    double pMut,
    int elite,
    pw.Font regular,
    pw.Font bold,
  ) {
    final params = [
      ['Tamaño de población', '$tamPob individuos'],
      ['Número de generaciones', '$numGen'],
      ['Probabilidad de cruzamiento', pCruz.toStringAsFixed(2)],
      ['Probabilidad de mutación', pMut.toStringAsFixed(2)],
      ['Elitismo (individuos conservados)', '$elite'],
      ['Selección', 'Torneo determinístico'],
      ['Cruzamiento', 'Order Crossover (OX)'],
      ['Mutación', 'Intercambio de posiciones (Swap)'],
    ];

    return pw.Table(
      border: pw.TableBorder.all(color: _kGrisBorde, width: 0.5),
      columnWidths: const {
        0: pw.FlexColumnWidth(2.2),
        1: pw.FlexColumnWidth(1.8),
      },
      children: params.asMap().entries.map((entry) {
        final isEven = entry.key.isEven;
        return pw.TableRow(
          decoration: pw.BoxDecoration(
              color: isEven ? PdfColors.white : _kGrisClaro),
          children: [
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(
                  horizontal: 8, vertical: 5),
              child: pw.Text(entry.value[0],
                  style: pw.TextStyle(font: bold, fontSize: 9)),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(
                  horizontal: 8, vertical: 5),
              child: pw.Text(entry.value[1],
                  style: const pw.TextStyle(fontSize: 9)),
            ),
          ],
        );
      }).toList(),
    );
  }

  // ── Leyenda de la gráfica ──────────────────────────────────────────────────

  static pw.Widget _leyendaGrafica(pw.Font regular) {
    return pw.Row(
      children: [
        _itemLeyenda('Mejor fitness', _kAzul, 2.0),
        pw.SizedBox(width: 16),
        _itemLeyenda('Fitness promedio', _kNaranja, 1.0),
        pw.SizedBox(width: 16),
        _itemLeyenda('Peor fitness', PdfColors.grey400, 0.8),
      ],
    );
  }

  static pw.Widget _itemLeyenda(String label, PdfColor color, double w) {
    return pw.Row(
      children: [
        pw.Container(width: 18, height: w + 1, color: color),
        pw.SizedBox(width: 4),
        pw.Text(label, style: const pw.TextStyle(fontSize: 8, color: _kGris)),
      ],
    );
  }

  // ── Gráfica de convergencia ────────────────────────────────────────────────

  static pw.Widget _graficaConvergencia(
      List<ResultadoGeneracion> historial) {
    return pw.Container(
      height: 160,
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _kGrisBorde, width: 0.5),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
        color: PdfColors.white,
      ),
      // LayoutBuilder provee el ancho real disponible al painter
      child: pw.LayoutBuilder(
        builder: (ctx, constraints) {
          final double w = constraints?.maxWidth ?? 500.0;
          return pw.CustomPaint(
            size: PdfPoint(w, 160),
            painter: (canvas, size) =>
                _pintarGrafica(canvas, size, historial),
          );
        },
      ),
    );
  }

  static void _pintarGrafica(
    PdfGraphics canvas,
    PdfPoint size,
    List<ResultadoGeneracion> historial,
  ) {
    if (historial.length < 2) return;

    final pad  = 20.0;
    final w    = size.x - pad * 2;
    final h    = size.y - pad * 2;
    final n    = historial.length;

    // Rango de valores
    final allV = historial.expand((g) =>
        [g.mejorFitness, g.promedioFitness, g.peorFitness]);
    final maxV = allV.reduce(math.max);
    final minV = allV.reduce(math.min);
    final range = (maxV - minV).clamp(1.0, double.infinity);

    // Coordenadas (PDF: origen en bottom-left)
    double px(int i) => pad + (i / (n - 1)) * w;
    double py(double v) => pad + ((v - minV) / range) * h;

    // Guías horizontales
    canvas.setStrokeColor(PdfColors.grey200);
    canvas.setLineWidth(0.3);
    for (int i = 0; i <= 4; i++) {
      final y = pad + (i / 4) * h;
      canvas.moveTo(pad, y);
      canvas.lineTo(pad + w, y);
      canvas.strokePath();
    }

    // Ejes
    canvas.setStrokeColor(PdfColors.grey400);
    canvas.setLineWidth(0.6);
    canvas.moveTo(pad, pad);
    canvas.lineTo(pad, pad + h);
    canvas.strokePath();
    canvas.moveTo(pad, pad);
    canvas.lineTo(pad + w, pad);
    canvas.strokePath();

    // Peor fitness (gris, fondo)
    canvas.setStrokeColor(PdfColors.grey400);
    canvas.setLineWidth(0.7);
    canvas.moveTo(px(0), py(historial[0].peorFitness));
    for (int i = 1; i < n; i++) {
      canvas.lineTo(px(i), py(historial[i].peorFitness));
    }
    canvas.strokePath();

    // Promedio (naranja)
    canvas.setStrokeColor(_kNaranja);
    canvas.setLineWidth(1.0);
    canvas.moveTo(px(0), py(historial[0].promedioFitness));
    for (int i = 1; i < n; i++) {
      canvas.lineTo(px(i), py(historial[i].promedioFitness));
    }
    canvas.strokePath();

    // Mejor fitness (azul, encima)
    canvas.setStrokeColor(_kAzul);
    canvas.setLineWidth(1.8);
    canvas.moveTo(px(0), py(historial[0].mejorFitness));
    for (int i = 1; i < n; i++) {
      canvas.lineTo(px(i), py(historial[i].mejorFitness));
    }
    canvas.strokePath();
  }

  // ── Tabla de horario organizada por Semestre → Día → Hora ──────────────────

  static List<pw.Widget> _tablaHorarioPorSemestre(
    List<Asignacion> horario,
    pw.Font regular,
    pw.Font bold,
  ) {
    if (horario.isEmpty) {
      return [
        pw.Text('No hay sesiones en el horario.',
            style: const pw.TextStyle(fontSize: 9, color: _kGris)),
      ];
    }

    // Agrupar por semestre
    final Map<int, List<Asignacion>> porSemestre = {};
    for (final a in horario) {
      porSemestre.putIfAbsent(a.semestre, () => []).add(a);
    }
    final semestres = porSemestre.keys.toList()..sort();

    final widgets = <pw.Widget>[];

    for (final sem in semestres) {
      final clasesSem = porSemestre[sem]!;

      // ── Encabezado de semestre ────────────────────────────────────────
      widgets.add(pw.SizedBox(height: 12));
      widgets.add(pw.Container(
        decoration: const pw.BoxDecoration(color: _kAzul),
        padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        child: pw.Row(
          children: [
            pw.Text('SEMESTRE $sem',
                style: pw.TextStyle(
                    font: bold, fontSize: 11, color: PdfColors.white)),
            pw.Spacer(),
            pw.Text('${clasesSem.length} sesiones/sem.',
                style: const pw.TextStyle(
                    fontSize: 8, color: _kBlancoSemi)),
          ],
        ),
      ));

      // Agrupar por día dentro del semestre y ordenar por hora
      final Map<String, List<Asignacion>> porDia = {};
      for (final a in clasesSem) {
        porDia.putIfAbsent(a.dia, () => []).add(a);
      }
      for (final lst in porDia.values) {
        lst.sort((a, b) => a.horaInicio.compareTo(b.horaInicio));
      }

      for (final dia in _dias) {
        final clasesDia = porDia[dia];
        if (clasesDia == null || clasesDia.isEmpty) continue;

        // Sub-encabezado del día
        widgets.add(pw.Container(
          color: _kAzulClaro,
          padding:
              const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: pw.Row(
            children: [
              pw.Text('  $dia',
                  style: pw.TextStyle(
                      font: bold, fontSize: 9, color: _kAzul)),
              pw.Spacer(),
              pw.Text('${clasesDia.length} clase(s)',
                  style: const pw.TextStyle(fontSize: 8, color: _kGris)),
            ],
          ),
        ));

        // Tabla de clases del día
        widgets.add(pw.Table(
          border: pw.TableBorder.all(color: _kGrisBorde, width: 0.4),
          columnWidths: const {
            0: pw.FixedColumnWidth(50),   // Inicio
            1: pw.FixedColumnWidth(50),   // Fin
            2: pw.FixedColumnWidth(18),   // h
            3: pw.FlexColumnWidth(2.8),   // Materia
            4: pw.FixedColumnWidth(20),   // Gr.
            5: pw.FlexColumnWidth(2.2),   // Profesor
            6: pw.FixedColumnWidth(52),   // Salón
          },
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: _kAzulClaro),
              children: ['Inicio', 'Fin', 'h', 'Materia', 'Gr.',
                         'Profesor', 'Salón']
                  .map((h) => pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(
                            horizontal: 4, vertical: 4),
                        child: pw.Text(h,
                            style: pw.TextStyle(
                                font: bold, fontSize: 7, color: _kAzul)),
                      ))
                  .toList(),
            ),
            ...clasesDia.asMap().entries.map((entry) {
              final isEven = entry.key.isEven;
              final a      = entry.value;
              return pw.TableRow(
                decoration: pw.BoxDecoration(
                    color: isEven ? PdfColors.white : _kGrisClaro),
                children: [
                  a.horaInicio,
                  a.horaFin,
                  '${a.duracionHoras}h',
                  a.materia,
                  a.grupo,
                  a.profesor,
                  a.salon,
                ]
                    .map((cell) => pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(
                              horizontal: 4, vertical: 4),
                          child: pw.Text(cell,
                              style: const pw.TextStyle(fontSize: 7.5)),
                        ))
                    .toList(),
              );
            }),
          ],
        ));
      }
    }

    return widgets;
  }
}
