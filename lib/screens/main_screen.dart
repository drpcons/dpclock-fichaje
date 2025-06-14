import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'work_log_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geocoding/geocoding.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'login_screen.dart';

class MainScreen extends StatelessWidget {
  const MainScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('DRP Clock'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              try {
              await AuthService().logout();
              if (context.mounted) {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (context) => const LoginScreen()),
                    (Route<dynamic> route) => false,
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error al cerrar sesión: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Control de Jornada',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 40),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildControlButton(
                  context,
                  'Entrada',
                  Icons.login,
                  Colors.green,
                  () => _registerWorkEvent(context, 'entrada'),
                ),
                const SizedBox(width: 16),
                _buildControlButton(
                  context,
                  'Pausa',
                  Icons.pause,
                  Colors.orange,
                  () => _registerWorkEvent(context, 'pausa'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildControlButton(
                  context,
                  'Reanuda',
                  Icons.play_arrow,
                  Colors.blue,
                  () => _registerWorkEvent(context, 'reanudar'),
                ),
                const SizedBox(width: 16),
                _buildControlButton(
                  context,
                  'Salida',
                  Icons.logout,
                  Colors.red,
                  () => _registerWorkEvent(context, 'salida'),
                ),
              ],
            ),
            const SizedBox(height: 40),
            ElevatedButton.icon(
              onPressed: () async {
                final user = await AuthService().getCurrentUser();
                if (user != null && context.mounted) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => WorkLogScreen(
                        userId: user['id'],
                        companyName: user['company']?.toString() ?? '',
                        employeeName: user['name']?.toString() ?? '',
                      ),
                  ),
                );
                }
              },
              icon: const Icon(Icons.history),
              label: const Text('Ver Registro de Jornada'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlButton(
    BuildContext context,
    String label,
    IconData icon,
    Color color,
    VoidCallback onPressed,
  ) {
    return SizedBox(
      width: 120,
      height: 120,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 32),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _registerWorkEvent(BuildContext context, String eventType) async {
    try {
      print('Iniciando registro de fichaje: $eventType');
      
      // Verificar usuario actual
      final user = await AuthService().getCurrentUser();
      print('Usuario actual: $user');
      
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No hay usuario autenticado')),
        );
        return;
      }

      if (user['id'] == null || user['id'].toString().isEmpty) {
        print('Error: ID de usuario inválido');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error: ID de usuario inválido')),
        );
        return;
      }

      // Verificar permisos de ubicación solo si no es web
      if (!kIsWeb) {
      print('Verificando permisos de ubicación...');
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Por favor, activa el servicio de ubicación en tu dispositivo'),
          ),
        );
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Los permisos de ubicación son necesarios para registrar el fichaje'),
            ),
          );
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Los permisos de ubicación están permanentemente denegados. Por favor, actívalos en la configuración del dispositivo'),
          ),
        );
        return;
        }
      }

      // Obtener ubicación actual
      print('Obteniendo ubicación actual...');
      Position? position;
      try {
        position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        );
      } catch (e) {
        print('Error al obtener la ubicación: $e');
        if (kIsWeb) {
          // En web, continuar sin ubicación
          position = null;
        } else {
          rethrow;
        }
      }

      // Obtener dirección
      String? address;
      if (position != null) {
        try {
        List<Placemark> placemarks = await placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );
        if (placemarks.isNotEmpty) {
          Placemark place = placemarks[0];
            address = '${place.street}, ${place.locality}, ${place.country}';
        }
      } catch (e) {
        print('Error al obtener la dirección: $e');
          address = 'No se pudo obtener la dirección';
        }
      }

      // Registrar el evento en Firestore
      print('Registrando evento en Firestore...');
      await FirebaseFirestore.instance.collection('work_logs').add({
        'userId': user['id'],
        'userName': user['name'],
        'eventType': eventType,
        'timestamp': FieldValue.serverTimestamp(),
        'location': position != null ? GeoPoint(position.latitude, position.longitude) : null,
        'address': address,
        'deviceInfo': {
          'platform': kIsWeb ? 'web' : 'mobile',
          'userAgent': kIsWeb ? 'web' : 'mobile',
        },
      });

        ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$eventType registrada correctamente')),
        );
    } catch (e) {
      print('Error al registrar el evento: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al registrar el evento: $e')),
      );
    }
  }

  String _getEventTitle(String eventType) {
    switch (eventType) {
      case 'entrada':
        return 'Entrada';
      case 'pausa':
        return 'Pausa';
      case 'reanudar':
        return 'Reanudar';
      case 'salida':
        return 'Salida';
      default:
        return eventType;
    }
  }
} 