package uz.inha.inhahub

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.widget.RemoteViews

class NextLectureWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        val snap = WidgetDbHelper.loadSnapshot(context)
        for (id in appWidgetIds) {
            appWidgetManager.updateAppWidget(id, buildViews(context, snap))
        }
    }

    companion object {
        fun updateAll(context: Context) {
            val mgr = AppWidgetManager.getInstance(context)
            val ids = mgr.getAppWidgetIds(ComponentName(context, NextLectureWidgetProvider::class.java))
            if (ids.isEmpty()) return
            val snap = WidgetDbHelper.loadSnapshot(context)
            for (id in ids) {
                mgr.updateAppWidget(id, buildViews(context, snap))
            }
        }

        private fun buildViews(context: Context, snap: WidgetSnapshot): RemoteViews {
            val views = RemoteViews(context.packageName, R.layout.widget_next_lecture)
            views.setOnClickPendingIntent(
                R.id.widget_root,
                WidgetDbHelper.createOpenTabIntent(context, 2, 101)
            )

            val next = snap.nextLesson
            if (next == null) {
                views.setTextViewText(
                    R.id.tv_badge,
                    if (snap.isRu) "РАСПИСАНИЕ" else "TIMETABLE"
                )
                views.setTextViewText(R.id.tv_time, snap.group)
                views.setTextViewText(
                    R.id.tv_subject,
                    if (snap.group.isEmpty()) {
                        if (snap.isRu) "Выберите группу в приложении" else "Select your group in app"
                    } else {
                        if (snap.isRu) "Ближайших пар нет" else "No upcoming classes"
                    }
                )
                views.setTextViewText(
                    R.id.tv_meta,
                    if (snap.isRu) "Нажмите, чтобы открыть" else "Tap to open schedule"
                )
                return views
            }

            val badgeText = when {
                snap.minsUntilNext != null -> {
                    val h = snap.minsUntilNext / 60
                    val m = snap.minsUntilNext % 60
                    if (snap.isRu) {
                        if (h > 0) "через ${h}ч ${m}м" else "через $m мин"
                    } else {
                        if (h > 0) "in ${h}h ${m}m" else "in $m min"
                    }
                }
                snap.nextDayCode != null -> dayLabel(snap.nextDayCode, snap.isRu)
                else -> if (snap.isRu) "ДАЛЕЕ" else "NEXT"
            }

            views.setTextViewText(R.id.tv_badge, badgeText)
            views.setTextViewText(R.id.tv_time, "${next.start}–${next.end}")
            views.setTextViewText(R.id.tv_subject, next.subject)
            val metaParts = listOf(next.room, next.teacher).filter { it.isNotEmpty() }
            views.setTextViewText(
                R.id.tv_meta,
                if (metaParts.isNotEmpty()) metaParts.joinToString(" • ") else snap.group
            )
            return views
        }

        private fun dayLabel(code: String, isRu: Boolean): String {
            if (!isRu) return code
            return when (code) {
                "Mon" -> "Пн"
                "Tue" -> "Вт"
                "Wed" -> "Ср"
                "Thu" -> "Чт"
                "Fri" -> "Пт"
                else -> code
            }
        }
    }
}
