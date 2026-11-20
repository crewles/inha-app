package uz.inha.inhahub

import androidx.work.Constraints
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.NetworkType
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.TimeUnit

class MainActivity : FlutterActivity() {
    private val channelName = "uz.inha.inhahub/bg_sync"
    private val uniqueWorkName = "inha_eclass_bg_sync"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
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
    }
}
