import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:convert';
import 'dart:async';
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

  String _formatCoordinates(double latitude, double longitude) {
    return 'Lat: ${latitude.toStringAsFixed(6)}, Long: ${longitude.toStringAsFixed(6)}';
  }

  Future<String> _getAddressFromCoordinates(double latitude, double longitude) async {
    try {
      LoggerService.info('Intentando obtener dirección para coordenadas: $latitude, $longitude');
      final url = 'https://nominatim.openstreetmap.org/reverse?format=json&lat=$latitude&lon=$longitude&accept-language=es&zoom=18';
      LoggerService.info('URL de geocodificación: $url');
      
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'User-Agent': 'Fichaje App/1.0',
          'Accept': 'application/json'
        },
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          LoggerService.error('Timeout al obtener dirección');
          throw TimeoutException('Tiempo de espera agotado al obtener la dirección');
        },
      );

      LoggerService.info('Respuesta del servidor: ${response.statusCode}');
      LoggerService.info('Contenido de la respuesta: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        LoggerService.info('Datos decodificados: $data');
        
        // Intentar construir la dirección desde los componentes individuales primero
        final address = data['address'] as Map<String, dynamic>?;
        if (address != null) {
          LoggerService.info('Componentes de dirección encontrados: $address');
          final components = <String>[];
          
          final addressParts = {
            'road': 'Calle',
            'house_number': 'Número',
            'suburb': 'Barrio',
            'city': 'Ciudad',
            'town': 'Pueblo',
            'county': 'Municipio',
            'state': 'Provincia',
            'postcode': 'CP'
          };

          for (final entry in addressParts.entries) {
            final value = address[entry.key];
            if (value != null && value.toString().isNotEmpty) {
              components.add(value.toString());
            }
          }
          
          if (components.isNotEmpty) {
            final formattedAddress = components.join(', ');
            LoggerService.info('Dirección formateada desde componentes: $formattedAddress');
            return formattedAddress;
          }
        }
        
        // Si no se pudo construir desde componentes, usar display_name
        final displayName = data['display_name'] as String?;
        if (displayName != null && displayName.isNotEmpty) {
          LoggerService.info('Usando display_name como dirección: $displayName');
          return displayName;
        }
        
        LoggerService.info('No se encontró información de dirección en la respuesta');
        return _formatCoordinates(latitude, longitude);
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
      LoggerService.info('Solicitando permisos de ubicación...');
      LocationPermission permission = await Geolocator.checkPermission();
      
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Permisos de ubicación denegados');
        }
      }
      
      if (permission == LocationPermission.deniedForever) {
        throw Exception('Permisos de ubicación permanentemente denegados');
      }

      LoggerService.info('Obteniendo posición actual...');
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 15),
      );
      
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

                          LoggerService.info('Registrando entrada con ubicación: $locationData');
                          await JornadaService().registrarFichaje('entrada', locationData);
                          
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Entrada registrada correctamente'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          }
                        } catch (e) {
                          LoggerService.error('Error al registrar entrada: $e');
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Error al registrar entrada: $e'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      },
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.login, color: Colors.white),
                          SizedBox(width: 8),
                          Text(
                            'Entrada',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
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

                          LoggerService.info('Registrando salida con ubicación: $locationData');
                          await JornadaService().registrarFichaje('salida', locationData);
                          
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Salida registrada correctamente'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          }
                        } catch (e) {
                          LoggerService.error('Error al registrar salida: $e');
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Error al registrar salida: $e'),
                                backgroundColor: Colors.red,
                              ),
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
} 