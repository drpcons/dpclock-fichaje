import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import '../services/jornada_service.dart';
import '../services/logger_service.dart';
import 'package:flutter/foundation.dart';
import 'dart:html' as html;

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
      
      // Aumentar el tiempo de espera para la web
      final timeout = kIsWeb ? const Duration(seconds: 20) : const Duration(seconds: 10);
      
      final url = Uri.parse('https://nominatim.openstreetmap.org/reverse')
        .replace(queryParameters: {
          'format': 'json',
          'lat': latitude.toString(),
          'lon': longitude.toString(),
          'accept-language': 'es',
          'zoom': '18',
          'addressdetails': '1'
        });
      
      LoggerService.info('URL de geocodificación: $url');
      
      final response = await http.get(
        url,
        headers: {
          'User-Agent': 'Fichaje App/1.0',
          'Accept': 'application/json',
          'Origin': kIsWeb ? html.window.location.origin ?? 'https://fichaje-app.web.app' : 'app://fichaje',
        },
      ).timeout(
        timeout,
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
        
        // Intentar obtener la dirección de varias formas
        String? address;
        
        // 1. Intentar con display_name
        final displayName = data['display_name'] as String?;
        if (displayName != null && displayName.isNotEmpty) {
          LoggerService.info('Usando display_name como dirección: $displayName');
          address = displayName;
        }
        
        // 2. Si no hay display_name, intentar con address
        if (address == null) {
          final addressData = data['address'] as Map<String, dynamic>?;
          if (addressData != null) {
            LoggerService.info('Componentes de dirección encontrados: $addressData');
            
            // Priorizar componentes más específicos
            final components = <String>[];
            
            // Orden de prioridad para componentes de dirección
            final addressParts = [
              'road',          // calle
              'house_number',  // número
              'suburb',        // barrio
              'neighbourhood', // vecindario
              'city',         // ciudad
              'town',         // pueblo
              'village',      // villa
              'municipality', // municipio
              'county',       // condado
              'state',        // estado/provincia
              'postcode'      // código postal
            ];
            
            // Agregar componentes en orden de prioridad
            for (final key in addressParts) {
              final value = addressData[key];
              if (value != null && value.toString().isNotEmpty) {
                components.add(value.toString());
              }
            }
            
            if (components.isNotEmpty) {
              address = components.join(', ');
              LoggerService.info('Dirección construida desde componentes: $address');
            }
          }
        }
        
        // Si se obtuvo una dirección válida, devolverla
        if (address != null && address.isNotEmpty) {
          return address;
        }
        
        // Si no se pudo obtener la dirección, usar coordenadas
        final coordText = _formatCoordinates(latitude, longitude);
        LoggerService.info('Usando coordenadas como fallback: $coordText');
        return coordText;
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
      
      if (kIsWeb) {
        LoggerService.info('Ejecutando en versión web...');
        
        // En web, primero verificar si la geolocalización está disponible
        if (!await Geolocator.isLocationServiceEnabled()) {
          throw Exception('Los servicios de ubicación no están disponibles en el navegador');
        }

        // Verificar permisos específicamente para web
        LocationPermission permission = await Geolocator.checkPermission();
        LoggerService.info('Estado inicial de permisos web: $permission');
        
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
          LoggerService.info('Permisos solicitados web: $permission');
          if (permission == LocationPermission.denied) {
            throw Exception('Permisos de ubicación denegados en el navegador');
          }
        }
        
        if (permission == LocationPermission.deniedForever) {
          throw Exception('Permisos de ubicación permanentemente denegados en el navegador');
        }

        // En web, usar alta precisión y un tiempo de espera más largo
        LoggerService.info('Obteniendo posición en web...');
        final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 20),
        );
        
        LoggerService.info('Posición web obtenida: ${position.latitude}, ${position.longitude}');
        
        if (position.latitude == 0 && position.longitude == 0) {
          throw Exception('No se pudo obtener una ubicación válida del navegador');
        }

        final address = await _getAddressFromCoordinates(position.latitude, position.longitude);
        LoggerService.info('Dirección web obtenida: $address');

        setState(() {
          _currentPosition = position;
          _currentAddress = address;
          _isLoading = false;
        });
      } else {
        // Código existente para móvil
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
      }
      
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
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Botón de Entrada (Verde)
                  SizedBox(
                    width: double.infinity,
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
                  const SizedBox(height: 16),
                  // Botón de Pausa (Amarillo)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amber,
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

                          LoggerService.info('Registrando pausa con ubicación: $locationData');
                          await JornadaService().registrarFichaje('pausa', locationData);
                          
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Pausa registrada correctamente'),
                                backgroundColor: Colors.amber,
                              ),
                            );
                          }
                        } catch (e) {
                          LoggerService.error('Error al registrar pausa: $e');
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Error al registrar pausa: $e'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      },
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.pause_circle_outline, color: Colors.white),
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
                  const SizedBox(height: 16),
                  // Botón de Salida (Rojo)
                  SizedBox(
                    width: double.infinity,
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