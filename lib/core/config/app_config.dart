import 'package:flutter/foundation.dart';

class AppConfig {
  static const String backendPort = '8000';
  static const String androidEmulatorBaseUrl = 'http://10.0.2.2:8000';
  static const String desktopBaseUrl = 'http://127.0.0.1:8000';

  static String get baseUrl {
    const configuredOverride =
        String.fromEnvironment('BACKEND_BASE_URL', defaultValue: '');
    final override = configuredOverride.trim();
    if (override.isNotEmpty) {
      return override.replaceAll(RegExp(r'/+$'), '');
    }

    if (defaultTargetPlatform == TargetPlatform.android) {
      return androidEmulatorBaseUrl;
    }

    return desktopBaseUrl;
  }
}
