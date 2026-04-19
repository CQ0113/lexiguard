import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

class FirebaseInitializer {
  static bool _isReady = false;
  static String? _initializationError;
  static Future<void>? _initializationFuture;

  static bool get isReady => _isReady;
  static String? get initializationError => _initializationError;

  static Future<void> ensureInitialized() {
    _initializationFuture ??= _initializeInternal();
    return _initializationFuture!;
  }

  static Future<void> _initializeInternal() async {
    try {
      await Firebase.initializeApp();
      _isReady = true;
      _initializationError = null;
    } catch (error) {
      _isReady = false;
      _initializationError = error.toString();

      // Keep the app usable in demo mode when Firebase config is not added yet.
      debugPrint('Firebase init skipped: $_initializationError');
    }
  }
}
