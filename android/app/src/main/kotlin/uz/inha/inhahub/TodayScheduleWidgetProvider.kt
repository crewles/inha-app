package uz.inha.inhahub

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.view.View
import android.widget.RemoteViews

class TodayScheduleWidgetProvider : AppWidgetProvider() {
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
        private val ruDays = listOf("Понедельник", "Вторник", "Среда", "Четверг", "Пятница")
        private val enDays = listOf("Monday", "Tuesday", "Wednesday", "Thursday", "Friday")

        fun updateAll(context: Context) {
            val mgr = AppWidgetManager.getInstance(context)
            val ids = mgr.getAppWidgetIds(ComponentName(context, TodayScheduleWidgetProvider::class.java))
            if (ids.isEmpty()) return
            val snap = WidgetDbHelper.loadSnapshot(context)
            for (id in ids) {
                mgr.updateAppWidget(id, buildViews(context, snap))
            }
        }

        private fun buildViews(context: Context, snap: WidgetSnapshot): RemoteViews {
            val views = RemoteViews(context.packageName, R.layout.widget_today_schedule)
            views.setOnClickPendingIntent(
                R.id.widget_root,
                WidgetDbHelper.createOpenTabIntent(context, 2, 102)
            )

            val dayTitle = if (snap.isRu) ruDays[snap.todayWeekdayIdx] else enDays[snap.todayWeekdayIdx]
            views.setTextViewText(R.id.tv_header, dayTitle)
            views.setTextViewText(
                R.id.tv_count_pill,
                if (snap.isRu) "${snap.todayLessons.size} пар" else "${snap.todayLessons.size} classes"
            )

            val rowIds = intArrayOf(R.id.row_1, R.id.row_2, R.id.row_3, R.id.row_4)
            val timeIds = intArrayOf(R.id.row_1_time, R.id.row_2_time, R.id.row_3_time, R.id.row_4_time)
            val subjIds = intArrayOf(R.id.row_1_subject, R.id.row_2_subject, R.id.row_3_subject, R.id.row_4_subject)
            val roomIds = intArrayOf(R.id.row_1_room, R.id.row_2_room, R.id.row_3_room, R.id.row_4_room)

            if (snap.todayLessons.isEmpty()) {
                views.setViewVisibility(R.id.tv_empty, View.VISIBLE)
                views.setTextViewText(
                    R.id.tv_empty,
                    if (snap.group.isEmpty()) {
                        if (snap.isRu) "Выберите группу в Расписании" else "Select a group in Timetable"
                    } else {
                        if (snap.isRu) "Сегодня пар нет" else "No classes today"
                    }
                )
                for (rId in rowIds) {
                    views.setViewVisibility(rId, View.GONE)
                }
                return views
            }

            views.setViewVisibility(R.id.tv_empty, View.GONE)
            for (i in 0 until 4) {
                if (i < snap.todayLessons.size) {
                    val l = snap.todayLessons[i]
                    views.setViewVisibility(rowIds[i], View.VISIBLE)
                    views.setTextViewText(timeIds[i], l.start)
                    views.setTextViewText(subjIds[i], l.subject)
                    views.setTextViewText(roomIds[i], l.room)
                } else {
                    views.setViewVisibility(rowIds[i], View.GONE)
                }
            }
            return views
        }
    }
}
