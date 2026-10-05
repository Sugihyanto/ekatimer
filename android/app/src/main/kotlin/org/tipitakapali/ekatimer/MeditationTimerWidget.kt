// android/app/src/main/kotlin/org/tipitakapali/ekatimer/MeditationTimerWidget.kt

package org.tipitakapali.ekatimer

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.os.Build
import android.widget.RemoteViews

/**
 * Base widget provider for meditation timer widgets.
 * Subclasses define the fixed layout type so the user gets the exact
 * widget they chose from the picker.
 */
open class MeditationTimerWidget : AppWidgetProvider() {

    /** Override in each subclass to define which layout and behaviour. */
    open val widgetConfig: WidgetConfig get() = WidgetConfig.QUICK_START_1H

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        // Read saved transparency from native SharedPreferences for cold-start updates
        val prefs = context.getSharedPreferences(
            context.packageName + "_preferences",
            Context.MODE_PRIVATE
        )
        val transparent = prefs.getBoolean(
            COMPANION_PREFS_TRANSPARENT,
            false
        )
        for (appWidgetId in appWidgetIds) {
            val views = buildWidgetViews(context, widgetConfig, transparent)
            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }

    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: android.os.Bundle?,
    ) {
        val prefs = context.getSharedPreferences(
            context.packageName + "_preferences",
            Context.MODE_PRIVATE
        )
        val transparent = prefs.getBoolean(
            COMPANION_PREFS_TRANSPARENT,
            false
        )
        val views = buildWidgetViews(context, widgetConfig, transparent)
        appWidgetManager.updateAppWidget(appWidgetId, views)
    }

    // ── Layout & Action Config ────────────────────────────────────────

    enum class WidgetConfig(
        val layoutRes: Int,
        val actionLabel: String,
        val timerMode: String,
        val timerDuration: Int,   // minutes; 0 means use mode-specific default
        val description: String,
    ) {
        QUICK_START_15M(
            R.layout.widget_quickstart,
            "15m", "timed", 15,
            "Start a 15-minute meditation"
        ),
        QUICK_START_30M(
            R.layout.widget_quickstart,
            "30m", "timed", 30,
            "Start a 30-minute meditation"
        ),
        QUICK_START_1H(
            R.layout.widget_quickstart,
            "1H", "timed", 60,
            "Start a 1-hour meditation"
        ),
        QUICK_START_1_5H(
            R.layout.widget_quickstart,
            "1.5H", "timed", 90,
            "Start a 1.5-hour meditation"
        ),
        QUICK_START_2H(
            R.layout.widget_quickstart,
            "2H", "timed", 120,
            "Start a 2-hour meditation"
        ),
        QUICK_START_2_5H(
            R.layout.widget_quickstart,
            "2.5H", "timed", 150,
            "Start a 2.5-hour meditation"
        ),
        QUICK_START_3H(
            R.layout.widget_quickstart,
            "3H", "timed", 180,
            "Start a 3-hour meditation"
        ),
        QUICK_START_3_5H(
            R.layout.widget_quickstart,
            "3.5H", "timed", 210,
            "Start a 3.5-hour meditation"
        ),
        QUICK_START_4H(
            R.layout.widget_quickstart,
            "4H", "timed", 240,
            "Start a 4-hour meditation"
        ),
        QUICK_START_END_AT(
            R.layout.widget_quickstart,
            "End", "endAt", 0,
            "Set an end-time meditation"
        ),
        QUICK_START_UNTIMED(
            R.layout.widget_quickstart,
            "∞", "unlimited", 0,
            "Start an unlimited meditation"
        );
    }

    // ── Transparent Widget Support & View Building ───────────────────

    companion object {
        // Key used for native-side SharedPreferences persistence
        private const val COMPANION_PREFS_TRANSPARENT = "transparent_widget"

        /// Force-update all widget types with the given transparency value.
        ///
        /// The [transparent] flag is passed directly from Flutter and also
        /// persisted to the app's native SharedPreferences so that cold-start
        /// widget updates (e.g. after a reboot) can still read it.
        fun updateAllWidgets(context: Context, transparent: Boolean) {
            // Persist to native SharedPreferences (same file the widget reads on cold start)
            val prefs = context.getSharedPreferences(
                context.packageName + "_preferences",
                Context.MODE_PRIVATE
            )
            prefs.edit().putBoolean(COMPANION_PREFS_TRANSPARENT, transparent).apply()

            // Update all widget instances
            val appWidgetManager = AppWidgetManager.getInstance(context)
            val providers = listOf(
                Meditation15mWidget::class.java,
                Meditation30mWidget::class.java,
                Meditation1HWidget::class.java,
                Meditation1_5HWidget::class.java,
                Meditation2HWidget::class.java,
                Meditation2_5HWidget::class.java,
                Meditation3HWidget::class.java,
                Meditation3_5HWidget::class.java,
                Meditation4HWidget::class.java,
                MeditationEndAtWidget::class.java,
                MeditationUnlimitedWidget::class.java,
            )
            providers.forEach { providerClass ->
                val ids = appWidgetManager.getAppWidgetIds(
                    ComponentName(context, providerClass)
                )
                if (ids.isNotEmpty()) {
                    for (appWidgetId in ids) {
                        val config = when (providerClass) {
                            Meditation15mWidget::class.java -> WidgetConfig.QUICK_START_15M
                            Meditation30mWidget::class.java -> WidgetConfig.QUICK_START_30M
                            Meditation1HWidget::class.java -> WidgetConfig.QUICK_START_1H
                            Meditation1_5HWidget::class.java -> WidgetConfig.QUICK_START_1_5H
                            Meditation2HWidget::class.java -> WidgetConfig.QUICK_START_2H
                            Meditation2_5HWidget::class.java -> WidgetConfig.QUICK_START_2_5H
                            Meditation3HWidget::class.java -> WidgetConfig.QUICK_START_3H
                            Meditation3_5HWidget::class.java -> WidgetConfig.QUICK_START_3_5H
                            Meditation4HWidget::class.java -> WidgetConfig.QUICK_START_4H
                            MeditationEndAtWidget::class.java -> WidgetConfig.QUICK_START_END_AT
                            MeditationUnlimitedWidget::class.java -> WidgetConfig.QUICK_START_UNTIMED
                            else -> return@forEach
                        }
                        val views = buildWidgetViews(context, config, transparent)
                        appWidgetManager.updateAppWidget(appWidgetId, views)
                    }
                }
            }
        }

        /// Build a RemoteViews instance for the given widget configuration.
        ///
        /// When [transparent] is true, the widget background is set to fully
        /// transparent so it blends with the user's wallpaper.
        fun buildWidgetViews(
            context: Context,
            config: WidgetConfig,
            transparent: Boolean = false,
        ): RemoteViews {
        val views = RemoteViews(context.packageName, config.layoutRes)
        // Render the artwork inside a circular mask; screenshot-style backgrounds
        // outside the glass rim must never appear on the home screen.
        val source = android.graphics.BitmapFactory.decodeResource(context.resources, R.drawable.widget_circle)
        val art = android.graphics.Bitmap.createBitmap(256, 256, android.graphics.Bitmap.Config.ARGB_8888)
        val canvas = android.graphics.Canvas(art)
        val paint = android.graphics.Paint(android.graphics.Paint.ANTI_ALIAS_FLAG or android.graphics.Paint.FILTER_BITMAP_FLAG)
        canvas.drawCircle(128f, 128f, 128f, paint)
        paint.xfermode = android.graphics.PorterDuffXfermode(android.graphics.PorterDuff.Mode.SRC_IN)
        canvas.drawBitmap(source,
            android.graphics.Rect((source.width * .024f).toInt(), (source.height * .018f).toInt(),
                (source.width * .973f).toInt(), (source.height * .950f).toInt()),
            android.graphics.RectF(0f, 0f, 256f, 256f), paint)
        source.recycle()
        views.setImageViewBitmap(R.id.widget_logo, art)

        // Set the label on the shared quick-start layout
        val durationLabel = if (config.timerMode == "timed") {
            if (config.timerDuration < 60) "${config.timerDuration}:00"
            else "${config.timerDuration / 60}:${(config.timerDuration % 60).toString().padStart(2, '0')}:00"
        } else config.actionLabel
        views.setTextViewText(R.id.widget_action_label, durationLabel)
        views.setInt(R.id.widget_logo, "setImageAlpha", if (transparent) 150 else 255)

        // Apply transparency – use android.R.color.transparent for the
        // background so the widget blends with the user's wallpaper.
        if (transparent) {
            views.setInt(
                R.id.widget_container,
                "setBackgroundResource",
                android.R.color.transparent
            )
            views.setTextColor(R.id.widget_action_label, Color.WHITE)
        } else {
            // Restore the normal styled background drawable
            views.setInt(
                R.id.widget_container,
                "setBackgroundResource",
                android.R.color.transparent
            )
        }

        // Open app on widget tap via launch intent with extras
        val intent = context.packageManager.getLaunchIntentForPackage(
            context.packageName
        ) ?: Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                    Intent.FLAG_ACTIVITY_CLEAR_TOP or
                    Intent.FLAG_ACTIVITY_SINGLE_TOP
        }

        intent.putExtra("widget_timer_mode", config.timerMode)
        intent.putExtra("widget_timer_duration", config.timerDuration)

        val pendingIntentFlags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        } else {
            PendingIntent.FLAG_UPDATE_CURRENT
        }

        val pendingIntent = PendingIntent.getActivity(
            context,
            config.ordinal, // unique request code per widget type
            intent,
            pendingIntentFlags
        )
        views.setOnClickPendingIntent(R.id.widget_container, pendingIntent)
        views.setOnClickPendingIntent(R.id.widget_play, pendingIntent)

        return views
    }
    }
}

// ── Concrete Widget Subclasses ───────────────────────────────────────

class Meditation15mWidget : MeditationTimerWidget() {
    override val widgetConfig get() = WidgetConfig.QUICK_START_15M
}

class Meditation30mWidget : MeditationTimerWidget() {
    override val widgetConfig get() = WidgetConfig.QUICK_START_30M
}

class Meditation1HWidget : MeditationTimerWidget() {
    override val widgetConfig get() = WidgetConfig.QUICK_START_1H
}

class Meditation1_5HWidget : MeditationTimerWidget() {
    override val widgetConfig get() = WidgetConfig.QUICK_START_1_5H
}

class Meditation2HWidget : MeditationTimerWidget() {
    override val widgetConfig get() = WidgetConfig.QUICK_START_2H
}

class Meditation2_5HWidget : MeditationTimerWidget() {
    override val widgetConfig get() = WidgetConfig.QUICK_START_2_5H
}

class Meditation3HWidget : MeditationTimerWidget() {
    override val widgetConfig get() = WidgetConfig.QUICK_START_3H
}

class Meditation3_5HWidget : MeditationTimerWidget() {
    override val widgetConfig get() = WidgetConfig.QUICK_START_3_5H
}

class Meditation4HWidget : MeditationTimerWidget() {
    override val widgetConfig get() = WidgetConfig.QUICK_START_4H
}

class MeditationEndAtWidget : MeditationTimerWidget() {
    override val widgetConfig get() = WidgetConfig.QUICK_START_END_AT
}

class MeditationUnlimitedWidget : MeditationTimerWidget() {
    override val widgetConfig get() = WidgetConfig.QUICK_START_UNTIMED
}
