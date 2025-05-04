import 'dart:html' as html;
import 'dart:js' as js;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
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

  Future<Map<String, dynamic>> _getCurrentLocation() async {
    try {
      if (kIsWeb) {
        try {
          LoggerService.info('Intentando obtener ubicación en web');
          dynamic result;
          try {
            result = await js.context.callMethod('getGeoLocation');
            LoggerService.info('Respuesta de geolocalización web: ${result.toString()}');
          } catch (e) {
            LoggerService.error('Error al llamar a getGeoLocation', e);
            throw 'Error al obtener ubicación: $e';
          }

          if (result == null) {
            LoggerService.error('Resultado de geolocalización es null');
            throw 'No se pudo obtener la ubicación';
          }

          // Intentar acceder a las propiedades de manera segura
          dynamic latValue = result['latitude'];
          dynamic longValue = result['longitude'];

          LoggerService.info('Valores recibidos: lat=$latValue, long=$longValue');

          // Convertir a double de manera segura
          double? latitude = (latValue is num) ? latValue.toDouble() : null;
          double? longitude = (longValue is num) ? longValue.toDouble() : null;

          if (latitude == null || longitude == null || latitude == 0 || longitude == 0) {
            LoggerService.error('Valores de coordenadas inválidos: lat=$latValue, long=$longValue');
            throw 'Coordenadas inválidas o no disponibles';
          }

          String address = _formatCoordinates(latitude, longitude);
          
          try {
            LoggerService.info('Intentando obtener dirección para coordenadas: lat=$latitude, long=$longitude');
            final List<Placemark> placemarks = await placemarkFromCoordinates(
              latitude,
              longitude,
            );

            if (placemarks.isNotEmpty) {
              final place = placemarks.first;
              // Crear una lista de partes de la dirección, filtrando los valores nulos o vacíos
              final List<String> addressParts = [];
              
              if (place.street?.isNotEmpty ?? false) addressParts.add(place.street!);
              if (place.locality?.isNotEmpty ?? false) addressParts.add(place.locality!);
              if (place.postalCode?.isNotEmpty ?? false) addressParts.add(place.postalCode!);
              if (place.country?.isNotEmpty ?? false) addressParts.add(place.country!);
              
              if (addressParts.isNotEmpty) {
                address = addressParts.join(', ');
                LoggerService.info('Dirección obtenida exitosamente: $address');
              } else {
                LoggerService.info('No se pudo obtener una dirección legible, usando coordenadas');
              }
            } else {
              LoggerService.info('No se encontraron placemarks para las coordenadas');
            }
          } catch (e) {
            LoggerService.error('Error al obtener dirección, usando coordenadas como respaldo: $e');
            // Continuamos con las coordenadas como dirección
          }

          LoggerService.info('Ubicación web obtenida: lat=$latitude, long=$longitude, address=$address');
          return {
            'latitude': latitude,
            'longitude': longitude,
            'address': address
          };
        } catch (e) {
          LoggerService.error('Error al procesar ubicación web: $e');
          throw 'Error al obtener ubicación: $e';
        }
      } else {
        bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
        if (!serviceEnabled) {
          throw 'Los servicios de ubicación están desactivados';
        }

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

        final position = await Geolocator.getCurrentPosition();
        final List<Placemark> placemarks = await placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );

        String address = _formatCoordinates(position.latitude, position.longitude);
        if (placemarks.isNotEmpty) {
          final place = placemarks.first;
          final parts = [
            place.street,
            place.locality,
            place.postalCode,
            place.country,
          ].where((part) => part != null && part.isNotEmpty).toList();
          
          if (parts.isNotEmpty) {
            address = parts.join(', ');
          }
        }

        return {
          'latitude': position.latitude,
          'longitude': position.longitude,
          'address': address
        };
      }
    } catch (e) {
      LoggerService.error('Error general al obtener la ubicación: $e');
      throw 'Error al obtener ubicación: $e';
    }
  }

  Future<void> registrarFichaje(String tipo) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('Usuario no autenticado');

      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      final userData = userDoc.data() ?? {};

      Map<String, dynamic> locationData;
      try {
        locationData = await _getCurrentLocation();
      } catch (e) {
        LoggerService.error('Error al obtener ubicación para fichaje', e);
        locationData = {
          'latitude': 0.0,
          'longitude': 0.0,
          'address': 'Error al obtener ubicación'
        };
      }

      final registro = {
        'tipo': tipo,
        'fecha': FieldValue.serverTimestamp(),
        'userId': user.uid,
        'userEmail': user.email,
        'userName': '${userData['nombre'] ?? ''} ${userData['apellidos'] ?? ''}'.trim(),
        'latitude': locationData['latitude'],
        'longitude': locationData['longitude'],
        'locationAddress': locationData['address'],
      };

      await _firestore.collection('registros').add(registro);
      LoggerService.info('Registro de fichaje creado exitosamente: $tipo');
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