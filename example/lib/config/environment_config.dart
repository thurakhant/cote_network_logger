import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

/// Environment configuration class that follows singleton pattern and provides
/// environment-specific settings and utilities.
class EnvironmentConfig {
  // Private constructor to prevent instantiation
  EnvironmentConfig._();

  /// Singleton instance
  static final EnvironmentConfig instance = EnvironmentConfig._();

  /// Environment types
  static const String debug = 'Debug';
  static const String staging = 'Staging';
  static const String release = 'Release';

  /// Environment-specific settings
  static const Map<String, EnvironmentSettings> _settings = {
    debug: EnvironmentSettings(
      name: debug,
      color: Colors.blue,
      icon: Icons.bug_report,
      description: 'Development environment with full debugging features',
      features: {
        'Network Logger': true,
        'Debug Tools': true,
        'Analytics': false,
      },
    ),
    staging: EnvironmentSettings(
      name: staging,
      color: Colors.orange,
      icon: Icons.storage,
      description: 'Testing environment with limited debugging features',
      features: {
        'Network Logger': true,
        'Debug Tools': false,
        'Analytics': true,
      },
    ),
    release: EnvironmentSettings(
      name: release,
      color: Colors.red,
      icon: Icons.security,
      description: 'Production environment with security features enabled',
      features: {
        'Network Logger': false,
        'Debug Tools': false,
        'Analytics': true,
      },
    ),
  };

  /// Get current environment
  String get currentEnvironment {
    if (kDebugMode) return debug;
    if (const bool.fromEnvironment('STAGING_ENV', defaultValue: false)) return staging;
    return release;
  }

  /// Get current environment settings
  EnvironmentSettings get currentSettings => _settings[currentEnvironment]!;

  /// Check if feature is enabled in current environment
  bool isFeatureEnabled(String feature) {
    return currentSettings.features[feature] ?? false;
  }

  /// Get environment-specific color
  Color get color => currentSettings.color;

  /// Get environment-specific icon
  IconData get icon => currentSettings.icon;

  /// Get environment description
  String get description => currentSettings.description;

  /// Get all enabled features
  List<String> get enabledFeatures => currentSettings.features.entries.where((entry) => entry.value).map((entry) => entry.key).toList();

  /// Get all disabled features
  List<String> get disabledFeatures => currentSettings.features.entries.where((entry) => !entry.value).map((entry) => entry.key).toList();

  /// Check if current environment is debug
  bool get isDebug => currentEnvironment == debug;

  /// Check if current environment is staging
  bool get isStaging => currentEnvironment == staging;

  /// Check if current environment is release
  bool get isRelease => currentEnvironment == release;
}

/// Environment-specific settings
class EnvironmentSettings {
  final String name;
  final Color color;
  final IconData icon;
  final String description;
  final Map<String, bool> features;

  const EnvironmentSettings({
    required this.name,
    required this.color,
    required this.icon,
    required this.description,
    required this.features,
  });
}
