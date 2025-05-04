import 'package:cloud_firestore/cloud_firestore.dart';

class AdminService {
  static const String adminEmail = 'd.romeral.perulero@gmail.com';
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> resetAdminConfig() async {
    try {
      // Buscar y eliminar cualquier documento de usuario admin existente
      final usersSnapshot = await _firestore
          .collection('users')
          .where('email', isEqualTo: adminEmail)
          .get();

      // Eliminar todos los documentos encontrados
      for (var doc in usersSnapshot.docs) {
        await _firestore.collection('users').doc(doc.id).delete();
        print('Documento de administrador eliminado: ${doc.id}');
      }

      print('Configuración de administrador reiniciada correctamente');
    } catch (e) {
      print('Error al reiniciar la configuración del administrador: $e');
    }
  }

  Future<void> ensureAdminPrivileges() async {
    try {
      // Buscar el usuario en Firestore
      final usersSnapshot = await _firestore
          .collection('users')
          .where('email', isEqualTo: adminEmail)
          .get();

      if (usersSnapshot.docs.isEmpty) {
        // Crear nuevo documento para el admin
        await _firestore.collection('users').add({
          'email': adminEmail,
          'isAdmin': true,
          'role': 'admin',
          'createdAt': FieldValue.serverTimestamp(),
        });
        print('Nuevo documento de administrador creado');
        return;
      }

      // Actualizar documento existente
      final userDoc = usersSnapshot.docs.first;
      await _firestore.collection('users').doc(userDoc.id).update({
        'isAdmin': true,
        'role': 'admin',
        'updatedAt': FieldValue.serverTimestamp(),
      });
      print('Documento de administrador actualizado');
    } catch (e) {
      print('Error al configurar administrador: $e');
    }
  }

  Future<Map<String, dynamic>?> getAdminInfo() async {
    try {
      final usersSnapshot = await _firestore
          .collection('users')
          .where('email', isEqualTo: adminEmail)
          .get();

      if (usersSnapshot.docs.isEmpty) {
        print('No se encontró ningún administrador');
        return null;
      }

      final adminDoc = usersSnapshot.docs.first;
      final adminData = adminDoc.data();
      adminData['id'] = adminDoc.id;

      return adminData;
    } catch (e) {
      print('Error al obtener información del administrador: $e');
      return null;
    }
  }
} 