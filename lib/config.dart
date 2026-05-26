import 'package:flutter/material.dart';

class AppConfig {
  /// URL base del servidor API (sin trailing slash).
  ///
  /// Producción  → https://giecom.com.co/HorarioGenetico
  /// Emulador    → http://10.0.2.2:8000
  /// Dispositivo → http://192.168.1.X:8000
  static const String baseUrl = 'https://giecom.com.co/HorarioGenetico';
}

// ── Paleta por grupo (A, B, C…) ──────────────────────────────────────────────
const Map<String, Color> kGroupColors = {
  'A': Color(0xFF1565C0),
  'B': Color(0xFF2E7D32),
  'C': Color(0xFFE65100),
  'D': Color(0xFF6A1B9A),
  'E': Color(0xFF00838F),
};

Color groupColor(String grupo) =>
    kGroupColors[grupo] ?? const Color(0xFF455A64);

// ── Paleta de 10 colores — uno por semestre ───────────────────────────────────
const List<Color> kSemesterColors = [
  Color(0xFF1A237E), // Sem 1 — azul índigo oscuro
  Color(0xFF0277BD), // Sem 2 — azul cielo
  Color(0xFF1B5E20), // Sem 3 — verde bosque
  Color(0xFF006064), // Sem 4 — teal
  Color(0xFFBF360C), // Sem 5 — naranja quemado
  Color(0xFF4A148C), // Sem 6 — púrpura
  Color(0xFF880E4F), // Sem 7 — rosa oscuro
  Color(0xFF827717), // Sem 8 — oliva
  Color(0xFF37474F), // Sem 9 — azul grisáceo
  Color(0xFF3E2723), // Sem 10 — café
];

Color semesterColor(int semestre) {
  final idx = (semestre - 1).clamp(0, kSemesterColors.length - 1);
  return kSemesterColors[idx];
}
