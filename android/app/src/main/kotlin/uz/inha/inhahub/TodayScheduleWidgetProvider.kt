package uz.inha.inhahub

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.os.Bundle
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
        private val dayCodes = listOf("Mon", "Tue", "Wed", "Thu", "Fri")
        private val ruDays = listOf("Понедельник", "Вторник", "Среда", "Четверг", "Пятница")
        private val enDays = listOf("Monday", "Tuesday", "Wednesday", "Thursday", "Friday")

        fun updateAll(context: Context) {
            val mgr = AppWidgetManager.getInstance(context)
            val ids = mgr.getAppWidgetIds(ComponentName(context, TodayScheduleWidgetProvider::class.java))
            if (ids.isEmpty()) return
            val snap = WidgetDbHelper.loadSnapshot(context)
            for (id in ids) {
                val opts = mgr.getAppWidgetOptions(id)
                mgr.updateAppWidget(id, buildViews(context, snap, maxRowsForOptions(opts)))
            }
        }

        private fun maxRowsForOptions(options: Bundle?): Int {
            val maxH = options?.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT, 0) ?: 0
            return if (maxH in 1..205) 3 else 4
        }

        private fun buildViews(context: Context, snap: WidgetSnapshot, maxRows: Int): RemoteViews {
            val views = RemoteViews(context.packageName, R.layout.widget_today_schedule)
            views.setOnClickPendingIntent(
                R.id.widget_root,
                WidgetDbHelper.createOpenTabIntent(context, 2, 102)
            )

            val dayTitle = if (snap.isRu) ruDays[snap.todayWeekdayIdx] else enDays[snap.todayWeekdayIdx]
            views.setTextViewText(R.id.tv_header, dayTitle)
            if (snap.group.isNotEmpty()) {
                views.setViewVisibility(R.id.tv_group, View.VISIBLE)
                views.setTextViewText(R.id.tv_group, snap.group)
            } else {
                views.setViewVisibility(R.id.tv_group, View.GONE)
            }
            views.setTextViewText(
                R.id.tv_count_pill,
                WidgetDbHelper.formatClassesCount(snap.todayLessons.size, snap.isRu)
            )

            val rowIds = intArrayOf(R.id.row_1, R.id.row_2, R.id.row_3, R.id.row_4)
            val barIds = intArrayOf(R.id.row_1_bar, R.id.row_2_bar, R.id.row_3_bar, R.id.row_4_bar)
            val timeIds = intArrayOf(R.id.row_1_time, R.id.row_2_time, R.id.row_3_time, R.id.row_4_time)
            val endIds = intArrayOf(R.id.row_1_end_time, R.id.row_2_end_time, R.id.row_3_end_time, R.id.row_4_end_time)
            val subjIds = intArrayOf(R.id.row_1_subject, R.id.row_2_subject, R.id.row_3_subject, R.id.row_4_subject)
            val teachIds = intArrayOf(R.id.row_1_teacher, R.id.row_2_teacher, R.id.row_3_teacher, R.id.row_4_teacher)
            val roomIds = intArrayOf(R.id.row_1_room, R.id.row_2_room, R.id.row_3_room, R.id.row_4_room)

            if (snap.todayLessons.isEmpty()) {
                views.setViewVisibility(R.id.empty_container, View.VISIBLE)
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

            views.setViewVisibility(R.id.empty_container, View.GONE)
            val todayCode = dayCodes.getOrNull(snap.todayWeekdayIdx)
            val limit = maxRows.coerceIn(1, 4)
            for (i in 0 until 4) {
                if (i < snap.todayLessons.size && i < limit) {
                    val l = snap.todayLessons[i]
                    val isNextToday = snap.nextLesson != null &&
                        snap.nextDayCode == todayCode &&
                        l.start == snap.nextLesson.start &&
                        l.subject == snap.nextLesson.subject

                    views.setViewVisibility(rowIds[i], View.VISIBLE)
                    views.setImageViewResource(
                        barIds[i],
                        if (isNextToday) R.drawable.widget_bar_active else R.drawable.widget_bar_inactive
                    )
                    views.setTextViewText(timeIds[i], l.start)
                    views.setTextViewText(endIds[i], l.end)
                    views.setTextViewText(subjIds[i], l.subject)

                    if (l.teacher.isNotEmpty()) {
                        views.setViewVisibility(teachIds[i], View.VISIBLE)
                        views.setTextViewText(teachIds[i], l.teacher)
                    } else {
                        views.setViewVisibility(teachIds[i], View.GONE)
                    }

                    if (l.room.isNotEmpty()) {
                        views.setViewVisibility(roomIds[i], View.VISIBLE)
                        views.setTextViewText(roomIds[i], l.room)
                    } else {
                        views.setViewVisibility(roomIds[i], View.GONE)
                    }
                } else {
                    views.setViewVisibility(rowIds[i], View.GONE)
                }
            }
            return views
        }
    }
}
