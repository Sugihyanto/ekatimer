// android/app/src/main/kotlin/org/tipitakapali/ekatimer/MainActivity.kt

package org.tipitakapali.ekatimer

import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.PowerManager
import android.provider.Settings
import android.util.Log
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    // Cross-language API: keep these names synchronized with the Dart services.
    // A typo here still compiles, then surfaces as MissingPluginException.
    private val WIDGET_CHANNEL = "org.tipitakapali.ekatimer/widget"
    private val BATTERY_CHANNEL = "org.tipitakapali.ekatimer/background_settings"
    private var widgetTimerMode: String? = null
    private var widgetTimerDuration: Int? = null
    private var widgetAction: String? = null
    private var widgetStatsPeriod: String? = null
    private var methodChannel: MethodChannel? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (intent?.getIntExtra("from_alarm", -1) != -1) {
            window.addFlags(
                WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
                WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD
            )
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        readWidgetIntent(intent)

        methodChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            WIDGET_CHANNEL
        )
        methodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "updateAllWidgets" -> {
                    val transparent = call.argument<Boolean>("transparent") ?: false
                    MeditationTimerWidget.updateAllWidgets(
                        applicationContext,
                        transparent
                    )
                    result.success(null)
                }
                "getWidgetAction", "peekWidgetAction" -> {
                    val data = mutableMapOf<String, Any>()
                    if (widgetTimerMode != null) {
                        data["timerMode"] = widgetTimerMode!!
                        data["timerDuration"] = widgetTimerDuration ?: 0
                    }
                    if (widgetAction != null) {
                        data["action"] = widgetAction!!
                        data["statsPeriod"] = widgetStatsPeriod ?: "week"
                    }
                    if ((intent?.getIntExtra("from_alarm", -1) ?: -1) != -1) {
                        data["fromAlarm"] = true
                    }

                    if (call.method == "getWidgetAction") {
                        widgetTimerMode = null
                        widgetTimerDuration = null
                        widgetAction = null
                        widgetStatsPeriod = null

                        intent?.removeExtra("widget_timer_mode")
                        intent?.removeExtra("widget_timer_duration")
                        intent?.removeExtra("widget_action")
                        intent?.removeExtra("widget_stats_period")
                        intent?.removeExtra("from_alarm")
                    }

                    result.success(data.ifEmpty { null })
                }
                else -> result.notImplemented()
            }
        }

        // ── Battery / Background Settings channel ─────────────────────
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            BATTERY_CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "isBatteryOptimizationIgnored" -> {
                    val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
                    result.success(pm.isIgnoringBatteryOptimizations(packageName))
                }
                "requestIgnoreBatteryOptimization" -> {
                    try {
                        val intent = Intent(
                            Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS,
                            Uri.parse("package:$packageName")
                        )
                        startActivity(intent)
                        result.success(null)
                    } catch (e: Exception) {
                        // Fallback: open app details page
                        try {
                            val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                                data = Uri.parse("package:$packageName")
                            }
                            startActivity(intent)
                            result.success(null)
                        } catch (e2: Exception) {
                            result.error("ACTIVITY_NOT_FOUND", e2.message, null)
                        }
                    }
                }
                "openOemBackgroundSettings" -> {
                    try {
                        startActivity(buildOemIntent())
                        result.success(null)
                    } catch (e: Exception) {
                        // Fallback: open app details page
                        try {
                            val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                                data = Uri.parse("package:$packageName")
                            }
                            startActivity(intent)
                            result.success(null)
                        } catch (e2: Exception) {
                            result.error("ACTIVITY_NOT_FOUND", e2.message, null)
                        }
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun buildOemIntent(): Intent {
        val manufacturer = Build.MANUFACTURER.lowercase()
        return when {
            manufacturer.contains("xiaomi") -> {
                Intent().apply {
                    component = ComponentName(
                        "com.miui.securitycenter",
                        "com.miui.securitycenter.backgroundpermission.PermissionsEditorActivity"
                    )
                    putExtra("package_name", packageName)
                }
            }
            manufacturer.contains("huawei") || manufacturer.contains("honor") -> {
                Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                    data = Uri.parse("package:$packageName")
                }
            }
            manufacturer.contains("oppo") || manufacturer.contains("realme") -> {
                Intent().apply {
                    component = ComponentName(
                        "com.coloros.safecenter",
                        "com.coloros.safecenter.startupapp.StartupAppListActivity"
                    )
                }
            }
            manufacturer.contains("vivo") -> {
                Intent().apply {
                    component = ComponentName(
                        "com.vivo.permissionmanager",
                        "com.vivo.permissionmanager.activity.SoftPermissionDetailActivity"
                    )
                    putExtra("packagename", packageName)
                }
            }
            manufacturer.contains("oneplus") -> {
                Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                    data = Uri.parse("package:$packageName")
                }
            }
            manufacturer.contains("samsung") -> {
                Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                    data = Uri.parse("package:$packageName")
                }
            }
            else -> {
                Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                    data = Uri.parse("package:$packageName")
                }
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        readWidgetIntent(intent)
        if (intent.getIntExtra("from_alarm", -1) != -1) {
            window.addFlags(
                WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
                WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD or
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED
            )
        }
    }

    private fun readWidgetIntent(intent: Intent?) {
        intent?.let {
            widgetTimerMode = it.getStringExtra("widget_timer_mode")
            widgetTimerDuration = if (it.hasExtra("widget_timer_duration")) {
                it.getIntExtra("widget_timer_duration", 0)
            } else {
                null
            }
            widgetAction = it.getStringExtra("widget_action")
            widgetStatsPeriod = it.getStringExtra("widget_stats_period")
        }
    }

    companion object {
        private const val TAG = "MainActivity"
    }
}
