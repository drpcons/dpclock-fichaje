import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../services/jornada_service.dart';
import '../services/logger_service.dart';

class FicharScreen extends StatefulWidget {
  const FicharScreen({super.key});

  @override
  State<FicharScreen> createState() => _FicharScreenState();
}

class _FicharScreenState extends State<FicharScreen> {
  Position? _currentPosition;
  String? _currentAddress;
  String? _locationError;
  bool _isLoading = false;

  Future<String?> _getAddressFromCoordinates(double latitude, double longitude) async {
    try {
      LoggerService.info('Intentando obtener dirección para coordenadas: $latitude, $longitude');
      final url = 'https://nominatim.openstreetmap.org/reverse?format=json&lat=$latitude&lon=$longitude&accept-language=es';
      LoggerService.info('URL de geocodificación: $url');
      
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'User-Agent': 'Fichaje App (https://github.com/drpcons/drpcons-fichaje)',
          'Accept': 'application/json'
        },
      );

      LoggerService.info('Respuesta del servidor: ${response.statusCode}');
      LoggerService.info('Contenido de la respuesta: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final address = data['display_name'] as String?;
        if (address != null && address.isNotEmpty) {
          LoggerService.info('Dirección obtenida: $address');
          return address;
        } else {
          LoggerService.info('No se encontró dirección en la respuesta');
          return _formatCoordinates(latitude, longitude);
        }
      } else {
        LoggerService.error('Error en la respuesta del servidor: ${response.statusCode}');
        return _formatCoordinates(latitude, longitude);
      }
    } catch (e) {
      LoggerService.error('Error al obtener dirección: $e');
      return _formatCoordinates(latitude, longitude);
    }
  }

  Future<void> _updateLocation() async {
    setState(() {
      _isLoading = true;
      _locationError = null;
      _currentAddress = null;
    });

    try {
      final position = await Geolocator.getCurrentPosition();
      LoggerService.info('Posición obtenida: ${position.latitude}, ${position.longitude}');
      
      final address = await _getAddressFromCoordinates(position.latitude, position.longitude);
      LoggerService.info('Dirección obtenida en _updateLocation: $address');

      setState(() {
        _currentPosition = position;
        _currentAddress = address;
        _isLoading = false;
      });
      
      LoggerService.info('Estado actualizado - Dirección actual: $_currentAddress');
    } catch (e) {
      LoggerService.error('Error al obtener ubicación: $e');
      setState(() {
        _locationError = 'Error al obtener ubicación: $e';
        _isLoading = false;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _updateLocation();
  }

  Widget _buildLocationWidget() {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.all(16.0),
        child: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_locationError != null) {
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text(
              _locationError!,
              style: const TextStyle(color: Colors.red),
            ),
            TextButton.icon(
              onPressed: _updateLocation,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      );
    }

    if (_currentPosition != null) {
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Text(
              'Ubicación actual:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              _currentAddress ?? 'Obteniendo dirección...',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14),
            ),
            TextButton.icon(
              onPressed: _updateLocation,
              icon: const Icon(Icons.refresh),
              label: const Text('Actualizar ubicación'),
            ),
          ],
        ),
      );
    }

    return const Padding(
      padding: EdgeInsets.all(16.0),
      child: Text(
        'Obteniendo ubicación...',
        style: TextStyle(fontStyle: FontStyle.italic),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Fichar'),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildLocationWidget(),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: _isLoading ? null : () async {
                        try {
                          if (_currentPosition == null) {
                            throw Exception('No hay ubicación disponible');
                          }

                          if (_currentAddress == null) {
                            throw Exception('La dirección no está disponible');
                          }
                          
                          final locationData = {
                            'latitude': _currentPosition!.latitude,
                            'longitude': _currentPosition!.longitude,
                            'address': _currentAddress
                          };

                          LoggerService.info('Enviando datos de ubicación para fichaje: $locationData');
                          
                          await JornadaService().registrarFichaje('ENTRADA', locationData);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Entrada registrada correctamente')),
                            );
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error al registrar entrada: $e')),
                            );
                          }
                        }
                      },
                      child: const Text(
                        'Entrada',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: _isLoading ? null : () async {
                        try {
                          if (_currentPosition == null) {
                            throw Exception('No hay ubicación disponible');
                          }

                          if (_currentAddress == null) {
                            throw Exception('La dirección no está disponible');
                          }
                          
                          final locationData = {
                            'latitude': _currentPosition!.latitude,
                            'longitude': _currentPosition!.longitude,
                            'address': _currentAddress
                          };

                          LoggerService.info('Enviando datos de ubicación para fichaje: $locationData');
                          
                          await JornadaService().registrarFichaje('PAUSA', locationData);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Pausa registrada correctamente')),
                            );
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error al registrar pausa: $e')),
                            );
                          }
                        }
                      },
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.pause, color: Colors.white),
                          SizedBox(width: 8),
                          Text(
                            'Pausa',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: _isLoading ? null : () async {
                        try {
                          if (_currentPosition == null) {
                            throw Exception('No hay ubicación disponible');
                          }

                          if (_currentAddress == null) {
                            throw Exception('La dirección no está disponible');
                          }
                          
                          final locationData = {
                            'latitude': _currentPosition!.latitude,
                            'longitude': _currentPosition!.longitude,
                            'address': _currentAddress
                          };

                          LoggerService.info('Enviando datos de ubicación para fichaje: $locationData');
                          
                          await JornadaService().registrarFichaje('SALIDA', locationData);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Salida registrada correctamente')),
                            );
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error al registrar salida: $e')),
                            );
                          }
                        }
                      },
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.logout, color: Colors.white),
                          SizedBox(width: 8),
                          Text(
                            'Salida',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatCoordinates(double latitude, double longitude) {
    return 'Lat: ${latitude.toStringAsFixed(6)}, Long: ${longitude.toStringAsFixed(6)}';
  }
} 