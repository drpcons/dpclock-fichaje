import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyBjtDNcStVKgxaOD5lEXU2n_jbYNcPrA0s',
    appId: '1:816861692730:android:68984e74c0333ef11d4603',
    messagingSenderId: '816861692730',
    projectId: 'fichaje-de-personal',
    databaseURL: 'https://fichaje-de-personal-default-rtdb.europe-west1.firebasedatabase.app',
    storageBucket: 'fichaje-de-personal.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBjtDNcStVKgxaOD5lEXU2n_jbYNcPrA0s',
    appId: '1:816861692730:android:68984e74c0333ef11d4603',
    messagingSenderId: '816861692730',
    projectId: 'fichaje-de-personal',
    databaseURL: 'https://fichaje-de-personal-default-rtdb.europe-west1.firebasedatabase.app',
    storageBucket: 'fichaje-de-personal.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyBjtDNcStVKgxaOD5lEXU2n_jbYNcPrA0s',
    appId: '1:816861692730:ios:your_ios_app_id',
    messagingSenderId: '816861692730',
    projectId: 'fichaje-de-personal',
    databaseURL: 'https://fichaje-de-personal-default-rtdb.europe-west1.firebasedatabase.app',
    storageBucket: 'fichaje-de-personal.firebasestorage.app',
    iosClientId: 'your_ios_client_id',
    iosBundleId: 'com.example.fichaje',
  );
} 