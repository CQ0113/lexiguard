import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter_dotenv/flutter_dotenv.dart';

String _env(String key, String fallback) {
  final value = dotenv.env[key];
  if (value == null || value.trim().isEmpty) return fallback;
  return value;
}

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
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static FirebaseOptions get web => FirebaseOptions(
    apiKey: _env('FIREBASE_WEB_API_KEY', 'YOUR_WEB_API_KEY'),
    appId: _env('FIREBASE_WEB_APP_ID', 'YOUR_WEB_APP_ID'),
    messagingSenderId: _env(
      'FIREBASE_WEB_MESSAGING_SENDER_ID',
      'YOUR_MESSAGING_SENDER_ID',
    ),
    projectId: _env('FIREBASE_WEB_PROJECT_ID', 'YOUR_PROJECT_ID'),
    authDomain: _env('FIREBASE_WEB_AUTH_DOMAIN', 'YOUR_PROJECT_ID.firebaseapp.com'),
    storageBucket: _env(
      'FIREBASE_WEB_STORAGE_BUCKET',
      'YOUR_PROJECT_ID.firebasestorage.app',
    ),
    measurementId: _env('FIREBASE_WEB_MEASUREMENT_ID', 'YOUR_MEASUREMENT_ID'),
  );

  static FirebaseOptions get android => FirebaseOptions(
    apiKey: _env('FIREBASE_ANDROID_API_KEY', 'YOUR_ANDROID_API_KEY'),
    appId: _env('FIREBASE_ANDROID_APP_ID', 'YOUR_ANDROID_APP_ID'),
    messagingSenderId: _env(
      'FIREBASE_ANDROID_MESSAGING_SENDER_ID',
      'YOUR_MESSAGING_SENDER_ID',
    ),
    projectId: _env('FIREBASE_ANDROID_PROJECT_ID', 'YOUR_PROJECT_ID'),
    storageBucket: _env(
      'FIREBASE_ANDROID_STORAGE_BUCKET',
      'YOUR_PROJECT_ID.firebasestorage.app',
    ),
  );

  static FirebaseOptions get ios => FirebaseOptions(
    apiKey: _env('FIREBASE_IOS_API_KEY', 'YOUR_IOS_API_KEY'),
    appId: _env('FIREBASE_IOS_APP_ID', 'YOUR_IOS_APP_ID'),
    messagingSenderId: _env(
      'FIREBASE_IOS_MESSAGING_SENDER_ID',
      'YOUR_MESSAGING_SENDER_ID',
    ),
    projectId: _env('FIREBASE_IOS_PROJECT_ID', 'YOUR_PROJECT_ID'),
    storageBucket: _env(
      'FIREBASE_IOS_STORAGE_BUCKET',
      'YOUR_PROJECT_ID.firebasestorage.app',
    ),
    iosBundleId: _env('FIREBASE_IOS_BUNDLE_ID', 'com.example.lexi_guard'),
  );

  static FirebaseOptions get macos => FirebaseOptions(
    apiKey: _env('FIREBASE_MACOS_API_KEY', 'YOUR_MACOS_API_KEY'),
    appId: _env('FIREBASE_MACOS_APP_ID', 'YOUR_MACOS_APP_ID'),
    messagingSenderId: _env(
      'FIREBASE_MACOS_MESSAGING_SENDER_ID',
      'YOUR_MESSAGING_SENDER_ID',
    ),
    projectId: _env('FIREBASE_MACOS_PROJECT_ID', 'YOUR_PROJECT_ID'),
    storageBucket: _env(
      'FIREBASE_MACOS_STORAGE_BUCKET',
      'YOUR_PROJECT_ID.firebasestorage.app',
    ),
    iosBundleId: _env('FIREBASE_MACOS_BUNDLE_ID', 'com.example.lexi_guard'),
  );
}
 