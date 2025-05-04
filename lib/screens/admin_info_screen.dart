import 'package:flutter/material.dart';
import '../services/admin_service.dart';

class AdminInfoScreen extends StatelessWidget {
  const AdminInfoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final adminService = AdminService();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Información del Administrador'),
      ),
      body: FutureBuilder<Map<String, dynamic>?>(
        future: adminService.getAdminInfo(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text('Error: ${snapshot.error}'),
            );
          }

          final adminData = snapshot.data;
          if (adminData == null) {
            return const Center(
              child: Text('No se encontró información del administrador'),
            );
          }

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Administrador del Sistema',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ListTile(
                      leading: const Icon(Icons.email),
                      title: const Text('Email'),
                      subtitle: Text(adminData['email'] ?? 'No disponible'),
                    ),
                    if (adminData['nombre'] != null)
                      ListTile(
                        leading: const Icon(Icons.person),
                        title: const Text('Nombre'),
                        subtitle: Text(adminData['nombre']),
                      ),
                    if (adminData['apellidos'] != null)
                      ListTile(
                        leading: const Icon(Icons.person_outline),
                        title: const Text('Apellidos'),
                        subtitle: Text(adminData['apellidos']),
                      ),
                    ListTile(
                      leading: const Icon(Icons.verified_user),
                      title: const Text('ID'),
                      subtitle: Text(adminData['id'] ?? 'No disponible'),
                    ),
                    if (adminData['createdAt'] != null)
                      ListTile(
                        leading: const Icon(Icons.calendar_today),
                        title: const Text('Fecha de creación'),
                        subtitle: Text(
                          adminData['createdAt'].toDate().toString(),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
} 