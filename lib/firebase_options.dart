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
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
      case TargetPlatform.linux:
      case TargetPlatform.fuchsia:
        return windows;
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyCRYXDbWcNAM4S3jxixlvnLnKegqQBxUW4',
    appId: '1:398456425469:web:76da0bd3462ff6746e2794',
    messagingSenderId: '398456425469',
    projectId: 'lexiguard-32c63',
    authDomain: 'lexiguard-32c63.firebaseapp.com',
    databaseURL: 'https://lexiguard-32c63-default-rtdb.asia-southeast1.firebasedatabase.app',
    storageBucket: 'lexiguard-32c63.firebasestorage.app',
    measurementId: 'G-FQ38MDTXDE',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDl9R55zChTMVS0-4wQPxK-Z3rkp5PYkmk',
    appId: '1:398456425469:android:f92734f15a08e7b86e2794',
    messagingSenderId: '398456425469',
    projectId: 'lexiguard-32c63',
    databaseURL: 'https://lexiguard-32c63-default-rtdb.asia-southeast1.firebasedatabase.app',
    storageBucket: 'lexiguard-32c63.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyBxNyFEkZIyKTOIZdDG5gLONvIo3RwHKP8',
    appId: '1:398456425469:ios:6580b1dc03c52ebc6e2794',
    messagingSenderId: '398456425469',
    projectId: 'lexiguard-32c63',
    databaseURL: 'https://lexiguard-32c63-default-rtdb.asia-southeast1.firebasedatabase.app',
    storageBucket: 'lexiguard-32c63.firebasestorage.app',
    iosClientId: '398456425469-v4060i1mchj507fsvtogllok79pkvn6s.apps.googleusercontent.com',
    iosBundleId: 'com.example.leiGuard',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyBxNyFEkZIyKTOIZdDG5gLONvIo3RwHKP8',
    appId: '1:398456425469:ios:6580b1dc03c52ebc6e2794',
    messagingSenderId: '398456425469',
    projectId: 'lexiguard-32c63',
    databaseURL: 'https://lexiguard-32c63-default-rtdb.asia-southeast1.firebasedatabase.app',
    storageBucket: 'lexiguard-32c63.firebasestorage.app',
    iosClientId: '398456425469-v4060i1mchj507fsvtogllok79pkvn6s.apps.googleusercontent.com',
    iosBundleId: 'com.example.leiGuard',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyCRYXDbWcNAM4S3jxixlvnLnKegqQBxUW4',
    appId: '1:398456425469:web:44d3ae362b41df2f6e2794',
    messagingSenderId: '398456425469',
    projectId: 'lexiguard-32c63',
    authDomain: 'lexiguard-32c63.firebaseapp.com',
    databaseURL: 'https://lexiguard-32c63-default-rtdb.asia-southeast1.firebasedatabase.app',
    storageBucket: 'lexiguard-32c63.firebasestorage.app',
    measurementId: 'G-RFKLC9VNHB',
  );

}