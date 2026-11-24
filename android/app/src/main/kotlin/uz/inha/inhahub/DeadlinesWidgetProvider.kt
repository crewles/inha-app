package uz.inha.inhahub

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.os.Bundle
import android.view.View
import android.widget.RemoteViews
import androidx.core.content.ContextCompat

class DeadlinesWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        val snap = WidgetDbHelper.loadSnapshot(context)
        for (id in appWidgetIds) {
            val opts = appWidgetManager.getAppWidgetOptions(id)
            appWidgetManager.updateAppWidget(id, buildViews(context, snap, maxRowsForOptions(opts)))
        }
    }

    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: Bundle
    ) {
        val snap = WidgetDbHelper.loadSnapshot(context)
        appWidgetManager.updateAppWidget(
            appWidgetId,
            buildViews(context, snap, maxRowsForOptions(newOptions))
        )
    }

    companion object {
        fun updateAll(context: Context) {
            val mgr = AppWidgetManager.getInstance(context)
            val ids = mgr.getAppWidgetIds(ComponentName(context, DeadlinesWidgetProvider::class.java))
            if (ids.isEmpty()) return
            val snap = WidgetDbHelper.loadSnapshot(context)
            for (id in ids) {
                val opts = mgr.getAppWidgetOptions(id)
                mgr.updateAppWidget(id, buildViews(context, snap, maxRowsForOptions(opts)))
            }
        }

        private fun maxRowsForOptions(options: Bundle?): Int {
            val maxH = options?.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT, 0) ?: 0
            return if (maxH in 1..175) 2 else 3
        }

        private fun buildViews(context: Context, snap: WidgetSnapshot, maxRows: Int): RemoteViews {
            val views = RemoteViews(context.packageName, R.layout.widget_deadlines)
            views.setOnClickPendingIntent(
                R.id.widget_root,
                WidgetDbHelper.createOpenTabIntent(context, 1, 104)
            )

            views.setTextViewText(
                R.id.tv_header,
                if (snap.isRu) "Дедлайны" else "Deadlines"
            )
            views.setTextViewText(
                R.id.tv_pending_pill,
                WidgetDbHelper.formatDueCount(snap.pendingDeadlines.size, snap.isRu)
            )

            val hasDue = snap.pendingDeadlines.isNotEmpty()
            views.setInt(
                R.id.tv_pending_pill,
                "setBackgroundResource",
                if (hasDue) R.drawable.widget_pill_error else R.drawable.widget_pill_ok
            )
            views.setTextColor(
                R.id.tv_pending_pill,
                ContextCompat.getColor(
                    context,
                    if (hasDue) R.color.widget_pill_error_fg else R.color.widget_pill_ok_fg
                )
            )

            val rowIds = intArrayOf(R.id.row_1, R.id.row_2, R.id.row_3)
            val barIds = intArrayOf(R.id.row_1_bar, R.id.row_2_bar, R.id.row_3_bar)
            val titleIds = intArrayOf(R.id.row_1_title, R.id.row_2_title, R.id.row_3_title)
            val courseIds = intArrayOf(R.id.row_1_course, R.id.row_2_course, R.id.row_3_course)
            val dueIds = intArrayOf(R.id.row_1_due, R.id.row_2_due, R.id.row_3_due)

            if (!hasDue) {
                views.setViewVisibility(R.id.empty_container, View.VISIBLE)
                views.setTextViewText(
                    R.id.tv_empty,
                    if (snap.isRu) "Всё сдано" else "All caught up"
                )
                for (rId in rowIds) {
                    views.setViewVisibility(rId, View.GONE)
                }
                return views
            }

            val nowSec = System.currentTimeMillis() / 1000L
            val limit = maxRows.coerceIn(1, 3)
            views.setViewVisibility(R.id.empty_container, View.GONE)
            for (i in 0 until 3) {
                if (i < snap.pendingDeadlines.size && i < limit) {
                    val d = snap.pendingDeadlines[i]
                    val diff = d.dueTs - nowSec
                    val isUrgent = d.dueTs > 0 && diff <= 48L * 3600L
                    val isSoon = !isUrgent && d.dueTs > 0 && diff <= 7L * 86400L

                    val barRes = when {
                        isUrgent -> R.drawable.widget_bar_urgent
                        isSoon -> R.drawable.widget_bar_soon
                        else -> R.drawable.widget_bar_normal
                    }
                    val dueBgRes = when {
                        isUrgent -> R.drawable.widget_due_pill_urgent
                        isSoon -> R.drawable.widget_due_pill_soon
                        else -> R.drawable.widget_due_pill_normal
                    }
                    val dueFgColorRes = when {
                        isUrgent -> R.color.widget_due_urgent_fg
                        isSoon -> R.color.widget_due_soon_fg
                        else -> R.color.widget_due_normal_fg
                    }

                    views.setViewVisibility(rowIds[i], View.VISIBLE)
                    views.setImageViewResource(barIds[i], barRes)
                    views.setTextViewText(titleIds[i], d.name)

                    if (d.courseName.isNotEmpty()) {
                        views.setViewVisibility(courseIds[i], View.VISIBLE)
                        views.setTextViewText(courseIds[i], d.courseName)
                    } else {
                        views.setViewVisibility(courseIds[i], View.GONE)
                    }

                    val dueLabel = WidgetDbHelper.formatShortDue(d.dueTs, d.due, snap.isRu)
                    if (dueLabel.isNotEmpty()) {
                        views.setViewVisibility(dueIds[i], View.VISIBLE)
                        views.setTextViewText(dueIds[i], dueLabel)
                        views.setInt(dueIds[i], "setBackgroundResource", dueBgRes)
                        views.setTextColor(dueIds[i], ContextCompat.getColor(context, dueFgColorRes))
                    } else {
                        views.setViewVisibility(dueIds[i], View.GONE)
                    }
                } else {
                    views.setViewVisibility(rowIds[i], View.GONE)
                }
            }
            return views
        }
    }
}
