package com.example.overlay_app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Handler
import android.os.HandlerThread
import android.os.IBinder
import android.os.Looper
import android.util.Log
import androidx.core.app.NotificationCompat

class AppMonitorService : Service() {

    companion object {
        private const val TAG = "AppMonitorService"
        private const val CHANNEL_ID = "app_monitor_channel"
        private const val NOTIFICATION_ID = 1001

        // Increased polling interval for better battery life
        private const val POLL_INTERVAL_MS = 800L

        // Shorter query window for more responsive detection
        private const val USAGE_QUERY_WINDOW_MS = 5000L

        // Blocking rules - set from Flutter
        val blockingRules = mutableListOf<BlockingRule>()

        // Legacy: simple package blocking (still supported)
        val blockedPackages = mutableSetOf<String>()

        // Cache of package name -> app name for pattern matching
        private val appNameCache = mutableMapOf<String, String>()
    }

    // Use background thread for monitoring to reduce main thread load
    private var handlerThread: HandlerThread? = null
    private var backgroundHandler: Handler? = null
    private val mainHandler = Handler(Looper.getMainLooper())

    private var isMonitoring = false
    private var lastForegroundPackage: String? = null
    private var currentMatchedRule: BlockingRule? = null
    private var isOverlayCurrentlyShowing = false

    // Cache UsageStatsManager reference
    private lateinit var usageStatsManager: UsageStatsManager

    private val monitorRunnable = object : Runnable {
        override fun run() {
            if (isMonitoring) {
                checkForegroundApp()
                backgroundHandler?.postDelayed(this, POLL_INTERVAL_MS)
            }
        }
    }

    override fun onCreate() {
        super.onCreate()

        // Cache system service
        usageStatsManager = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager

        // Setup background thread for monitoring
        handlerThread = HandlerThread("AppMonitorThread", android.os.Process.THREAD_PRIORITY_BACKGROUND).apply {
            start()
        }
        backgroundHandler = Handler(handlerThread!!.looper)

        createNotificationChannel()
        startForeground(NOTIFICATION_ID, createNotification())
        buildAppNameCache()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (!isMonitoring) {
            isMonitoring = true
            backgroundHandler?.post(monitorRunnable)
            Log.d(TAG, "App monitoring started with ${blockingRules.size} rules")
        }
        return START_STICKY
    }

    override fun onDestroy() {
        super.onDestroy()
        isMonitoring = false
        backgroundHandler?.removeCallbacks(monitorRunnable)
        handlerThread?.quitSafely()

        // Hide overlay on main thread
        mainHandler.post {
            stopService(Intent(this, OverlayService::class.java))
        }
        isOverlayCurrentlyShowing = false
        Log.d(TAG, "App monitoring stopped")
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun buildAppNameCache() {
        backgroundHandler?.post {
            try {
                val pm = packageManager
                val apps = pm.getInstalledApplications(PackageManager.GET_META_DATA)
                synchronized(appNameCache) {
                    appNameCache.clear()
                    for (app in apps) {
                        val name = pm.getApplicationLabel(app).toString()
                        appNameCache[app.packageName] = name
                    }
                }
                Log.d(TAG, "Built app name cache with ${appNameCache.size} entries")
            } catch (e: Exception) {
                Log.e(TAG, "Error building app name cache", e)
            }
        }
    }

    private fun checkForegroundApp() {
        val foregroundPackage = getForegroundPackage() ?: return

        val matchedRule = findMatchingRule(foregroundPackage)

        // Log only when app changes
        if (foregroundPackage != lastForegroundPackage) {
            Log.d(TAG, "Foreground: $foregroundPackage, blocked: ${matchedRule != null}")
            lastForegroundPackage = foregroundPackage
        }

        if (matchedRule != null) {
            // Need to show overlay
            val needsShow = !isOverlayCurrentlyShowing ||
                    currentMatchedRule?.pattern != matchedRule.pattern

            if (needsShow) {
                currentMatchedRule = matchedRule
                showOverlay(matchedRule)
            }
        } else if (isOverlayCurrentlyShowing) {
            // Was showing overlay, now should hide
            currentMatchedRule = null
            hideOverlay()
        }
    }

    private fun findMatchingRule(packageName: String): BlockingRule? {
        // Don't block ourselves or system UI
        if (packageName == this.packageName ||
            packageName == "com.android.systemui" ||
            packageName.startsWith("com.android.launcher") ||
            packageName == "com.google.android.apps.nexuslauncher") {
            return null
        }

        val appName = synchronized(appNameCache) { appNameCache[packageName] } ?: ""

        // Check rule-based blocking (first match wins)
        for (rule in blockingRules) {
            if (!rule.enabled) continue

            val matches = when (rule.type) {
                RuleType.INDIVIDUAL -> packageName == rule.pattern
                RuleType.NAME_CONTAINS -> appName.contains(rule.pattern, ignoreCase = true)
                RuleType.NAME_STARTS_WITH -> appName.startsWith(rule.pattern, ignoreCase = true)
                RuleType.REGEX -> {
                    try {
                        Regex(rule.pattern).matches(packageName)
                    } catch (e: Exception) {
                        false
                    }
                }
                RuleType.COMPANY -> packageName.startsWith(rule.pattern)
            }

            if (matches) return rule
        }

        // Fallback to legacy blocking
        if (blockedPackages.contains(packageName)) {
            return BlockingRule(
                type = RuleType.INDIVIDUAL,
                pattern = packageName,
                enabled = true,
                imagePaths = emptyList(),
                overlayTexts = BlockingRule.defaultQuotes,
                textX = 0.5f,
                textY = 0.5f,
                imageScale = 1.0f,
                imageOffsetX = 0.0f,
                imageOffsetY = 0.0f
            )
        }

        return null
    }

    private fun getForegroundPackage(): String? {
        val endTime = System.currentTimeMillis()
        val startTime = endTime - USAGE_QUERY_WINDOW_MS

        val usageEvents = usageStatsManager.queryEvents(startTime, endTime)
        var lastEventPackage: String? = null
        var lastEventTime = 0L

        val event = UsageEvents.Event()
        while (usageEvents.hasNextEvent()) {
            usageEvents.getNextEvent(event)
            if (event.eventType == UsageEvents.Event.MOVE_TO_FOREGROUND ||
                event.eventType == UsageEvents.Event.ACTIVITY_RESUMED) {
                if (event.timeStamp > lastEventTime) {
                    lastEventTime = event.timeStamp
                    lastEventPackage = event.packageName
                }
            }
        }

        return lastEventPackage
    }

    private fun showOverlay(rule: BlockingRule) {
        // Random selection from available images and texts
        OverlayService.overlayImagePath = rule.getRandomImagePath()
        OverlayService.overlayText = rule.getRandomText()
        OverlayService.textPositionX = rule.textX
        OverlayService.textPositionY = rule.textY
        OverlayService.imageScale = rule.imageScale
        OverlayService.imageOffsetX = rule.imageOffsetX
        OverlayService.imageOffsetY = rule.imageOffsetY

        mainHandler.post {
            startService(Intent(this, OverlayService::class.java))
        }
        isOverlayCurrentlyShowing = true
    }

    private fun hideOverlay() {
        mainHandler.post {
            stopService(Intent(this, OverlayService::class.java))
        }
        isOverlayCurrentlyShowing = false
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "App Monitor",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Monitors app usage to help you stay focused"
                setShowBadge(false)
            }

            val notificationManager = getSystemService(NotificationManager::class.java)
            notificationManager.createNotificationChannel(channel)
        }
    }

    private fun createNotification(): Notification {
        val ruleCount = blockingRules.count { it.enabled }
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Focus Mode Active")
            .setContentText("Monitoring with $ruleCount blocking rules")
            .setSmallIcon(android.R.drawable.ic_lock_lock)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setOngoing(true)
            .build()
    }
}
