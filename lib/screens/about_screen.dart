import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config.dart';

const _kPrefHost = 'server_host';
const _kPrefPort = 'server_port';

class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  // ── Configuración del servidor ─────────────────────────────────────────────

  Future<void> _showServerConfig() async {
    final hostCtrl = TextEditingController(text: AppConfig.serverHost);
    final portCtrl = TextEditingController(text: '${AppConfig.serverPort}');

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.dns_outlined),
            SizedBox(width: 8),
            Text('Servidor API'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '📱 Emulador Android → 10.0.2.2\n'
                '📲 Dispositivo físico → IP LAN del PC\n'
                '    Ejemplo: 192.168.1.X',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSecondaryContainer,
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: hostCtrl,
              decoration: const InputDecoration(
                labelText: 'Host / IP',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.computer_outlined),
              ),
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: portCtrl,
              decoration: const InputDecoration(
                labelText: 'Puerto',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.settings_ethernet),
              ),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    final host = hostCtrl.text.trim();
    final port = int.tryParse(portCtrl.text.trim()) ?? AppConfig.serverPort;
    if (host.isEmpty) return;

    setState(() {
      AppConfig.serverHost = host;
      AppConfig.serverPort = port;
    });

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kPrefHost, host);
    await prefs.setInt(_kPrefPort, port);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Servidor actualizado → http://$host:$port'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            title: const Text('Acerca de'),
            backgroundColor: cs.primaryContainer,
          ),
          SliverPadding(
            padding: const EdgeInsets.all(20),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Logo / ícono
                Center(
                  child: Container(
                    width: 90, height: 90,
                    decoration: BoxDecoration(
                      color: cs.primary,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(Icons.schema, color: Colors.white, size: 52),
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: Text('Horario Genético',
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall!
                          .copyWith(fontWeight: FontWeight.bold)),
                ),
                Center(
                  child: Text('v1.0.0',
                      style: TextStyle(color: cs.outline)),
                ),
                const SizedBox(height: 28),

                _Section(title: 'Descripción', children: [
                  _InfoTile(
                    icon: Icons.info_outline,
                    text:
                        'Aplicación móvil que aplica algoritmos genéticos con '
                        'representación por permutación para generar y optimizar '
                        'horarios universitarios de forma automática.',
                  ),
                ]),

                _Section(title: 'Institución', children: [
                  _InfoTile(
                      icon: Icons.school,
                      text: 'Universidad de la Amazonia'),
                  _InfoTile(
                      icon: Icons.business,
                      text: 'Facultad de Ingeniería'),
                  _InfoTile(
                      icon: Icons.computer,
                      text: 'Ingeniería de Sistemas'),
                  _InfoTile(
                      icon: Icons.psychology,
                      text: 'Inteligencia Artificial — Algoritmos Genéticos'),
                  _InfoTile(
                      icon: Icons.person_pin,
                      text: 'Docente: Dr. Jesús Emilio Pinto'),
                ]),

                _Section(title: 'Integrantes', children: [
                  _PersonTile(name: 'Oscar Ivan Torres'),
                  _PersonTile(name: 'Andres Carrillo'),
                  _PersonTile(name: 'Mercy Florez'),
                ]),

                _Section(title: 'Tecnologías', children: [
                  _InfoTile(icon: Icons.phone_android, text: 'Flutter (Frontend móvil)'),
                  _InfoTile(icon: Icons.terminal, text: 'Python + FastAPI (Backend)'),
                  _InfoTile(icon: Icons.sync, text: 'WebSocket (Actualizaciones en tiempo real)'),
                  _InfoTile(icon: Icons.bar_chart, text: 'fl_chart (Visualización del AG)'),
                ]),

                _Section(title: 'Algoritmo Genético', children: [
                  _InfoTile(icon: Icons.shuffle, text: 'Codificación: Permutación'),
                  _InfoTile(icon: Icons.call_split, text: 'Cruzamiento: Order Crossover (OX)'),
                  _InfoTile(icon: Icons.swap_horiz, text: 'Mutación: Intercambio de posiciones'),
                  _InfoTile(icon: Icons.emoji_events, text: 'Elitismo: conserva los N mejores'),
                  _InfoTile(icon: Icons.sports_kabaddi, text: 'Selección: Torneo determinístico'),
                ]),

                // ── Configuración del servidor ─────────────────────────────
                _Section(title: 'Configuración de desarrollo', children: [
                  ListTile(
                    leading: Icon(Icons.dns_outlined, color: cs.primary, size: 22),
                    title: const Text('Servidor API'),
                    subtitle: Text(
                      'http://${AppConfig.serverHost}:${AppConfig.serverPort}',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                        color: cs.secondary,
                      ),
                    ),
                    trailing: Icon(Icons.edit_outlined, color: cs.outline, size: 18),
                    dense: true,
                    onTap: _showServerConfig,
                  ),
                ]),

                const SizedBox(height: 16),
                Center(
                  child: Text('© 2025 — Universidad de la Amazonia',
                      style: TextStyle(color: cs.outline, fontSize: 12)),
                ),
                const SizedBox(height: 8),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _Section({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(title,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium!
                  .copyWith(color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.bold)),
        ),
        Card(
          margin: const EdgeInsets.only(bottom: 20),
          child: Column(children: children),
        ),
      ],
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoTile({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) => ListTile(
        leading: Icon(icon,
            color: Theme.of(context).colorScheme.primary, size: 20),
        title: Text(text),
        dense: true,
      );
}

class _PersonTile extends StatelessWidget {
  final String name;
  const _PersonTile({required this.name});

  @override
  Widget build(BuildContext context) => ListTile(
        leading: CircleAvatar(
          backgroundColor:
              Theme.of(context).colorScheme.primaryContainer,
          child: Text(name[0],
              style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.bold)),
        ),
        title: Text(name),
        dense: true,
      );
}
