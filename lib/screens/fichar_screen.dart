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
      final response = await http.get(
        Uri.parse('https://nominatim.openstreetmap.org/reverse?format=json&lat=$latitude&lon=$longitude&accept-language=es'),
        headers: {'User-Agent': 'Fichaje App (https://github.com/drpcons/drpcons-fichaje)'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final address = data['display_name'] as String?;
        if (address != null && address.isNotEmpty) {
          LoggerService.info('Dirección obtenida: $address');
          return address;
        }
      }
      LoggerService.info('No se pudo obtener dirección, usando coordenadas');
      return 'Lat: ${latitude.toStringAsFixed(6)}, Long: ${longitude.toStringAsFixed(6)}';
    } catch (e) {
      LoggerService.error('Error al obtener dirección: $e');
      return 'Lat: ${latitude.toStringAsFixed(6)}, Long: ${longitude.toStringAsFixed(6)}';
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
      final address = await _getAddressFromCoordinates(position.latitude, position.longitude);

      setState(() {
        _currentPosition = position;
        _currentAddress = address;
        _isLoading = false;
      });
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: () async {
                    try {
                      await JornadaService().registrarFichaje('Entrada');
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
                  child: const Text('Entrada'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    try {
                      await JornadaService().registrarFichaje('Salida');
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
                  child: const Text('Salida'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
} 