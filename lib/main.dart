import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'config.dart';
import 'providers/data_provider.dart';
import 'providers/optimization_provider.dart';
import 'screens/home_screen.dart';
import 'screens/datos_screen.dart';
import 'screens/optimization_screen.dart';
import 'screens/schedule_screen.dart';
import 'screens/about_screen.dart';

// Claves de SharedPreferences — también usadas en about_screen.dart
const String kPrefHost = 'server_host';
const String kPrefPort = 'server_port';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Cargar host/puerto guardados (si el desarrollador los cambió antes)
  final prefs = await SharedPreferences.getInstance();
  AppConfig.serverHost = prefs.getString(kPrefHost) ?? AppConfig.serverHost;
  AppConfig.serverPort = prefs.getInt(kPrefPort)    ?? AppConfig.serverPort;

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => DataProvider()),
        ChangeNotifierProvider(create: (_) => OptimizationProvider()),
      ],
      child: const HorarioGeneticoApp(),
    ),
  );
}

class HorarioGeneticoApp extends StatelessWidget {
  const HorarioGeneticoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Horario Genético',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1565C0),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      home: const _MainShell(),
    );
  }
}

class _MainShell extends StatefulWidget {
  const _MainShell();

  @override
  State<_MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<_MainShell> {
  int _idx = 0;
  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      HomeScreen(
        onGoToDatos:     () => setState(() => _idx = 1),
        onGoToOptimizar: () => setState(() => _idx = 2),
      ),
      const DatosScreen(),
      const OptimizationScreen(),
      const ScheduleScreen(),
      const AboutScreen(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _idx, children: _screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _idx,
        onDestinationSelected: (i) => setState(() => _idx = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Inicio',
          ),
          NavigationDestination(
            icon: Icon(Icons.storage_outlined),
            selectedIcon: Icon(Icons.storage),
            label: 'Datos',
          ),
          NavigationDestination(
            icon: Icon(Icons.science_outlined),
            selectedIcon: Icon(Icons.science),
            label: 'Optimizar',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month),
            label: 'Horario',
          ),
          NavigationDestination(
            icon: Icon(Icons.info_outline),
            selectedIcon: Icon(Icons.info),
            label: 'Acerca de',
          ),
        ],
      ),
    );
  }
}
