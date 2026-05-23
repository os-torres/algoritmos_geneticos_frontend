import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../models/materia.dart';
import '../models/profesor.dart';
import '../models/salon.dart';
import '../models/franja_horaria.dart';
import '../providers/data_provider.dart';

class DatosScreen extends StatefulWidget {
  const DatosScreen({super.key});

  @override
  State<DatosScreen> createState() => _DatosScreenState();
}

class _DatosScreenState extends State<DatosScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 4, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.read<DataProvider>().materias.isEmpty) {
        context.read<DataProvider>().cargarTodo();
      }
    });
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestión de Datos'),
        bottom: TabBar(
          controller: _tab,
          tabs: const [
            Tab(icon: Icon(Icons.book), text: 'Materias'),
            Tab(icon: Icon(Icons.person), text: 'Profesores'),
            Tab(icon: Icon(Icons.meeting_room), text: 'Salones'),
            Tab(icon: Icon(Icons.schedule), text: 'Franjas'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.upload_file_outlined),
            tooltip: 'Importar pensum desde JSON',
            onPressed: () => _importarJson(context),
          ),
          IconButton(
            icon: const Icon(Icons.restore),
            tooltip: 'Restaurar datos de muestra',
            onPressed: () => _confirmReset(context),
          ),
        ],
      ),
      body: TabBarView(
        controller: _tab,
        children: const [
          _MateriasTab(),
          _ProfesoresTab(),
          _SalonesTab(),
          _FranjasTab(),
        ],
      ),
    );
  }

  void _confirmReset(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Restaurar datos'),
        content: const Text(
            '¿Restaurar los datos de muestra? Se perderán los cambios actuales.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar')),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              context.read<DataProvider>().resetearDatos();
            },
            child: const Text('Restaurar'),
          ),
        ],
      ),
    );
  }

  Future<void> _importarJson(BuildContext context) async {
    // 1. Seleccionar archivo JSON
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
      withData: true,
    );
    if (result == null || result.files.single.bytes == null) return;

    final bytes = result.files.single.bytes!;
    final texto = utf8.decode(bytes);

    // 2. Parsear JSON
    Map<String, dynamic> datos;
    try {
      datos = jsonDecode(texto) as Map<String, dynamic>;
    } catch (_) {
      if (!context.mounted) return;
      _mostrarError(context, 'El archivo no es un JSON válido.');
      return;
    }

    // 3. Preguntar acción si no está en el JSON
    final accion = datos['accion'] as String? ?? 'reemplazar';

    if (!context.mounted) return;
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        icon: Icon(
          accion == 'reemplazar'
              ? Icons.swap_horiz_rounded
              : Icons.add_circle_outline,
          color: accion == 'reemplazar' ? Colors.orange : Colors.blue,
          size: 36,
        ),
        title: Text(accion == 'reemplazar'
            ? 'Reemplazar datos'
            : 'Agregar datos'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(accion == 'reemplazar'
                ? '¿Reemplazar TODOS los datos actuales con el archivo "${result.files.single.name}"?'
                : '¿Agregar los datos de "${result.files.single.name}" al pensum existente?'),
            const SizedBox(height: 8),
            Text(
              'Materias en el archivo: ${(datos["materias"] as List?)?.length ?? 0}\n'
              'Profesores en el archivo: ${(datos["profesores"] as List?)?.length ?? 0}',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          FilledButton(
            style: accion == 'reemplazar'
                ? FilledButton.styleFrom(backgroundColor: Colors.orange)
                : null,
            onPressed: () => Navigator.pop(context, true),
            child: Text(accion == 'reemplazar' ? 'Reemplazar' : 'Agregar'),
          ),
        ],
      ),
    );

    if (confirmado != true || !context.mounted) return;

    // 4. Enviar al backend
    final dp = context.read<DataProvider>();
    final resImport = await dp.importarDesdeJson(datos);

    if (!context.mounted) return;
    if (resImport == null) {
      _mostrarError(context, dp.error ?? 'Error al importar');
      return;
    }

    // 5. Mostrar resultado
    final imp = resImport['importado'] as Map<String, dynamic>? ?? {};
    final sem = (resImport['resumen']?['semestres_disponibles'] as List?)
        ?.join(', ') ?? '-';
    final salAuto = imp['salones_auto_creados'] as int? ?? 0;
    final totalSal = imp['total_salones'] as int? ?? 0;
    final totalRan = imp['total_ranuras'] as int? ?? 0;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: Colors.green.shade700,
      content: Text(
        '✓ ${imp["materias_importadas"]} materias · '
        '${imp["profesores_importados"]} profesores'
        '${salAuto > 0 ? ' · $salAuto salones auto-creados ($totalSal total, $totalRan ranuras)' : ''}. '
        'Semestres: $sem',
      ),
      duration: const Duration(seconds: 6),
    ));
  }

  void _mostrarError(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: Theme.of(context).colorScheme.error,
      content: Text(msg),
    ));
  }
}

// ============================================================
// TAB MATERIAS
// ============================================================

class _MateriasTab extends StatelessWidget {
  const _MateriasTab();

  @override
  Widget build(BuildContext context) {
    final dp = context.watch<DataProvider>();

    return Scaffold(
      body: dp.loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: dp.materias.length,
              itemBuilder: (_, i) {
                final m = dp.materias[i];
                // Profesores que dictan esta materia
                final profsMat = dp.profesores
                    .where((p) => p.materiasIds.contains(m.id))
                    .toList();
                final sinProf = profsMat.isEmpty;

                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: _groupColor(m.grupo).withAlpha(38),
                      child: Text(m.grupo,
                          style: TextStyle(
                              color: _groupColor(m.grupo),
                              fontWeight: FontWeight.bold)),
                    ),
                    title: Row(
                      children: [
                        Expanded(
                          child: Text(m.nombre,
                              overflow: TextOverflow.ellipsis),
                        ),
                        if (sinProf)
                          const Tooltip(
                            message: 'Sin docente asignado',
                            child: Icon(Icons.warning_amber_rounded,
                                color: Colors.orange, size: 18),
                          ),
                      ],
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Sem. ${m.semestre} · ${m.horasSemanales}h/sem '
                          '(${m.bloques.map((b) => '${b}h').join('+')}) · ${m.creditos} cr.',
                        ),
                        Text(
                          sinProf
                              ? 'Sin docente asignado'
                              : profsMat.map((p) => p.nombre).join(', '),
                          style: TextStyle(
                            fontSize: 11,
                            color: sinProf
                                ? Colors.orange.shade700
                                : Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                    isThreeLine: true,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit_outlined),
                          onPressed: () => _showMateriaForm(context, materia: m),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline),
                          color: Theme.of(context).colorScheme.error,
                          onPressed: () => _confirmDelete(
                              context, 'materia "${m.nombre}"',
                              () => dp.eliminarMateria(m.id)),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('Agregar'),
        onPressed: () => _showMateriaForm(context),
      ),
    );
  }

  void _showMateriaForm(BuildContext context, {Materia? materia}) {
    final nombreCtrl = TextEditingController(text: materia?.nombre ?? '');
    final grupoCtrl  = TextEditingController(text: materia?.grupo ?? '');
    int semestre     = materia?.semestre ?? 1;
    int creditos     = materia?.creditos ?? 3;
    List<int> bloques = List<int>.from(materia?.bloques ?? [2, 2]);
    final formKey    = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 16, right: 16, top: 20),
        child: StatefulBuilder(
          builder: (ctx, setSt) => Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(materia == null ? 'Nueva materia' : 'Editar materia',
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: nombreCtrl,
                    decoration: const InputDecoration(
                        labelText: 'Nombre', border: OutlineInputBorder()),
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? 'Requerido' : null,
                  ),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(
                      child: TextFormField(
                        controller: grupoCtrl,
                        decoration: const InputDecoration(
                            labelText: 'Grupo (A, B, C…)',
                            border: OutlineInputBorder()),
                        validator: (v) =>
                            v == null || v.trim().isEmpty ? 'Requerido' : null,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        value: semestre,
                        decoration: const InputDecoration(
                            labelText: 'Semestre',
                            border: OutlineInputBorder()),
                        items: List.generate(10, (i) => i + 1)
                            .map((s) => DropdownMenuItem(
                                value: s, child: Text('Semestre $s')))
                            .toList(),
                        onChanged: (v) => setSt(() => semestre = v!),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 16),
                  // ── Bloques de horas ──
                  Row(
                    children: [
                      const Text('Bloques de horas/sem:',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                      const Spacer(),
                      Text(
                        '${bloques.fold(0, (s, b) => s + b)}h total',
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      for (int i = 0; i < bloques.length; i++)
                        InputChip(
                          label: Text('${bloques[i]}h'),
                          onDeleted: bloques.length > 1
                              ? () => setSt(() => bloques.removeAt(i))
                              : null,
                          onPressed: () => setSt(() {
                            bloques[i] = (bloques[i] % 4) + 1;
                          }),
                          tooltip: 'Toca para cambiar horas',
                        ),
                      ActionChip(
                        avatar: const Icon(Icons.add, size: 16),
                        label: const Text('Agregar'),
                        onPressed: bloques.length < 7
                            ? () => setSt(() => bloques.add(1))
                            : null,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Toca un bloque para cambiar sus horas (1–4h). '
                    'Cada bloque es una sesión en un día diferente.',
                    style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context).colorScheme.outline),
                  ),
                  const SizedBox(height: 12),

                  // ── Docente asignado (solo lectura) ──────────────────
                  Builder(builder: (innerCtx) {
                    final dp2 = context.read<DataProvider>();
                    if (materia == null) {
                      // Materia nueva: no tiene ID aún
                      return Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.info_outline,
                                size: 16, color: Colors.blueGrey),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Tras crear la materia, ve a la pestaña '
                                '"Profesores" y asígnala al docente correspondiente.',
                                style: TextStyle(fontSize: 11),
                              ),
                            ),
                          ],
                        ),
                      );
                    }
                    // Materia existente: mostrar docentes asignados
                    final profs = dp2.profesores
                        .where((p) => p.materiasIds.contains(materia.id))
                        .map((p) => p.nombre)
                        .toList();
                    final sinProf = profs.isEmpty;
                    return Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: sinProf
                            ? Colors.orange.shade50
                            : Colors.green.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: sinProf ? Colors.orange : Colors.green,
                          width: 0.8,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            sinProf
                                ? Icons.warning_amber_rounded
                                : Icons.person,
                            size: 16,
                            color: sinProf
                                ? Colors.orange.shade700
                                : Colors.green.shade700,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              sinProf
                                  ? 'Sin docente asignado — ve a "Profesores" y asigna esta materia'
                                  : 'Docente(s): ${profs.join(', ')}',
                              style: TextStyle(
                                fontSize: 11,
                                color: sinProf
                                    ? Colors.orange.shade800
                                    : Colors.green.shade800,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 12),

                  Row(children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Créditos: $creditos'),
                          Slider(
                            value: creditos.toDouble(),
                            min: 1, max: 10,
                            divisions: 9,
                            onChanged: (v) => setSt(() => creditos = v.toInt()),
                          ),
                        ],
                      ),
                    ),
                  ]),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () async {
                      if (!formKey.currentState!.validate()) return;
                      final body = {
                        'nombre': nombreCtrl.text.trim(),
                        'grupo': grupoCtrl.text.trim().toUpperCase(),
                        'semestre': semestre,
                        'creditos': creditos,
                        'bloques': bloques,
                      };
                      final dp = context.read<DataProvider>();
                      final ok = materia == null
                          ? await dp.agregarMateria(body)
                          : await dp.editarMateria(materia.id, body);
                      if (ctx.mounted) Navigator.pop(ctx);
                      if (!ok && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(dp.error ?? 'Error')));
                      }
                    },
                    child: Text(materia == null ? 'Agregar' : 'Guardar'),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// TAB PROFESORES
// ============================================================

class _ProfesoresTab extends StatelessWidget {
  const _ProfesoresTab();

  @override
  Widget build(BuildContext context) {
    final dp = context.watch<DataProvider>();

    return Scaffold(
      body: dp.loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: dp.profesores.length,
              itemBuilder: (_, i) {
                final p = dp.profesores[i];
                final materiaNames = dp.materias
                    .where((m) => p.materiasIds.contains(m.id))
                    .map((m) => m.nombre)
                    .join(', ');
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  child: ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.person)),
                    title: Text(p.nombre),
                    subtitle: Text(
                        materiaNames.isEmpty ? 'Sin materias asignadas' : materiaNames,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit_outlined),
                          onPressed: () =>
                              _showProfesorForm(context, profesor: p),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline),
                          color: Theme.of(context).colorScheme.error,
                          onPressed: () => _confirmDelete(
                              context, 'profesor "${p.nombre}"',
                              () => dp.eliminarProfesor(p.id)),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('Agregar'),
        onPressed: () => _showProfesorForm(context),
      ),
    );
  }

  void _showProfesorForm(BuildContext context, {Profesor? profesor}) {
    final nombreCtrl   = TextEditingController(text: profesor?.nombre ?? '');
    final buscarCtrl   = TextEditingController();
    final selectedMats = <int>{...?profesor?.materiasIds};
    final formKey      = GlobalKey<FormState>();
    final dp           = context.read<DataProvider>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      // useSafeArea evita que el teclado o la barra de estado lo rompan
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      // DraggableScrollableSheet permite expandir el panel si hay muchas materias
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.75,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        builder: (sheetCtx, scrollCtrl) => Padding(
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
              left: 16, right: 16, top: 8),
          child: StatefulBuilder(
            builder: (ctx, setSt) {
              // Filtrar materias por búsqueda
              final query = buscarCtrl.text.toLowerCase();
              final materiasFiltradas = query.isEmpty
                  ? dp.materias
                  : dp.materias
                      .where((m) => m.nombre.toLowerCase().contains(query))
                      .toList();

              return Form(
                key: formKey,
                child: CustomScrollView(
                  controller: scrollCtrl,
                  slivers: [
                    SliverToBoxAdapter(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Tirador visual
                          Center(
                            child: Container(
                              width: 40, height: 4,
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade300,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                          Text(
                            profesor == null
                                ? 'Nuevo profesor'
                                : 'Editar profesor',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 16),
                          // Campo nombre
                          TextFormField(
                            controller: nombreCtrl,
                            decoration: const InputDecoration(
                                labelText: 'Nombre',
                                border: OutlineInputBorder()),
                            validator: (v) =>
                                v == null || v.trim().isEmpty
                                    ? 'Requerido'
                                    : null,
                          ),
                          const SizedBox(height: 16),
                          // Encabezado de materias + contador
                          Row(
                            children: [
                              const Text('Materias que dicta:',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w600)),
                              const Spacer(),
                              if (selectedMats.isNotEmpty)
                                Chip(
                                  label: Text(
                                      '${selectedMats.length} seleccionada(s)',
                                      style: const TextStyle(fontSize: 11)),
                                  padding: EdgeInsets.zero,
                                  visualDensity: VisualDensity.compact,
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          // Buscador de materias
                          TextField(
                            controller: buscarCtrl,
                            decoration: InputDecoration(
                              hintText: 'Buscar materia…',
                              prefixIcon: const Icon(Icons.search, size: 20),
                              suffixIcon: buscarCtrl.text.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear, size: 18),
                                      onPressed: () =>
                                          setSt(() => buscarCtrl.clear()),
                                    )
                                  : null,
                              isDense: true,
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8)),
                              contentPadding: const EdgeInsets.symmetric(
                                  vertical: 8, horizontal: 12),
                            ),
                            onChanged: (_) => setSt(() {}),
                          ),
                          const SizedBox(height: 8),
                        ],
                      ),
                    ),

                    // Lista de chips desplazable (ocupa el espacio restante)
                    SliverPadding(
                      padding: const EdgeInsets.only(bottom: 8),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (_, i) {
                            final m = materiasFiltradas[i];
                            final sel = selectedMats.contains(m.id);
                            return CheckboxListTile(
                              dense: true,
                              visualDensity: VisualDensity.compact,
                              value: sel,
                              title: Text(m.nombre,
                                  style: const TextStyle(fontSize: 13)),
                              subtitle: Text(
                                  'Sem. ${m.semestre} · Grupo ${m.grupo}',
                                  style: const TextStyle(fontSize: 11)),
                              secondary: CircleAvatar(
                                radius: 14,
                                backgroundColor:
                                    _groupColor(m.grupo).withAlpha(38),
                                child: Text(m.grupo,
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: _groupColor(m.grupo),
                                        fontWeight: FontWeight.bold)),
                              ),
                              onChanged: (v) => setSt(() =>
                                  v! ? selectedMats.add(m.id)
                                     : selectedMats.remove(m.id)),
                            );
                          },
                          childCount: materiasFiltradas.length,
                        ),
                      ),
                    ),

                    // Botón fijo al final
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 8, bottom: 16),
                        child: FilledButton(
                          onPressed: () async {
                            if (!formKey.currentState!.validate()) return;
                            final body = {
                              'nombre': nombreCtrl.text.trim(),
                              'materias_ids': selectedMats.toList(),
                              'franjas_preferidas':
                                  profesor?.franjasPreferidas ?? [],
                            };
                            final ok = profesor == null
                                ? await dp.agregarProfesor(body)
                                : await dp.editarProfesor(
                                    profesor.id, body);
                            if (ctx.mounted) Navigator.pop(ctx);
                            if (!ok && context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                      content: Text(dp.error ?? 'Error')));
                            }
                          },
                          child: Text(
                              profesor == null ? 'Agregar' : 'Guardar'),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

// ============================================================
// TAB SALONES
// ============================================================

class _SalonesTab extends StatelessWidget {
  const _SalonesTab();

  @override
  Widget build(BuildContext context) {
    final dp = context.watch<DataProvider>();

    return Scaffold(
      body: dp.loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: dp.salones.length + 1, // +1 para el banner informativo
              itemBuilder: (_, i) {
                // Banner explicativo al inicio de la lista
                if (i == 0) {
                  return Card(
                    color: Colors.blue.shade50,
                    margin: const EdgeInsets.only(bottom: 8),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.auto_awesome,
                                  size: 16, color: Colors.blue),
                              SizedBox(width: 6),
                              Text('Asignación automática de aulas',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13)),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'El Algoritmo Genético asigna los salones '
                            'automáticamente. Garantiza que:\n'
                            '• Ningún salón tenga dos clases al mismo tiempo.\n'
                            '• Las sesiones se distribuyen entre todos los salones disponibles.\n\n'
                            'No necesitas asignar un salón manualmente a cada docente. '
                            'Solo define los salones disponibles con su capacidad.',
                            style: TextStyle(
                                fontSize: 12,
                                color: Colors.blueGrey.shade700,
                                height: 1.4),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final s = dp.salones[i - 1]; // offset por el banner
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  child: ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.meeting_room)),
                    title: Text(s.nombre),
                    subtitle: Text('Capacidad: ${s.capacidad} estudiantes'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit_outlined),
                          onPressed: () => _showSalonForm(context, salon: s),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline),
                          color: Theme.of(context).colorScheme.error,
                          onPressed: () => _confirmDelete(
                              context, 'salón "${s.nombre}"',
                              () => dp.eliminarSalon(s.id)),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('Agregar'),
        onPressed: () => _showSalonForm(context),
      ),
    );
  }

  void _showSalonForm(BuildContext context, {Salon? salon}) {
    final nombreCtrl = TextEditingController(text: salon?.nombre ?? '');
    int capacidad    = salon?.capacidad ?? 30;
    final formKey    = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 16, right: 16, top: 20),
        child: StatefulBuilder(
          builder: (ctx, setSt) => Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(salon == null ? 'Nuevo salón' : 'Editar salón',
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 16),
                TextFormField(
                  controller: nombreCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Nombre (Ej: Aula 101)',
                      border: OutlineInputBorder()),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Requerido' : null,
                ),
                const SizedBox(height: 12),
                Text('Capacidad: $capacidad estudiantes'),
                Slider(
                  value: capacidad.toDouble(),
                  min: 10, max: 200, divisions: 19,
                  label: '$capacidad',
                  onChanged: (v) => setSt(() => capacidad = v.toInt()),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () async {
                    if (!formKey.currentState!.validate()) return;
                    final dp   = context.read<DataProvider>();
                    final body = {'nombre': nombreCtrl.text.trim(), 'capacidad': capacidad};
                    final ok   = salon == null
                        ? await dp.agregarSalon(body)
                        : await dp.editarSalon(salon.id, body);
                    if (ctx.mounted) Navigator.pop(ctx);
                    if (!ok && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(dp.error ?? 'Error')));
                    }
                  },
                  child: Text(salon == null ? 'Agregar' : 'Guardar'),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// TAB FRANJAS
// ============================================================

class _FranjasTab extends StatelessWidget {
  const _FranjasTab();

  static const _dias = ['Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes',
      'Sábado', 'Domingo'];

  @override
  Widget build(BuildContext context) {
    final dp = context.watch<DataProvider>();

    // Agrupar por día
    final Map<String, List<FranjaHoraria>> porDia = {};
    for (final f in dp.franjas) {
      porDia.putIfAbsent(f.dia, () => []).add(f);
    }

    return Scaffold(
      body: dp.loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(8),
              children: [
                for (final dia in _dias)
                  if (porDia.containsKey(dia)) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Text(dia,
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                    ),
                    for (final f in porDia[dia]!)
                      Card(
                        margin: const EdgeInsets.symmetric(vertical: 3),
                        child: ListTile(
                          leading: const Icon(Icons.access_time),
                          title: Text('${f.horaInicio} – ${f.horaFin}'),
                          subtitle: Text('ID ${f.id}'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit_outlined),
                                onPressed: () =>
                                    _showFranjaForm(context, franja: f),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline),
                                color: Theme.of(context).colorScheme.error,
                                onPressed: () => _confirmDelete(
                                    context,
                                    'franja ${f.dia} ${f.horaInicio}',
                                    () => dp.eliminarFranja(f.id)),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('Agregar'),
        onPressed: () => _showFranjaForm(context),
      ),
    );
  }

  void _showFranjaForm(BuildContext context, {FranjaHoraria? franja}) {
    String dia          = franja?.dia ?? 'Lunes';
    final inicioCtrl    = TextEditingController(text: franja?.horaInicio ?? '07:00');
    final finCtrl       = TextEditingController(text: franja?.horaFin ?? '09:00');
    final formKey       = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 16, right: 16, top: 20),
        child: StatefulBuilder(
          builder: (ctx, setSt) => Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(franja == null ? 'Nueva franja' : 'Editar franja',
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: dia,
                  decoration: const InputDecoration(
                      labelText: 'Día', border: OutlineInputBorder()),
                  items: _dias
                      .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                      .toList(),
                  onChanged: (v) => setSt(() => dia = v!),
                ),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: TextFormField(
                      controller: inicioCtrl,
                      decoration: const InputDecoration(
                          labelText: 'Inicio (HH:MM)',
                          border: OutlineInputBorder()),
                      validator: (v) =>
                          RegExp(r'^\d{2}:\d{2}$').hasMatch(v ?? '')
                              ? null
                              : 'Formato HH:MM',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: finCtrl,
                      decoration: const InputDecoration(
                          labelText: 'Fin (HH:MM)',
                          border: OutlineInputBorder()),
                      validator: (v) =>
                          RegExp(r'^\d{2}:\d{2}$').hasMatch(v ?? '')
                              ? null
                              : 'Formato HH:MM',
                    ),
                  ),
                ]),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () async {
                    if (!formKey.currentState!.validate()) return;
                    final dp   = context.read<DataProvider>();
                    final body = {
                      'dia': dia,
                      'hora_inicio': inicioCtrl.text.trim(),
                      'hora_fin': finCtrl.text.trim(),
                    };
                    final ok = franja == null
                        ? await dp.agregarFranja(body)
                        : await dp.editarFranja(franja.id, body);
                    if (ctx.mounted) Navigator.pop(ctx);
                    if (!ok && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(dp.error ?? 'Error')));
                    }
                  },
                  child: Text(franja == null ? 'Agregar' : 'Guardar'),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// Helpers compartidos
// ============================================================

Color _groupColor(String grupo) {
  const colors = {
    'A': Color(0xFF1565C0),
    'B': Color(0xFF2E7D32),
    'C': Color(0xFFE65100),
    'D': Color(0xFF6A1B9A),
  };
  return colors[grupo] ?? const Color(0xFF455A64);
}

void _confirmDelete(
    BuildContext context, String label, Future<bool> Function() onConfirm) {
  showDialog(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('Confirmar eliminación'),
      content: Text('¿Eliminar $label?'),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar')),
        FilledButton(
          style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error),
          onPressed: () async {
            Navigator.pop(context);
            await onConfirm();
          },
          child: const Text('Eliminar'),
        ),
      ],
    ),
  );
}
