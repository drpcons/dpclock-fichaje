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
      return RegistroJornada(
        id: id,
        tipo: data['tipo'] as String? ?? '',
        fecha: parseFecha(data['fecha']),
        userId: data['userId'] as String? ?? '',
        userEmail: data['userEmail'] as String? ?? '',
        userName: data['userName'] as String? ?? '',
        latitude: (data['latitude'] is int) 
          ? (data['latitude'] as int).toDouble()
          : data['latitude'] as double?,
        longitude: (data['longitude'] is int)
          ? (data['longitude'] as int).toDouble()
          : data['longitude'] as double?,
        locationAddress: data['locationAddress'] as String?,
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