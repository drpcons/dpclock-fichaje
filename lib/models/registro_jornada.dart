import 'package:cloud_firestore/cloud_firestore.dart';

class RegistroJornada {
  final String id;
  final String tipo; // 'ENTRADA', 'PAUSA', 'SALIDA'
  final DateTime fecha;
  final String userId;
  final String userEmail;
  final String userName;
  final double? latitude;
  final double? longitude;
  final String? locationAddress;

  RegistroJornada({
    required this.id,
    required this.tipo,
    required this.fecha,
    required this.userId,
    required this.userEmail,
    required this.userName,
    this.latitude,
    this.longitude,
    this.locationAddress,
  });

  factory RegistroJornada.fromFirestore(Map<String, dynamic> data, String id) {
    DateTime parseFecha(dynamic value) {
      if (value is Timestamp) {
        return value.toDate();
      } else if (value is String) {
        return DateTime.parse(value);
      } else if (value is int) {
        return DateTime.fromMillisecondsSinceEpoch(value);
      }
      throw Exception('Formato de fecha no válido: $value (${value.runtimeType})');
    }

    try {
      // Procesar la dirección
      String? locationAddress = data['locationAddress'] as String?;
      if (locationAddress == null || locationAddress.isEmpty) {
        // Si no hay dirección, intentar construirla desde las coordenadas
        final latitude = data['latitude'];
        final longitude = data['longitude'];
        if (latitude != null && longitude != null) {
          locationAddress = 'Lat: ${latitude.toString()}, Long: ${longitude.toString()}';
        }
      }

      // Procesar coordenadas
      double? latitude;
      if (data['latitude'] is int) {
        latitude = (data['latitude'] as int).toDouble();
      } else if (data['latitude'] is double) {
        latitude = data['latitude'] as double;
      }

      double? longitude;
      if (data['longitude'] is int) {
        longitude = (data['longitude'] as int).toDouble();
      } else if (data['longitude'] is double) {
        longitude = data['longitude'] as double;
      }

      return RegistroJornada(
        id: id,
        tipo: data['tipo'] as String? ?? '',
        fecha: parseFecha(data['fecha']),
        userId: data['userId'] as String? ?? '',
        userEmail: data['userEmail'] as String? ?? '',
        userName: data['userName'] as String? ?? '',
        latitude: latitude,
        longitude: longitude,
        locationAddress: locationAddress,
      );
    } catch (e) {
      throw Exception('Error al convertir documento: $e\nDatos: $data');
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'tipo': tipo,
      'fecha': Timestamp.fromDate(fecha),
      'userId': userId,
      'userEmail': userEmail,
      'userName': userName,
      'latitude': latitude,
      'longitude': longitude,
      'locationAddress': locationAddress,
    };
  }
} 