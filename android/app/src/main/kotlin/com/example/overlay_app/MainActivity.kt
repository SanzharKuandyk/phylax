package com.example.overlay_app

import android.app.ActivityManager
import android.app.AppOpsManager
import android.content.Context
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Process
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val CHANNEL = "overlay_channel"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "requestOverlayPermission" -> {
                        requestOverlayPermission()
                        result.success(null)
                    }
                    "requestUsageStatsPermission" -> {
                        requestUsageStatsPermission()
                        result.success(null)
                    }
                    "hasOverlayPermission" -> {
                        result.success(Settings.canDrawOverlays(this))
                    }
                    "hasUsageStatsPermission" -> {
                        result.success(hasUsageStatsPermission())
                    }
                    "startMonitoring" -> {
                        val intent = Intent(this, AppMonitorService::class.java)
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            startForegroundService(intent)
                        } else {
                            startService(intent)
                        }
                        result.success(null)
                    }
                    "stopMonitoring" -> {
                        stopService(Intent(this, AppMonitorService::class.java))
                        result.success(null)
                    }
                    "isMonitoring" -> {
                        result.success(isServiceRunning(AppMonitorService::class.java))
                    }
                    "startOverlay" -> {
                        startService(Intent(this, OverlayService::class.java))
                        result.success(null)
                    }
                    "stopOverlay" -> {
                        stopService(Intent(this, OverlayService::class.java))
                        result.success(null)
                    }
                    "setBlockedPackages" -> {
                        @Suppress("UNCHECKED_CAST")
                        val packages = call.argument<List<String>>("packages") ?: emptyList()
                        AppMonitorService.blockedPackages.clear()
                        AppMonitorService.blockedPackages.addAll(packages)
                        result.success(null)
                    }
                    "getInstalledApps" -> {
                        result.success(getInstalledApps())
                    }
                    "setOverlayConfig" -> {
                        OverlayService.overlayImagePath = call.argument<String>("imagePath")
                        OverlayService.overlayText = call.argument<String>("text") ?: "Stay Focused!"
                        OverlayService.textPositionX = (call.argument<Double>("textX") ?: 0.5).toFloat()
                        OverlayService.textPositionY = (call.argument<Double>("textY") ?: 0.5).toFloat()
                        result.success(null)
                    }
                    "setBlockingRules" -> {
                        @Suppress("UNCHECKED_CAST")
                        val rulesData = call.argument<List<Map<String, Any?>>>("rules") ?: emptyList()
                        AppMonitorService.blockingRules.clear()
                        AppMonitorService.blockingRules.addAll(
                            rulesData.map {
                                val imagePaths = (it["imagePaths"] as? List<*>)?.filterIsInstance<String>() ?: emptyList()
                                val overlayTexts = (it["overlayTexts"] as? List<*>)?.filterIsInstance<String>()
                                    ?.takeIf { list -> list.isNotEmpty() } ?: BlockingRule.defaultQuotes
                                BlockingRule(
                                    type = RuleType.values()[(it["type"] as Int)],
                                    pattern = it["pattern"] as String,
                                    enabled = it["enabled"] as Boolean,
                                    imagePaths = imagePaths,
                                    overlayTexts = overlayTexts,
                                    textX = (it["textX"] as? Double)?.toFloat() ?: 0.5f,
                                    textY = (it["textY"] as? Double)?.toFloat() ?: 0.5f,
                                    imageScale = (it["imageScale"] as Double?)?.toFloat() ?: 1.0f,
                                    imageOffsetX = (it["imageOffsetX"] as Double?)?.toFloat() ?: 0.0f,
                                    imageOffsetY = (it["imageOffsetY"] as Double?)?.toFloat() ?: 0.0f
                                )
                            }
                        )
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun requestOverlayPermission() {
        if (!Settings.canDrawOverlays(this)) {
            val intent = Intent(
                Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                Uri.parse("package:$packageName")
            )
            startActivity(intent)
        }
    }

    private fun requestUsageStatsPermission() {
        if (!hasUsageStatsPermission()) {
            startActivity(Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS))
        }
    }

    private fun hasUsageStatsPermission(): Boolean {
        val appOps = getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
        val mode = appOps.checkOpNoThrow(
            AppOpsManager.OPSTR_GET_USAGE_STATS,
            Process.myUid(),
            packageName
        )
        return mode == AppOpsManager.MODE_ALLOWED
    }

    private fun getInstalledApps(): List<Map<String, String>> {
        val pm = packageManager

        // Get all apps that have a launcher activity (apps user can open)
        val mainIntent = Intent(Intent.ACTION_MAIN, null).apply {
            addCategory(Intent.CATEGORY_LAUNCHER)
        }

        val launchableApps = pm.queryIntentActivities(mainIntent, 0)

        // Exclude our own app and critical system components
        val excludedPackages = setOf(
            packageName, // Our own app
        )

        return launchableApps
            .filter { resolveInfo ->
                !excludedPackages.contains(resolveInfo.activityInfo.packageName)
            }
            .map { resolveInfo ->
                val appInfo = resolveInfo.activityInfo.applicationInfo
                val isSystemApp = (appInfo.flags and ApplicationInfo.FLAG_SYSTEM) != 0
                mapOf(
                    "packageName" to resolveInfo.activityInfo.packageName,
                    "appName" to resolveInfo.loadLabel(pm).toString(),
                    "isSystemApp" to isSystemApp.toString()
                )
            }
            .distinctBy { it["packageName"] }
            .sortedBy { it["appName"]?.lowercase() }
    }

    @Suppress("DEPRECATION")
    private fun isServiceRunning(serviceClass: Class<*>): Boolean {
        val manager = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
        for (service in manager.getRunningServices(Int.MAX_VALUE)) {
            if (serviceClass.name == service.service.className) {
                return true
            }
        }
        return false
    }
}
