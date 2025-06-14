import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'work_log_screen.dart';

class WorkerDetailsScreen extends StatelessWidget {
  final String userId;
  final Map<String, dynamic> userData;

  const WorkerDetailsScreen({
    super.key,
    required this.userId,
    required this.userData,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(userData['name'] ?? 'Detalles del Trabajador'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Información del trabajador
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Información Personal',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildInfoRow('Nombre', userData['name'] ?? 'No disponible'),
                    _buildInfoRow('Email', userData['email'] ?? 'No disponible'),
                    _buildInfoRow('Rol', userData['role'] == 'admin' ? 'Administrador' : 'Empleado'),
                    _buildInfoRow('Estado', userData['status'] == 'active' ? 'Activo' : 'Inactivo'),
                    _buildInfoRow('Departamento', userData['department'] ?? 'No disponible'),
                    _buildInfoRow('Cargo', userData['position'] ?? 'No disponible'),
                    _buildInfoRow(
                      'Fecha de Registro',
                      userData['createdAt'] is Timestamp
                          ? userData['createdAt'].toDate().toString().split('.')[0]
                          : 'No disponible',
                    ),
                    _buildInfoRow(
                      'Último Acceso',
                      userData['lastLogin'] is Timestamp
                          ? userData['lastLogin'].toDate().toString().split('.')[0]
                          : 'No disponible',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            // Botón para ver registros
            Center(
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => WorkLogScreen(
                        userId: userId,
                        companyName: userData['company']?.toString() ?? '',
                        employeeName: userData['name']?.toString() ?? '',
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.history),
                label: const Text('Ver Registros de Jornada'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }
} 