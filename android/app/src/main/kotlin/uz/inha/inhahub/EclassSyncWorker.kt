package uz.inha.inhahub

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.database.sqlite.SQLiteDatabase
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.work.Worker
import androidx.work.WorkerParameters
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL
import java.net.URLEncoder

class EclassSyncWorker(
    appContext: Context,
    workerParams: WorkerParameters
) : Worker(appContext, workerParams) {

    override fun doWork(): Result {
        val dbFile = applicationContext.getDatabasePath("inha_app.db")
        if (!dbFile.exists()) return Result.success()

        var token: String? = null
        val knownAssignmentIds = HashSet<String>()
        val hiddenAssignmentIds = HashSet<String>()
        val currentCourseIds = ArrayList<String>()

        try {
            val db = SQLiteDatabase.openDatabase(
                dbFile.absolutePath,
                null,
                SQLiteDatabase.OPEN_READONLY
            )
            db.use { sqlite ->
                sqlite.rawQuery("SELECT eclass_token FROM credentials WHERE id = 1", null).use { c ->
                    if (c.moveToFirst()) {
                        token = c.getString(0)
                    }
                }
                sqlite.rawQuery("SELECT id FROM assignments", null).use { c ->
                    while (c.moveToNext()) {
                        knownAssignmentIds.add(c.getString(0))
                    }
                }
                try {
                    sqlite.rawQuery("SELECT assignment_id FROM hidden_assignments", null).use { c ->
                        while (c.moveToNext()) {
                            c.getString(0)?.let { hiddenAssignmentIds.add(it) }
                        }
                    }
                } catch (_: Exception) {
                }
                sqlite.rawQuery("SELECT id FROM courses WHERE is_current = 1", null).use { c ->
                    while (c.moveToNext()) {
                        currentCourseIds.add(c.getString(0))
                    }
                }
            }
        } catch (_: Exception) {
            return Result.success()
        }

        val apiToken = token
        if (apiToken.isNullOrEmpty() || knownAssignmentIds.isEmpty()) {
            return Result.success()
        }

        try {
            val params = StringBuilder()
            params.append("wstoken=").append(URLEncoder.encode(apiToken, "UTF-8"))
            params.append("&wsfunction=mod_assign_get_assignments")
            params.append("&moodlewsrestformat=json")
            for ((idx, cid) in currentCourseIds.withIndex()) {
                params.append("&courseids[").append(idx).append("]=")
                    .append(URLEncoder.encode(cid, "UTF-8"))
            }

            val prefs = applicationContext.getSharedPreferences(
                "inha_bg_sync_prefs",
                Context.MODE_PRIVATE
            )
            val alreadyNotified = prefs
                .getStringSet("notified_assignment_ids", emptySet())
                ?.toHashSet() ?: HashSet()
            val pruned = alreadyNotified.removeAll { knownAssignmentIds.contains(it) }

            val conn = (URL("https://eclass.inha.ac.kr/webservice/rest/server.php")
                .openConnection() as HttpURLConnection).apply {
                requestMethod = "POST"
                doOutput = true
                connectTimeout = 15000
                readTimeout = 20000
                setRequestProperty(
                    "User-Agent",
                    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36"
                )
                setRequestProperty("Content-Type", "application/x-www-form-urlencoded")
            }

            try {
                conn.outputStream.use { it.write(params.toString().toByteArray(Charsets.UTF_8)) }
                if (conn.responseCode != 200) return Result.retry()

                val body = conn.inputStream.bufferedReader(Charsets.UTF_8).use { it.readText() }
                val root = JSONObject(body)
                if (root.has("exception")) return Result.success()

                val coursesArr = root.optJSONArray("courses") ?: return Result.success()
                val newItems = ArrayList<Pair<String, String>>()
                val newlyNotifiedKeys = ArrayList<String>()

                for (i in 0 until coursesArr.length()) {
                    val courseObj = coursesArr.getJSONObject(i)
                    val cid = courseObj.optString("id")
                    val cname = courseObj.optString("fullname", courseObj.optString("shortname"))
                        .replace(Regex("\\[.*?\\]"), "")
                        .trim()
                    val assigns = courseObj.optJSONArray("assignments") ?: continue
                    for (j in 0 until assigns.length()) {
                        val a = assigns.getJSONObject(j)
                        val aid = a.optInt("id", 0)
                        val aname = a.optString("name", "").trim()
                        val key = "$cid::$aid"
                        if (aid > 0 &&
                            !knownAssignmentIds.contains(key) &&
                            !hiddenAssignmentIds.contains(key) &&
                            !alreadyNotified.contains(key)
                        ) {
                            newItems.add(Pair(cname, aname))
                            newlyNotifiedKeys.add(key)
                        }
                    }
                }

                if (newItems.isNotEmpty()) {
                    showNotification(newItems)
                    alreadyNotified.addAll(newlyNotifiedKeys)
                }
                if (pruned || newlyNotifiedKeys.isNotEmpty()) {
                    prefs.edit().putStringSet("notified_assignment_ids", alreadyNotified).apply()
                }
                WidgetUpdater.updateAll(applicationContext)
            } finally {
                conn.disconnect()
            }
        } catch (_: Exception) {
            return Result.retry()
        }

        return Result.success()
    }

    private fun showNotification(items: List<Pair<String, String>>) {
        val manager = applicationContext.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val channelId = "inha_updates"
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                channelId,
                "Inha App Updates",
                NotificationManager.IMPORTANCE_HIGH
            )
            manager.createNotificationChannel(channel)
        }

        val title = if (items.size == 1) items[0].first else "New eClass Assignments (${items.size})"
        val text = if (items.size == 1) items[0].second else items.take(3).joinToString(", ") { it.second }

        val notification = NotificationCompat.Builder(applicationContext, channelId)
            .setSmallIcon(R.drawable.ic_stat_inha)
            .setContentTitle(title)
            .setContentText(text)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setContentIntent(WidgetDbHelper.createOpenTabIntent(applicationContext, 1, 3001))
            .setAutoCancel(true)
            .build()

        manager.notify(3001, notification)
    }
}
