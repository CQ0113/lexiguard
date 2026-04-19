import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
      case TargetPlatform.linux:
      case TargetPlatform.fuchsia:
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyCRYXDbWcNAM4S3jxixlvnLnKegqQBxUW4',
    appId: '1:398456425469:web:76da0bd3462ff6746e2794',
    messagingSenderId: '398456425469',
    projectId: 'lexiguard-32c63',
    authDomain: 'lexiguard-32c63.firebaseapp.com',
    storageBucket: 'lexiguard-32c63.firebasestorage.app',
    measurementId: 'G-FQ38MDTXDE',
  );
}
