import 'package:flutter/services.dart';
import '../models/blocking_rule.dart';

class PlatformService {
  static const _channel = MethodChannel('overlay_channel');

  // Permissions
  static Future<bool> hasOverlayPermission() async {
    return await _channel.invokeMethod<bool>('hasOverlayPermission') ?? false;
  }

  static Future<void> requestOverlayPermission() async {
    await _channel.invokeMethod('requestOverlayPermission');
  }

  static Future<bool> hasUsageStatsPermission() async {
    return await _channel.invokeMethod<bool>('hasUsageStatsPermission') ??
        false;
  }

  static Future<void> requestUsageStatsPermission() async {
    await _channel.invokeMethod('requestUsageStatsPermission');
  }

  // Monitoring
  static Future<void> startMonitoring() async {
    await _channel.invokeMethod('startMonitoring');
  }

  static Future<void> stopMonitoring() async {
    await _channel.invokeMethod('stopMonitoring');
  }

  static Future<bool> isMonitoring() async {
    return await _channel.invokeMethod<bool>('isMonitoring') ?? false;
  }

  // Apps
  static Future<List<AppInfo>> getInstalledApps() async {
    final result = await _channel.invokeMethod<List>('getInstalledApps');
    if (result == null) return [];

    return result
        .map(
          (app) => AppInfo(
            packageName: app['packageName'] as String,
            appName: app['appName'] as String,
            isSystemApp: app['isSystemApp'] == 'true',
          ),
        )
        .toList();
  }

  // Rules - send to native for matching
  static Future<void> setBlockingRules(List<BlockingRule> rules) async {
    final rulesData = rules
        .map(
          (r) => {
            'type': r.type.index,
            'pattern': r.pattern,
            'enabled': r.enabled,
            'imagePaths': r.imagePaths,
            'overlayTexts': r.overlayTexts,
            'textX': r.textPositionX,
            'textY': r.textPositionY,
            'imageScale': r.imageScale,
            'imageOffsetX': r.imageOffsetX,
            'imageOffsetY': r.imageOffsetY,
          },
        )
        .toList();

    await _channel.invokeMethod('setBlockingRules', {'rules': rulesData});
  }

  // Legacy methods for backwards compatibility
  static Future<void> setBlockedPackages(List<String> packages) async {
    await _channel.invokeMethod('setBlockedPackages', {'packages': packages});
  }

  static Future<void> setOverlayConfig({
    String? imagePath,
    String? text,
    double? textX,
    double? textY,
  }) async {
    await _channel.invokeMethod('setOverlayConfig', {
      'imagePath': imagePath,
      'text': text,
      'textX': textX,
      'textY': textY,
    });
  }
}

class AppInfo {
  final String packageName;
  final String appName;
  final bool isSystemApp;

  AppInfo({
    required this.packageName,
    required this.appName,
    this.isSystemApp = false,
  });

  String get companyPrefix {
    final parts = packageName.split('.');
    if (parts.length >= 2) {
      return '${parts[0]}.${parts[1]}';
    }
    return packageName;
  }
}
