import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'screens/login_screen.dart';
import 'screens/main_screen.dart';
import 'screens/admin_screen.dart';
import 'screens/register_screen.dart';
import 'services/auth_service.dart';

void main() async {
  try {
    print('Iniciando la aplicación...');
    WidgetsFlutterBinding.ensureInitialized();
    
    print('Inicializando Firebase...');
    if (kIsWeb) {
      // Configuración específica para web
      await Firebase.initializeApp(
        options: const FirebaseOptions(
          apiKey: "AIzaSyDyK15r9TFic58iyxo62WL8-7SAua9NGqA",
          authDomain: "drpclock-a3957.firebaseapp.com",
          projectId: "drpclock-a3957",
          storageBucket: "drpclock-a3957.firebasestorage.app",
          messagingSenderId: "812906037963",
          appId: "1:812906037963:web:4534b0816d51583481514e",
          measurementId: "G-0JT9L282FB",
        ),
      );
      print('Firebase inicializado en web');
    } else {
    await Firebase.initializeApp();
      print('Firebase inicializado en móvil');
    }
    
    // Verificar la conexión con Firestore
    try {
      await FirebaseFirestore.instance.collection('test').doc('test').set({
        'test': 'test'
      });
      print('Conexión con Firestore verificada correctamente');
    } catch (e) {
      print('Error al verificar Firestore: $e');
    }
    
    print('Verificando administrador inicial...');
    await AuthService().createFirstAdmin();
    print('Verificación de administrador completada');
    
    runApp(const MyApp());
  } catch (e, stackTrace) {
    print('Error durante la inicialización: $e');
    print('Stack trace: $stackTrace');
    runApp(const MyApp()); // Intentar ejecutar la app de todos modos
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DRP Clock',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const AuthWrapper(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  final AuthService _authService = AuthService();
  bool _isLoading = true;
  Map<String, dynamic>? _userData;
  String? _error;

  @override
  void initState() {
    super.initState();
    print('AuthWrapper: initState');
    _checkAuthState();
  }

  Future<void> _checkAuthState() async {
    try {
      print('AuthWrapper: Verificando estado de autenticación...');
    final userData = await _authService.getCurrentUser();
      print('AuthWrapper: Datos del usuario obtenidos: $userData');
      
    if (mounted) {
      setState(() {
        _userData = userData;
        _isLoading = false;
          _error = null;
        });
      }
    } catch (e) {
      print('AuthWrapper: Error al verificar estado de autenticación: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = 'Error al verificar el estado de autenticación';
      });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    print('AuthWrapper: build - isLoading: $_isLoading, userData: $_userData, error: $_error');
    
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Cargando...'),
            ],
          ),
        ),
      );
    }

    if (_error != null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(_error!, style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _isLoading = true;
                    _error = null;
                  });
                  _checkAuthState();
                },
                child: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }

    if (_userData == null) {
      print('AuthWrapper: No hay usuario autenticado, mostrando pantalla de login');
      return const LoginScreen();
    }

    print('AuthWrapper: Usuario autenticado, redirigiendo según rol: ${_userData!['role']}');
    if (_userData!['role'] == 'admin') {
      return const AdminScreen();
    }

    return const MainScreen();
  }
}
