import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../../firebase_options.dart';

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
      if (Firebase.apps.isNotEmpty) {
        _isReady = true;
        _initializationError = null;
        return;
      }

      final options = DefaultFirebaseOptions.currentPlatform;
      if (_hasPlaceholderValues(options)) {
        throw StateError(
          'Firebase options still contain placeholder values. '
          'Run flutterfire configure and update lib/firebase_options.dart.',
        );
      }

      await Firebase.initializeApp(options: options);
      _isReady = true;
      _initializationError = null;
    } on FirebaseException catch (error) {
      if (error.code == 'duplicate-app') {
        _isReady = true;
        _initializationError = null;
        return;
      }

      _isReady = false;
      _initializationError = error.toString();

      // Keep the app usable in demo mode when Firebase config is not added yet.
      debugPrint('Firebase init skipped: $_initializationError');
    } catch (error) {
      _isReady = false;
      _initializationError = error.toString();

      // Keep the app usable in demo mode when Firebase config is not added yet.
      debugPrint('Firebase init skipped: $_initializationError');
    }
  }

  static bool _hasPlaceholderValues(FirebaseOptions options) {
    final requiredValues = [
      options.apiKey,
      options.appId,
      options.messagingSenderId,
      options.projectId,
    ];

    return requiredValues.any(
      (value) => value.isEmpty || value.contains('YOUR_'),
    );
  }
}
