package uz.inha.inhahub

import android.content.Context

object WidgetUpdater {
    fun updateAll(context: Context) {
        try {
            NextLectureWidgetProvider.updateAll(context)
        } catch (_: Throwable) {
        }
        try {
            TodayScheduleWidgetProvider.updateAll(context)
        } catch (_: Throwable) {
        }
        try {
            InsAcademicWidgetProvider.updateAll(context)
        } catch (_: Throwable) {
        }
        try {
            DeadlinesWidgetProvider.updateAll(context)
        } catch (_: Throwable) {
        }
    }
}
