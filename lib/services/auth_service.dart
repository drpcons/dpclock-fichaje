import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'logger_service.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Stream de cambios en el estado de autenticación
  Stream<User?> get user => _auth.authStateChanges();

  // Iniciar sesión con email y contraseña
  Future<UserCredential?> signInWithEmailAndPassword(String email, String password) async {
    try {
      final result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      LoggerService.info('Usuario ha iniciado sesión: ${result.user?.email}');
      
      // Verificar y actualizar el estado de admin si es necesario
      if (result.user != null && result.user!.email == 'd.romeral.perulero@gmail.com') {
        await _ensureUserIsAdmin(result.user!.uid);
      }
      
      return result;
    } catch (e) {
      LoggerService.error('Error al iniciar sesión', e);
      rethrow;
    }
  }

  // Registrar usuario con email y contraseña
  Future<UserCredential?> registerWithEmailAndPassword(
    String email, 
    String password,
    String nombre,
    String apellidos,
  ) async {
    try {
      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      final isAdmin = email == 'd.romeral.perulero@gmail.com';
      
      // Guardar información adicional en Firestore
      await _firestore.collection('users').doc(result.user!.uid).set({
        'email': email,
        'nombre': nombre,
        'apellidos': apellidos,
        'isAdmin': isAdmin,
        'role': isAdmin ? 'admin' : 'user',
        'createdAt': FieldValue.serverTimestamp(),
      });

      LoggerService.info('Usuario registrado: ${result.user?.email}');
      LoggerService.info('Datos del usuario guardados en Firestore');
      return result;
    } catch (e) {
      LoggerService.error('Error en el registro', e);
      rethrow;
    }
  }

  // Cerrar sesión
  Future<void> signOut() async {
    try {
      await _auth.signOut();
      LoggerService.info('Usuario ha cerrado sesión');
    } catch (e) {
      LoggerService.error('Error al cerrar sesión', e);
      rethrow;
    }
  }

  // Método privado para asegurar que un usuario es admin
  Future<void> _ensureUserIsAdmin(String uid) async {
    try {
      final userDoc = await _firestore.collection('users').doc(uid).get();
      if (!userDoc.exists) {
        await _firestore.collection('users').doc(uid).set({
          'email': 'd.romeral.perulero@gmail.com',
          'isAdmin': true,
          'role': 'admin',
          'createdAt': FieldValue.serverTimestamp(),
        });
        return;
      }

      final userData = userDoc.data();
      if (userData?['isAdmin'] != true) {
        await _firestore.collection('users').doc(uid).update({
          'isAdmin': true,
          'role': 'admin',
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      print('Error al asegurar permisos de administrador: $e');
    }
  }

  // Verificar si el usuario actual es administrador
  Future<bool> isCurrentUserAdmin() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      if (user.email == 'd.romeral.perulero@gmail.com') {
        final userDoc = await _firestore.collection('users').doc(user.uid).get();
        
        if (!userDoc.exists) {
          // Crear el documento si no existe
          await _firestore.collection('users').doc(user.uid).set({
            'email': 'd.romeral.perulero@gmail.com',
            'isAdmin': true,
            'role': 'admin',
            'createdAt': FieldValue.serverTimestamp(),
          });
          return true;
        }

        // Asegurar que tiene los permisos correctos
        if (userDoc.data()?['isAdmin'] != true) {
          await _firestore.collection('users').doc(user.uid).update({
            'isAdmin': true,
            'role': 'admin',
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
        
        return true;
      }

      return false;
    } catch (e) {
      print('Error al verificar permisos de administrador: $e');
      return false;
    }
  }
} 