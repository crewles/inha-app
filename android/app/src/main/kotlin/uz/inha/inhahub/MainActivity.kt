package uz.inha.inhahub

import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import androidx.core.content.FileProvider
import androidx.work.Constraints
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.NetworkType
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.concurrent.TimeUnit

class MainActivity : FlutterActivity() {
    private val bgChannelName = "uz.inha.inhahub/bg_sync"
    private val platformChannelName = "uz.inha.inhahub/app_platform"
    private val uniqueWorkName = "inha_eclass_bg_sync"

    private var pendingInitialTab: Int? = null
    private var platformChannel: MethodChannel? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        handleTabIntent(intent, notifyLive = false)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleTabIntent(intent, notifyLive = true)
    }

    private fun handleTabIntent(intent: Intent?, notifyLive: Boolean) {
        if (intent == null || !intent.hasExtra("open_tab")) return
        val tab = intent.getIntExtra("open_tab", -1)
        intent.removeExtra("open_tab")
        if (tab !in 0..4) return
        if (notifyLive && platformChannel != null) {
            platformChannel?.invokeMethod("openTab", tab)
        } else {
            pendingInitialTab = tab
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, bgChannelName)
            .setMethodCallHandler { call, result ->
                try {
                    when (call.method) {
                        "schedule" -> {
                            val minutes = (call.argument<Int>("intervalMinutes") ?: 120).coerceAtLeast(15)
                            val constraints = Constraints.Builder()
                                .setRequiredNetworkType(NetworkType.CONNECTED)
                                .build()
                            val request = PeriodicWorkRequestBuilder<EclassSyncWorker>(
                                minutes.toLong(),
                                TimeUnit.MINUTES
                            )
                                .setConstraints(constraints)
                                .build()
                            WorkManager.getInstance(applicationContext)
                                .enqueueUniquePeriodicWork(
                                    uniqueWorkName,
                                    ExistingPeriodicWorkPolicy.UPDATE,
                                    request
                                )
                            result.success(true)
                        }
                        "cancel" -> {
                            WorkManager.getInstance(applicationContext)
                                .cancelUniqueWork(uniqueWorkName)
                            result.success(true)
                        }
                        else -> result.notImplemented()
                    }
                } catch (t: Throwable) {
                    result.error("BG_SYNC_ERROR", t.message, null)
                }
            }

        platformChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, platformChannelName).apply {
            setMethodCallHandler { call, result ->
                try {
                    when (call.method) {
                        "getInitialTab" -> {
                            val tab = pendingInitialTab
                            pendingInitialTab = null
                            result.success(tab)
                        }
                        "updateWidgets" -> {
                            WidgetUpdater.updateAll(applicationContext)
                            result.success(true)
                        }
                        "requestPinWidget" -> {
                            val key = call.argument<String>("widget") ?: ""
                            result.success(requestPinWidget(key))
                        }
                        "installApk" -> {
                            val path = call.argument<String>("path") ?: ""
                            result.success(installApk(path))
                        }
                        else -> result.notImplemented()
                    }
                } catch (t: Throwable) {
                    result.error("PLATFORM_ERROR", t.message, null)
                }
            }
        }
    }

    private fun requestPinWidget(key: String): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return false
        val cls = when (key) {
            "next_lecture" -> NextLectureWidgetProvider::class.java
            "today_schedule" -> TodayScheduleWidgetProvider::class.java
            "ins_academic" -> InsAcademicWidgetProvider::class.java
            "deadlines" -> DeadlinesWidgetProvider::class.java
            else -> return false
        }
        val mgr = AppWidgetManager.getInstance(this)
        if (!mgr.isRequestPinAppWidgetSupported) return false
        return mgr.requestPinAppWidget(ComponentName(this, cls), null, null)
    }

    private fun installApk(path: String): Boolean {
        val file = File(path)
        if (!file.exists()) return false
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && !packageManager.canRequestPackageInstalls()) {
            val permIntent = Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES).apply {
                data = Uri.parse("package:$packageName")
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            startActivity(permIntent)
            return false
        }
        val uri = FileProvider.getUriForFile(this, "$packageName.update_provider", file)
        val installIntent = Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(uri, "application/vnd.android.package-archive")
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        startActivity(installIntent)
        return true
    }
}
