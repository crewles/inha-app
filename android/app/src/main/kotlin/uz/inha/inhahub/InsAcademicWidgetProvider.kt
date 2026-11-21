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
            views.setTextViewText(R.id.tv_gpa, if (snap.gpa.isNotEmpty()) snap.gpa else "—")

            val creditsLabel = if (snap.creditsAcquired.isNotEmpty()) {
                val base = if (snap.isRu) "Кредиты" else "Credits"
                if (snap.creditsAttempted.isNotEmpty()) {
                    "$base: ${snap.creditsAcquired}/${snap.creditsAttempted}"
                } else {
                    "$base: ${snap.creditsAcquired}"
                }
            } else {
                if (snap.isRu) "Откройте INS" else "Sync INS portal"
            }
            views.setTextViewText(R.id.tv_credits, creditsLabel)
            views.setTextViewText(
                R.id.tv_courses,
                if (snap.isRu) "${snap.activeCourseCount} активн." else "${snap.activeCourseCount} Active"
            )
            return views
        }
    }
}
