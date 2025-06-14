import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminPanelScreen extends StatefulWidget {
  const AdminPanelScreen({super.key});

  @override
  _AdminPanelScreenState createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen> {
  List<Map<String, dynamic>> _employees = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadEmployees();
  }

  Future<void> _loadEmployees() async {
    try {
      final snapshot = await FirebaseFirestore.instance.collection('usuarios').get();
      setState(() {
        _employees = snapshot.docs.map((doc) {
          final data = doc.data();
          data['id'] = doc.id;
          print('Datos del empleado cargados: $data');
          return data;
        }).toList();
        _isLoading = false;
      });
    } catch (e) {
      print('Error al cargar empleados: $e');
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar empleados: $e')),
        );
      }
    }
  }

  void _showDeleteConfirmation(Map<String, dynamic> employee) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar eliminación'),
        content: Text('¿Estás seguro de que deseas eliminar a ${employee['nombre']}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () async {
              try {
                await FirebaseFirestore.instance
                    .collection('usuarios')
                    .doc(employee['id'])
                    .delete();
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Empleado eliminado correctamente')),
                  );
                  _loadEmployees();
                }
              } catch (e) {
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error al eliminar: $e')),
                  );
                }
              }
            },
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Panel de Administración'),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showEditDialog({}),
        child: const Icon(Icons.add),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Lista de Empleados',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildEmployeesTable(),
                ],
              ),
            ),
    );
  }

  Widget _buildEmployeesTable() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: const [
          DataColumn(label: Text('Nombre')),
          DataColumn(label: Text('Identificación')),
          DataColumn(label: Text('Email')),
          DataColumn(label: Text('Rol')),
          DataColumn(label: Text('Empresa')),
          DataColumn(label: Text('NIF Empresa')),
          DataColumn(label: Text('Acciones')),
        ],
        rows: _employees.map((employee) {
          return DataRow(
            cells: [
              DataCell(Text(employee['nombre'] ?? '')),
              DataCell(Text(employee['id'] ?? '')),
              DataCell(Text(employee['email'] ?? '')),
              DataCell(Text(employee['rol'] ?? '')),
              DataCell(Text(employee['empresa'] ?? '')),
              DataCell(Text(employee['nif_empresa'] ?? '')),
              DataCell(
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: () => _showEditDialog(employee),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete),
                      onPressed: () => _showDeleteConfirmation(employee),
                    ),
                  ],
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  void _showEditDialog(Map<String, dynamic> employee) {
    final nombreController = TextEditingController(text: employee['nombre'] ?? '');
    final emailController = TextEditingController(text: employee['email'] ?? '');
    final empresaController = TextEditingController(text: employee['empresa'] ?? '');
    final nifEmpresaController = TextEditingController(text: employee['nif_empresa'] ?? '');
    final nifController = TextEditingController(text: employee['nif'] ?? '');
    String selectedRole = employee['rol'] ?? 'trabajador';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(employee.isEmpty ? 'Nuevo Empleado' : 'Editar Empleado'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nombreController,
                decoration: const InputDecoration(labelText: 'Nombre'),
              ),
              TextField(
                controller: emailController,
                decoration: const InputDecoration(labelText: 'Email'),
              ),
              TextField(
                controller: empresaController,
                decoration: const InputDecoration(labelText: 'Empresa'),
              ),
              TextField(
                controller: nifEmpresaController,
                decoration: const InputDecoration(labelText: 'NIF Empresa'),
              ),
              TextField(
                controller: nifController,
                decoration: const InputDecoration(labelText: 'NIF'),
              ),
              DropdownButtonFormField<String>(
                value: selectedRole,
                items: const [
                  DropdownMenuItem(value: 'admin', child: Text('Administrador')),
                  DropdownMenuItem(value: 'trabajador', child: Text('Trabajador')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    selectedRole = value;
                  }
                },
                decoration: const InputDecoration(labelText: 'Rol'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () async {
              try {
                final data = {
                  'nombre': nombreController.text,
                  'email': emailController.text,
                  'rol': selectedRole,
                  'empresa': empresaController.text,
                  'nif_empresa': nifEmpresaController.text,
                  'nif': nifController.text,
                };

                if (employee.isEmpty) {
                  await FirebaseFirestore.instance.collection('usuarios').add(data);
                } else {
                  await FirebaseFirestore.instance
                      .collection('usuarios')
                      .doc(employee['id'])
                      .update(data);
                }

                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Empleado guardado correctamente')),
                  );
                  _loadEmployees();
                }
              } catch (e) {
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error al guardar: $e')),
                  );
                }
              }
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }
} 