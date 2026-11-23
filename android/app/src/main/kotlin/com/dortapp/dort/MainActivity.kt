package com.dortapp.dort

import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import com.google.android.play.core.appupdate.AppUpdateManager
import com.google.android.play.core.appupdate.AppUpdateManagerFactory
import com.google.android.play.core.install.model.AppUpdateType
import com.google.android.play.core.install.model.UpdateAvailability

class MainActivity : FlutterActivity() {
    private lateinit var appUpdateManager: AppUpdateManager
    private var updateChannel: MethodChannel? = null
    private var pendingUpdateResult: MethodChannel.Result? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        appUpdateManager = AppUpdateManagerFactory.create(this)
        createDefaultNotificationChannel()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        PlayOfferChannel.register(this, flutterEngine.dartExecutor.binaryMessenger)
        updateChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.dortapp.dort/app_update",
        ).also { channel ->
            channel.setMethodCallHandler { call, result ->
                when (call.method) {
                    "checkAvailability" -> checkUpdateAvailability(result)
                    "startUpdate" -> startUpdate(
                        call.argument<Boolean>("immediate") == true,
                        result,
                    )
                    else -> result.notImplemented()
                }
            }
        }
    }

    private fun checkUpdateAvailability(result: MethodChannel.Result) {
        appUpdateManager.appUpdateInfo
            .addOnSuccessListener { info ->
                result.success(
                    mapOf(
                        "available" to
                            (info.updateAvailability() == UpdateAvailability.UPDATE_AVAILABLE),
                        "immediateAllowed" to info.isUpdateTypeAllowed(AppUpdateType.IMMEDIATE),
                        "flexibleAllowed" to info.isUpdateTypeAllowed(AppUpdateType.FLEXIBLE),
                        "availableVersionCode" to info.availableVersionCode(),
                    ),
                )
            }
            .addOnFailureListener { error ->
                result.error("play_update_unavailable", error.javaClass.simpleName, null)
            }
    }

    @Suppress("DEPRECATION")
    private fun startUpdate(immediate: Boolean, result: MethodChannel.Result) {
        if (pendingUpdateResult != null) {
            result.error("update_in_progress", "An update flow is already active.", null)
            return
        }
        appUpdateManager.appUpdateInfo
            .addOnSuccessListener { info ->
                val type = if (immediate) AppUpdateType.IMMEDIATE else AppUpdateType.FLEXIBLE
                if (
                    info.updateAvailability() != UpdateAvailability.UPDATE_AVAILABLE ||
                    !info.isUpdateTypeAllowed(type)
                ) {
                    result.success(false)
                    return@addOnSuccessListener
                }
                pendingUpdateResult = result
                try {
                    val started = appUpdateManager.startUpdateFlowForResult(
                        info,
                        type,
                        this,
                        APP_UPDATE_REQUEST_CODE,
                    )
                    if (!started) {
                        pendingUpdateResult = null
                        result.success(false)
                    }
                } catch (error: Exception) {
                    pendingUpdateResult = null
                    result.error("play_update_start_failed", error.javaClass.simpleName, null)
                }
            }
            .addOnFailureListener { error ->
                result.error("play_update_unavailable", error.javaClass.simpleName, null)
            }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: android.content.Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == APP_UPDATE_REQUEST_CODE) {
            pendingUpdateResult?.success(resultCode == RESULT_OK)
            pendingUpdateResult = null
        }
    }

    // Must match default_notification_channel_id and the server FCM channelId.
    // Android keeps the user's later channel changes; this call does not reset them.
    private fun createDefaultNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            return
        }
        val channel = NotificationChannel(
            getString(R.string.dort_notification_channel_id),
            getString(R.string.dort_notification_channel_name),
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = getString(R.string.dort_notification_channel_description)
            enableVibration(true)
        }
        getSystemService(NotificationManager::class.java)
            ?.createNotificationChannel(channel)
    }

    companion object {
        private const val APP_UPDATE_REQUEST_CODE = 41031
    }
}
