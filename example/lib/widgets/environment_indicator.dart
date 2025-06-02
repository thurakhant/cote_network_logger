import 'package:flutter/material.dart';
import '../config/environment_config.dart';

/// A widget that displays the current environment with visual indicators.
/// This widget can be used in the app bar or anywhere else in the UI.
class EnvironmentIndicator extends StatelessWidget {
  /// Whether to show enabled/disabled features
  final bool showFeatures;

  /// Whether to show a compact version of the indicator
  final bool compact;

  /// Creates an environment indicator.
  ///
  /// [showFeatures] determines whether to show enabled/disabled features.
  /// [compact] determines whether to show a compact version of the indicator.
  const EnvironmentIndicator({
    super.key,
    this.showFeatures = false,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final config = EnvironmentConfig.instance;
    final settings = config.currentSettings;

    if (compact) {
      return _buildCompactIndicator(settings);
    }

    return _buildFullIndicator(settings);
  }

  Widget _buildCompactIndicator(EnvironmentSettings settings) {
    return Container(
      margin: const EdgeInsets.only(right: 16),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: settings.color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: settings.color,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            settings.icon,
            size: 16,
            color: settings.color,
          ),
          const SizedBox(width: 4),
          Text(
            settings.name,
            style: TextStyle(
              color: settings.color,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFullIndicator(EnvironmentSettings settings) {
    return Card(
      color: settings.color.withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  settings.icon,
                  color: settings.color,
                ),
                const SizedBox(width: 8),
                Text(
                  'Current Environment',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: settings.color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              settings.description,
              style: TextStyle(
                color: settings.color.withOpacity(0.8),
              ),
            ),
            if (showFeatures) ...[
              const SizedBox(height: 16),
              _buildFeaturesList(settings),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFeaturesList(EnvironmentSettings settings) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Features:',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: settings.color,
          ),
        ),
        const SizedBox(height: 8),
        ...settings.features.entries.map((entry) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: [
                Icon(
                  entry.value ? Icons.check_circle : Icons.cancel,
                  size: 16,
                  color: entry.value ? Colors.green : Colors.red,
                ),
                const SizedBox(width: 8),
                Text(
                  entry.key,
                  style: TextStyle(
                    color: entry.value ? Colors.green : Colors.red,
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}
