package uz.inha.inhahub

import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.database.sqlite.SQLiteDatabase
import org.json.JSONArray
import org.json.JSONObject
import java.util.Calendar
import java.util.Locale
import java.util.TimeZone

data class WidgetLesson(
    val days: List<String>,
    val start: String,
    val end: String,
    val subject: String,
    val teacher: String,
    val room: String,
    val classes: List<String>
)

data class WidgetDeadline(
    val name: String,
    val courseName: String,
    val due: String,
    val dueTs: Long
)

data class WidgetSnapshot(
    val isRu: Boolean,
    val group: String,
    val nextLesson: WidgetLesson?,
    val nextDayCode: String?,
    val minsUntilNext: Int?,
    val todayLessons: List<WidgetLesson>,
    val todayWeekdayIdx: Int,
    val gpa: String,
    val creditsAcquired: String,
    val creditsAttempted: String,
    val activeCourseCount: Int,
    val pendingDeadlines: List<WidgetDeadline>
)

object WidgetDbHelper {
    private val tashkentTz = TimeZone.getTimeZone("Asia/Tashkent")
    private val dayNames = listOf("Mon", "Tue", "Wed", "Thu", "Fri")
    private val roomSuffixRegex = Regex("\\s*\\(\\d+\\)\\s*$")

    fun createOpenTabIntent(context: Context, tabIndex: Int, requestCode: Int): PendingIntent {
        val intent = Intent(context, MainActivity::class.java).apply {
            putExtra("open_tab", tabIndex)
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                Intent.FLAG_ACTIVITY_CLEAR_TOP or
                Intent.FLAG_ACTIVITY_SINGLE_TOP
        }
        return PendingIntent.getActivity(
            context,
            requestCode,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }

    fun loadSnapshot(context: Context): WidgetSnapshot {
        val dbFile = context.getDatabasePath("inha_app.db")
        val nowCal = Calendar.getInstance(tashkentTz)
        val todayIdx = when (nowCal.get(Calendar.DAY_OF_WEEK)) {
            Calendar.MONDAY -> 0
            Calendar.TUESDAY -> 1
            Calendar.WEDNESDAY -> 2
            Calendar.THURSDAY -> 3
            Calendar.FRIDAY -> 4
            else -> 0
        }

        if (!dbFile.exists()) {
            return WidgetSnapshot(
                isRu = true,
                group = "",
                nextLesson = null,
                nextDayCode = null,
                minsUntilNext = null,
                todayLessons = emptyList(),
                todayWeekdayIdx = todayIdx,
                gpa = "",
                creditsAcquired = "",
                creditsAttempted = "",
                activeCourseCount = 0,
                pendingDeadlines = emptyList()
            )
        }

        var isRu = true
        var group = ""
        val allLessons = ArrayList<WidgetLesson>()
        val hiddenIds = HashSet<String>()
        val deadlines = ArrayList<WidgetDeadline>()
        var gpa = ""
        var creditsAcq = ""
        var creditsAtt = ""
        var activeCourses = 0

        try {
            val db = SQLiteDatabase.openDatabase(
                dbFile.absolutePath,
                null,
                SQLiteDatabase.OPEN_READONLY
            )
            db.use { sqlite ->
                sqlite.rawQuery("SELECT key, value FROM settings", null).use { c ->
                    while (c.moveToNext()) {
                        val k = c.getString(0) ?: continue
                        val v = c.getString(1) ?: ""
                        when (k) {
                            "language" -> isRu = (v == "ru")
                            "timetable_group" -> group = v.trim()
                        }
                    }
                }

                try {
                    sqlite.rawQuery("SELECT assignment_id FROM hidden_assignments", null).use { c ->
                        while (c.moveToNext()) {
                            c.getString(0)?.let { hiddenIds.add(it) }
                        }
                    }
                } catch (_: Exception) {
                }

                try {
                    sqlite.rawQuery(
                        "SELECT days_json, period_start, period_end, subject, teachers_json, classes_json, classrooms_json FROM timetable_entries",
                        null
                    ).use { c ->
                        while (c.moveToNext()) {
                            val days = parseStringList(c.getString(0))
                            val start = c.getString(1) ?: ""
                            val end = c.getString(2) ?: ""
                            val subject = c.getString(3) ?: ""
                            val teachers = parseStringList(c.getString(4))
                            val classes = parseStringList(c.getString(5))
                            val rooms = parseStringList(c.getString(6))
                                .map { it.replace(roomSuffixRegex, "").trim() }
                                .filter { it.isNotEmpty() }
                            allLessons.add(
                                WidgetLesson(
                                    days = days,
                                    start = start,
                                    end = end,
                                    subject = subject,
                                    teacher = teachers.firstOrNull() ?: "",
                                    room = rooms.joinToString(", "),
                                    classes = classes
                                )
                            )
                        }
                    }
                } catch (_: Exception) {
                }

                try {
                    val nowSecQuery = System.currentTimeMillis() / 1000L
                    sqlite.rawQuery(
                        "SELECT id, name, course_name, due, due_timestamp, status, grade FROM assignments",
                        null
                    ).use { c ->
                        while (c.moveToNext()) {
                            val id = c.getString(0) ?: continue
                            if (hiddenIds.contains(id)) continue
                            val status = (c.getString(5) ?: "").lowercase()
                            val grade = (c.getString(6) ?: "").trim()
                            val submitted = grade.isNotEmpty() ||
                                status.contains("submitted") ||
                                status.contains("сдано") ||
                                status.contains("отправлено") ||
                                status.contains("graded")
                            if (submitted) continue
                            deadlines.add(
                                WidgetDeadline(
                                    name = c.getString(1) ?: "",
                                    courseName = c.getString(2) ?: "",
                                    due = c.getString(3) ?: "",
                                    dueTs = c.getLong(4)
                                )
                            )
                        }
                    }
                    deadlines.sortWith { a, b ->
                        val aUp = a.dueTs >= nowSecQuery
                        val bUp = b.dueTs >= nowSecQuery
                        val aGroup = when {
                            aUp -> 0
                            a.dueTs > 0 -> 1
                            else -> 2
                        }
                        val bGroup = when {
                            bUp -> 0
                            b.dueTs > 0 -> 1
                            else -> 2
                        }
                        if (aGroup != bGroup) {
                            aGroup.compareTo(bGroup)
                        } else when (aGroup) {
                            0 -> a.dueTs.compareTo(b.dueTs)
                            1 -> b.dueTs.compareTo(a.dueTs)
                            else -> a.name.compareTo(b.name)
                        }
                    }
                } catch (_: Exception) {
                }

                try {
                    sqlite.rawQuery("SELECT value FROM ins_meta WHERE key = 'gpa_info' LIMIT 1", null).use { c ->
                        if (c.moveToFirst()) {
                            val rawJson = c.getString(0) ?: "{}"
                            val obj = JSONObject(rawJson)
                            gpa = formatGpa(obj.optString("gpa", ""))
                            creditsAcq = formatCredits(obj.optString("credits_acquired", ""))
                            creditsAtt = formatCredits(obj.optString("credits_attempted", ""))
                        }
                    }
                } catch (_: Exception) {
                }

                try {
                    sqlite.rawQuery("SELECT COUNT(*) FROM courses WHERE is_current = 1", null).use { c ->
                        if (c.moveToFirst()) {
                            activeCourses = c.getInt(0)
                        }
                    }
                } catch (_: Exception) {
                }
            }
        } catch (_: Exception) {
        }

        val groupLower = group.lowercase()
        val groupLessons = if (groupLower.isEmpty()) {
            emptyList()
        } else {
            allLessons.filter { l -> l.classes.any { it.trim().lowercase() == groupLower } }
        }

        val wd = nowCal.get(Calendar.DAY_OF_WEEK)
        val isWeekday = wd in Calendar.MONDAY..Calendar.FRIDAY
        val todayCode = dayNames[todayIdx]
        val todayLessons = if (isWeekday) {
            groupLessons.filter { it.days.contains(todayCode) }.sortedBy { it.start }
        } else {
            emptyList()
        }

        val (nextLesson, nextDayCode, minsUntil) = findNextLesson(groupLessons, nowCal)

        return WidgetSnapshot(
            isRu = isRu,
            group = group,
            nextLesson = nextLesson,
            nextDayCode = nextDayCode,
            minsUntilNext = minsUntil,
            todayLessons = todayLessons,
            todayWeekdayIdx = todayIdx,
            gpa = gpa,
            creditsAcquired = creditsAcq,
            creditsAttempted = creditsAtt,
            activeCourseCount = activeCourses,
            pendingDeadlines = deadlines
        )
    }

    private fun findNextLesson(
        groupLessons: List<WidgetLesson>,
        nowCal: Calendar
    ): Triple<WidgetLesson?, String?, Int?> {
        if (groupLessons.isEmpty()) return Triple(null, null, null)

        val nowMinutes = nowCal.get(Calendar.HOUR_OF_DAY) * 60 + nowCal.get(Calendar.MINUTE)
        val wd = nowCal.get(Calendar.DAY_OF_WEEK)
        if (wd in Calendar.MONDAY..Calendar.FRIDAY) {
            val todayCode = dayNames[wd - Calendar.MONDAY]
            val todayList = groupLessons.filter { it.days.contains(todayCode) }.sortedBy { it.start }
            for (l in todayList) {
                val startMins = parseMinutes(l.start) ?: continue
                if (startMins > nowMinutes) {
                    return Triple(l, todayCode, startMins - nowMinutes)
                }
            }
        }

        val probe = nowCal.clone() as Calendar
        for (delta in 1..7) {
            probe.add(Calendar.DAY_OF_YEAR, 1)
            val d = probe.get(Calendar.DAY_OF_WEEK)
            if (d in Calendar.MONDAY..Calendar.FRIDAY) {
                val code = dayNames[d - Calendar.MONDAY]
                val dayList = groupLessons.filter { it.days.contains(code) }.sortedBy { it.start }
                if (dayList.isNotEmpty()) {
                    return Triple(dayList.first(), code, null)
                }
            }
        }
        return Triple(null, null, null)
    }

    private fun parseMinutes(hhmm: String): Int? {
        val parts = hhmm.split(":")
        if (parts.size != 2) return null
        val h = parts[0].toIntOrNull() ?: return null
        val m = parts[1].toIntOrNull() ?: return null
        return h * 60 + m
    }

    private fun parseStringList(raw: String?): List<String> {
        if (raw.isNullOrEmpty()) return emptyList()
        return try {
            val arr = JSONArray(raw)
            val out = ArrayList<String>(arr.length())
            for (i in 0 until arr.length()) {
                out.add(arr.optString(i, ""))
            }
            out
        } catch (_: Exception) {
            emptyList()
        }
    }

    private fun formatGpa(raw: String): String {
        val clean = raw.trim()
        if (clean.isEmpty()) return ""
        val num = clean.replace(',', '.').toDoubleOrNull() ?: return clean
        return String.format(Locale.US, "%.2f", num)
    }

    private fun formatCredits(raw: String): String {
        val clean = raw.trim()
        if (clean.isEmpty()) return ""
        val num = clean.replace(',', '.').toDoubleOrNull() ?: return clean
        return if (num == num.toLong().toDouble()) {
            num.toLong().toString()
        } else {
            String.format(Locale.US, "%.1f", num)
        }
    }
}
