import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  // Verificar si existe un usuario con el email y contraseña proporcionados
  Future<Map<String, dynamic>?> loginUser({
    required String email,
    required String password,
  }) async {
    try {
      print('Intentando iniciar sesión con email: $email');
      
      // Buscar usuario en Firestore
      final querySnapshot = await _firestore
          .collection('users')
          .where('email', isEqualTo: email)
          .where('password', isEqualTo: password) // En producción, usar hash de contraseña
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) {
        print('Usuario no encontrado');
        throw Exception('Credenciales inválidas');
      }

      final userDoc = querySnapshot.docs.first;
      final userData = userDoc.data();
      
      // Verificar si la cuenta está activa
      if (userData['status'] != 'active') {
        print('Cuenta inactiva');
        throw Exception('La cuenta está inactiva');
      }

      print('Usuario encontrado, guardando datos en almacenamiento seguro...');
      print('ID del usuario: ${userDoc.id}');
      print('Datos del usuario: $userData');

      // Guardar datos en el almacenamiento seguro
      await _storage.write(key: 'userId', value: userDoc.id);
      await _storage.write(key: 'userEmail', value: email);
      await _storage.write(key: 'userName', value: userData['name']);
      await _storage.write(key: 'userRole', value: userData['role']);

      // Verificar que los datos se guardaron correctamente
      final storedUserId = await _storage.read(key: 'userId');
      print('ID del usuario almacenado: $storedUserId');

      if (storedUserId == null) {
        print('Error: No se pudo almacenar el ID del usuario');
        throw Exception('Error al guardar los datos de sesión');
      }

      print('Inicio de sesión completado exitosamente');
      return {
        'id': userDoc.id,
        'email': email,
        'name': userData['name'],
        'role': userData['role'],
      };
    } catch (e) {
      print('Error durante el inicio de sesión: $e');
      rethrow;
    }
  }

  // Registrar un nuevo usuario
  Future<Map<String, dynamic>?> registerUser({
    required String email,
    required String password,
    required String name,
    String role = 'employee',
  }) async {
    try {
      print('Intentando registrar usuario con email: $email');
      
      // Verificar si Firebase está inicializado
      if (!FirebaseFirestore.instance.app.options.projectId.isNotEmpty) {
        throw Exception('Error de conexión con Firebase. Por favor, intente más tarde.');
      }
      
      // Verificar si el email ya está registrado
      final existingUser = await _firestore
          .collection('users')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (existingUser.docs.isNotEmpty) {
        throw Exception('Ya existe una cuenta con este correo electrónico');
      }

      // Crear nuevo documento de usuario en Firestore
      final userRef = await _firestore.collection('users').add({
        'email': email,
        'password': password, // En producción, usar hash de contraseña
        'name': name,
        'role': role,
        'status': 'active',
        'createdAt': FieldValue.serverTimestamp(),
      });

      print('Usuario registrado exitosamente');

      // Guardar datos en el almacenamiento seguro
      await _storage.write(key: 'userId', value: userRef.id);
      await _storage.write(key: 'userEmail', value: email);
      await _storage.write(key: 'userName', value: name);
      await _storage.write(key: 'userRole', value: role);

      return {
        'id': userRef.id,
        'email': email,
        'name': name,
        'role': role,
      };
    } catch (e) {
      print('Error durante el registro: $e');
      if (e is FirebaseException) {
        throw Exception('Error de conexión con la base de datos. Por favor, intente más tarde.');
      }
      rethrow;
    }
  }

  // Cerrar sesión
  Future<void> logout() async {
    try {
      await _storage.deleteAll();
    } catch (e) {
      print('Error durante el cierre de sesión: $e');
      rethrow;
    }
  }

  // Verificar si hay un usuario autenticado
  Future<Map<String, dynamic>?> getCurrentUser() async {
    try {
      print('=== GET CURRENT USER ===');
      final userId = await _storage.read(key: 'userId');
      print('userId almacenado: $userId');
      
      if (userId == null) {
        print('No hay userId almacenado');
        return null;
      }

      print('Obteniendo datos del usuario con ID: $userId');
      final userDoc = await _firestore.collection('users').doc(userId).get();
      
      if (!userDoc.exists) {
        print('No se encontró el documento del usuario');
        return null;
      }

      final userData = userDoc.data()!;
      print('Datos del usuario obtenidos: $userData');
      
      final user = {
        'id': userDoc.id,
        'email': userData['email'],
        'name': userData['name'],
        'role': userData['role'],
      };
      
      print('Usuario actual: $user');
      print('Rol del usuario: ${user['role']}');
      print('=====================');
      return user;
    } catch (e) {
      print('Error al obtener usuario actual: $e');
      return null;
    }
  }

  Future<void> createFirstAdmin() async {
    try {
      print('Checking for existing admin users...');
      
      // Check if any admin exists
      final adminQuery = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'admin')
          .limit(1)
          .get();

      if (adminQuery.docs.isNotEmpty) {
        print('Admin user already exists');
        return;
      }

      print('No admin found, creating first admin...');
      
      // Create admin user document
      final adminDoc = await _firestore.collection('users').add({
        'email': 'admin@drpclock.com',
        'password': 'admin123', // Contraseña por defecto
        'name': 'Administrator',
        'role': 'admin',
        'status': 'active',
        'createdAt': FieldValue.serverTimestamp(),
      });

      print('Admin user created with ID: ${adminDoc.id}');

      // Store admin credentials
      await _storage.write(key: 'userId', value: adminDoc.id);
      await _storage.write(key: 'userEmail', value: 'admin@drpclock.com');
      await _storage.write(key: 'userName', value: 'Administrator');
      await _storage.write(key: 'userRole', value: 'admin');

      print('Admin credentials stored successfully');
    } catch (e) {
      print('Error creating first admin: $e');
      // Don't rethrow the error to prevent app crash
    }
  }
} 