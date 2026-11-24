package uz.inha.inhahub

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.widget.RemoteViews

class InsAcademicWidgetProvider : AppWidgetProvider() {
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
            val ids = mgr.getAppWidgetIds(ComponentName(context, InsAcademicWidgetProvider::class.java))
            if (ids.isEmpty()) return
            val snap = WidgetDbHelper.loadSnapshot(context)
            for (id in ids) {
                mgr.updateAppWidget(id, buildViews(context, snap))
            }
        }

        private fun buildViews(context: Context, snap: WidgetSnapshot): RemoteViews {
            val views = RemoteViews(context.packageName, R.layout.widget_ins_academic)
            views.setOnClickPendingIntent(
                R.id.widget_root,
                WidgetDbHelper.createOpenTabIntent(context, 3, 103)
            )

            views.setTextViewText(R.id.tv_overline, "INS GPA")
            views.setTextViewText(
                R.id.tv_courses,
                WidgetDbHelper.formatCoursesCount(snap.activeCourseCount, snap.isRu)
            )
            views.setTextViewText(R.id.tv_gpa, if (snap.gpa.isNotEmpty()) snap.gpa else "—")

            views.setTextViewText(
                R.id.tv_credits_label,
                if (snap.isRu) "Кредиты" else "Credits"
            )
            val creditsValue = when {
                snap.creditsAcquired.isNotEmpty() && snap.creditsAttempted.isNotEmpty() ->
                    "${snap.creditsAcquired}/${snap.creditsAttempted}"
                snap.creditsAcquired.isNotEmpty() -> snap.creditsAcquired
                else -> "—"
            }
            views.setTextViewText(R.id.tv_credits_value, creditsValue)

            val gpaDouble = snap.gpa.replace(',', '.').toDoubleOrNull() ?: 0.0
            val progress = (gpaDouble.coerceIn(0.0, 4.5) * 100.0).toInt()
            views.setProgressBar(R.id.pb_gpa, 450, progress, false)
            return views
        }
    }
}
