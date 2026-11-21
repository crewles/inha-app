package uz.inha.inhahub

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.view.View
import android.widget.RemoteViews

class DeadlinesWidgetProvider : AppWidgetProvider() {
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
            val ids = mgr.getAppWidgetIds(ComponentName(context, DeadlinesWidgetProvider::class.java))
            if (ids.isEmpty()) return
            val snap = WidgetDbHelper.loadSnapshot(context)
            for (id in ids) {
                mgr.updateAppWidget(id, buildViews(context, snap))
            }
        }

        private fun buildViews(context: Context, snap: WidgetSnapshot): RemoteViews {
            val views = RemoteViews(context.packageName, R.layout.widget_deadlines)
            views.setOnClickPendingIntent(
                R.id.widget_root,
                WidgetDbHelper.createOpenTabIntent(context, 1, 104)
            )

            views.setTextViewText(
                R.id.tv_header,
                if (snap.isRu) "Дедлайны eClass" else "Deadlines"
            )
            views.setTextViewText(
                R.id.tv_pending_pill,
                if (snap.isRu) "${snap.pendingDeadlines.size} активн." else "${snap.pendingDeadlines.size} due"
            )

            val rowIds = intArrayOf(R.id.row_1, R.id.row_2, R.id.row_3)
            val dotIds = intArrayOf(R.id.row_1_dot, R.id.row_2_dot, R.id.row_3_dot)
            val titleIds = intArrayOf(R.id.row_1_title, R.id.row_2_title, R.id.row_3_title)
            val dueIds = intArrayOf(R.id.row_1_due, R.id.row_2_due, R.id.row_3_due)

            if (snap.pendingDeadlines.isEmpty()) {
                views.setViewVisibility(R.id.tv_empty, View.VISIBLE)
                views.setTextViewText(
                    R.id.tv_empty,
                    if (snap.isRu) "Всё сдано ✓" else "All caught up ✓"
                )
                for (rId in rowIds) {
                    views.setViewVisibility(rId, View.GONE)
                }
                return views
            }

            val nowSec = System.currentTimeMillis() / 1000L
            views.setViewVisibility(R.id.tv_empty, View.GONE)
            for (i in 0 until 3) {
                if (i < snap.pendingDeadlines.size) {
                    val d = snap.pendingDeadlines[i]
                    views.setViewVisibility(rowIds[i], View.VISIBLE)
                    views.setTextViewText(titleIds[i], d.name)
                    views.setTextViewText(dueIds[i], d.due)
                    val diff = d.dueTs - nowSec
                    val dotRes = when {
                        d.dueTs > 0 && diff <= 48L * 3600L -> R.drawable.widget_dot_urgent
                        d.dueTs > 0 && diff <= 7L * 86400L -> R.drawable.widget_dot_soon
                        else -> R.drawable.widget_dot_normal
                    }
                    views.setImageViewResource(dotIds[i], dotRes)
                } else {
                    views.setViewVisibility(rowIds[i], View.GONE)
                }
            }
            return views
        }
    }
}
