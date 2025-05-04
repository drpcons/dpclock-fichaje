import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/registro_jornada.dart';
import 'auth_service.dart';
import 'logger_service.dart';

class JornadaService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final AuthService _authService = AuthService();

  String _formatCoordinates(double? latitude, double? longitude) {
    if (latitude == null || longitude == null) {
      return 'Ubicación no disponible';
    }
    return 'Lat: ${latitude.toStringAsFixed(6)}, Long: ${longitude.toStringAsFixed(6)}';
  }

  Future<String> _getAddressFromCoordinates(double latitude, double longitude) async {
    try {
      if (kIsWeb) {
        LoggerService.info('Obteniendo dirección usando OpenStreetMap en web');
        final url = 'https://nominatim.openstreetmap.org/reverse?format=json&lat=$latitude&lon=$longitude&accept-language=es';
        
        final response = await http.get(
          Uri.parse(url),
          headers: {
            'User-Agent': 'Fichaje App (https://github.com/drpcons/drpcons-fichaje)',
            'Accept': 'application/json'
          },
        );

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          final address = data['display_name'] as String?;
          if (address != null && address.isNotEmpty) {
            LoggerService.info('Dirección web obtenida: $address');
            return address;
          }
        }
      } else {
        LoggerService.info('Obteniendo dirección usando geocoding en móvil');
        final List<Placemark> placemarks = await placemarkFromCoordinates(latitude, longitude);
        
        if (placemarks.isNotEmpty) {
          final place = placemarks.first;
          final parts = [
            place.street,
            place.locality,
            place.postalCode,
            place.country,
          ].where((part) => part != null && part.isNotEmpty).toList();
          
          if (parts.isNotEmpty) {
            final address = parts.join(', ');
            LoggerService.info('Dirección móvil obtenida: $address');
            return address;
          }
        }
      }
      
      // Si no se pudo obtener la dirección, devolver las coordenadas formateadas
      return _formatCoordinates(latitude, longitude);
    } catch (e) {
      LoggerService.error('Error al obtener dirección: $e');
      return _formatCoordinates(latitude, longitude);
    }
  }

  Future<Map<String, dynamic>> _getCurrentLocation() async {
    try {
      // Verificar si los servicios de ubicación están habilitados
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw 'Los servicios de ubicación están desactivados';
      }

      // Verificar permisos de ubicación
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw 'Los permisos de ubicación fueron denegados';
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw 'Los permisos de ubicación están permanentemente denegados';
      }

      // Obtener la posición actual
      final position = await Geolocator.getCurrentPosition();
      final address = await _getAddressFromCoordinates(position.latitude, position.longitude);

      return {
        'latitude': position.latitude,
        'longitude': position.longitude,
        'address': address
      };
    } catch (e) {
      LoggerService.error('Error general al obtener la ubicación: $e');
      throw 'Error al obtener ubicación: $e';
    }
  }

  Future<void> registrarFichaje(String tipo, [Map<String, dynamic>? locationDataFromScreen]) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('Usuario no autenticado');

      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      final userData = userDoc.data() ?? {};

      Map<String, dynamic> locationData;
      try {
        // Si se proporcionan datos de ubicación desde la pantalla, usarlos
        if (locationDataFromScreen != null) {
          LoggerService.info('Usando datos de ubicación de la pantalla: $locationDataFromScreen');
          
          // Verificar y procesar la dirección
          String address;
          if (locationDataFromScreen['address'] == null || locationDataFromScreen['address'].toString().isEmpty) {
            // Si no hay dirección, usar las coordenadas
            address = _formatCoordinates(
              locationDataFromScreen['latitude'] as double,
              locationDataFromScreen['longitude'] as double
            );
            LoggerService.info('Usando coordenadas como dirección: $address');
          } else {
            address = locationDataFromScreen['address'] as String;
            LoggerService.info('Usando dirección proporcionada: $address');
          }
          
          locationData = {
            'latitude': locationDataFromScreen['latitude'] as double,
            'longitude': locationDataFromScreen['longitude'] as double,
            'address': address
          };
          
          LoggerService.info('Datos de ubicación procesados: $locationData');
        } else {
          // Si no, obtener la ubicación
          locationData = await _getCurrentLocation();
          LoggerService.info('Ubicación obtenida del servicio: $locationData');
        }

        // Verificación final de los datos
        if (locationData['address'] == null || locationData['address'].toString().isEmpty) {
          locationData['address'] = _formatCoordinates(
            locationData['latitude'] as double,
            locationData['longitude'] as double
          );
          LoggerService.info('Usando coordenadas como dirección por defecto: ${locationData['address']}');
        }

        final registro = {
          'tipo': tipo,
          'fecha': FieldValue.serverTimestamp(),
          'userId': user.uid,
          'userEmail': user.email,
          'userName': '${userData['nombre'] ?? ''} ${userData['apellidos'] ?? ''}'.trim(),
          'latitude': locationData['latitude'],
          'longitude': locationData['longitude'],
          'locationAddress': locationData['address']
        };

        LoggerService.info('Guardando registro con datos: $registro');
        
        // Guardar en Firestore
        final docRef = await _firestore.collection('registros').add(registro);
        
        // Verificar que se guardó correctamente
        final savedDoc = await docRef.get();
        final savedData = savedDoc.data();
        LoggerService.info('Registro guardado en Firestore: $savedData');
        
        final locationAddress = savedData?['locationAddress'] as String?;
        if (locationAddress == null || locationAddress.isEmpty) {
          LoggerService.error('La dirección no se guardó correctamente en Firestore');
          // Intentar actualizar el documento con la dirección
          await docRef.update({
            'locationAddress': locationData['address']
          });
        }

        LoggerService.info('Registro de fichaje creado exitosamente: $tipo');
      } catch (e) {
        LoggerService.error('Error al obtener/procesar ubicación para fichaje', e);
        throw Exception('Error al procesar la ubicación: $e');
      }
    } catch (e) {
      LoggerService.error('Error al registrar fichaje', e);
      throw Exception('Error al registrar el fichaje: $e');
    }
  }

  Stream<List<RegistroJornada>> getRegistros() {
    try {
      return _firestore
          .collection('registros')
          .orderBy('fecha', descending: true)
          .snapshots()
          .map((snapshot) {
            try {
              return snapshot.docs.map((doc) {
                try {
                  return RegistroJornada.fromFirestore(doc.data(), doc.id);
                } catch (e) {
                  LoggerService.error('Error al convertir documento a RegistroJornada', e);
                  throw Exception('Error al procesar registro: $e');
                }
              }).toList();
            } catch (e) {
              LoggerService.error('Error al procesar lista de registros', e);
              throw Exception('Error al procesar lista de registros: $e');
            }
          });
    } catch (e) {
      LoggerService.error('Error al obtener stream de registros', e);
      throw Exception('Error al obtener registros: $e');
    }
  }

  Stream<List<RegistroJornada>> getRegistrosUsuario(String userId) {
    try {
      if (userId.isEmpty) {
        LoggerService.error('ID de usuario vacío al obtener registros');
        throw Exception('ID de usuario no válido');
      }

      return _firestore
          .collection('registros')
          .where('userId', isEqualTo: userId)
          .orderBy('fecha', descending: true)
          .snapshots()
          .map((snapshot) {
            try {
              return snapshot.docs.map((doc) {
                try {
                  return RegistroJornada.fromFirestore(doc.data(), doc.id);
                } catch (e) {
                  LoggerService.error('Error al convertir documento a RegistroJornada', e);
                  throw Exception('Error al procesar registro: $e');
                }
              }).toList();
            } catch (e) {
              LoggerService.error('Error al procesar lista de registros', e);
              throw Exception('Error al procesar lista de registros: $e');
            }
          });
    } catch (e) {
      LoggerService.error('Error al obtener stream de registros de usuario', e);
      throw Exception('Error al obtener registros: $e');
    }
  }

  Future<void> iniciarJornada(String userId) async {
    try {
      final locationData = await _getCurrentLocation();
      
      await _firestore.collection('jornadas').add({
        'userId': userId,
        'inicio': FieldValue.serverTimestamp(),
        'inicioLatitud': locationData['latitude'],
        'inicioLongitud': locationData['longitude'],
        'inicioDireccion': locationData['address'],
        'fin': null,
        'finLatitud': null,
        'finLongitud': null,
        'finDireccion': null,
      });

      LoggerService.info('Jornada iniciada para el usuario: $userId');
    } catch (e) {
      LoggerService.error('Error al iniciar jornada', e);
      rethrow;
    }
  }

  Future<void> finalizarJornada(String jornadaId) async {
    try {
      final locationData = await _getCurrentLocation();
      
      await _firestore.collection('jornadas').doc(jornadaId).update({
        'fin': FieldValue.serverTimestamp(),
        'finLatitud': locationData['latitude'],
        'finLongitud': locationData['longitude'],
        'finDireccion': locationData['address'],
      });

      LoggerService.info('Jornada finalizada: $jornadaId');
    } catch (e) {
      LoggerService.error('Error al finalizar jornada', e);
      rethrow;
    }
  }

  Future<void> deleteRegistro(String id) async {
    try {
      await _firestore.collection('registros').doc(id).delete();
    } catch (e) {
      throw Exception('Error al eliminar el registro: $e');
    }
  }
} 