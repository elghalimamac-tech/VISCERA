package com.viscera.viscera

import android.content.Intent
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity:FlutterActivity() {
  override fun configureFlutterEngine(engine:FlutterEngine) {
    super.configureFlutterEngine(engine)
    MethodChannel(engine.dartExecutor.binaryMessenger,"viscera/duty_alarm").setMethodCallHandler {
      call,result ->
      try {
        when(call.method) {
          "status" -> result.success(DutyAlarmNative.status(this))
          "syncMonth" -> {
            val month=call.argument<String>("month") ?: ""
            val rows=call.argument<List<Map<String,Any>>>("alarms") ?: emptyList()
            result.success(DutyAlarmNative.syncMonth(this,month,rows))
          }
          "cancelAll" -> {
            DutyAlarmNative.cancelAll(this);result.success(null)
          }
          "fullScreenSettings" -> {
            DutyAlarmNative.openFullScreen(this);result.success(null)
          }
          "volumeSettings" -> {
            DutyAlarmNative.openVolume(this);result.success(null)
          }
          "test" -> {
            val id=970902
            val title="VISCERA · Essai alarme"
            val service=Intent(this,DutyAlarmService::class.java)
              .putExtra("id",id).putExtra("title",title)
            if(Build.VERSION.SDK_INT>=26)startForegroundService(service)
            else startService(service)
            startActivity(Intent(this,DutyAlarmActivity::class.java)
              .putExtra("id",id).putExtra("title",title))
            result.success(null)
          }
          else -> result.notImplemented()
        }
      } catch(e:Exception) {
        result.error("DUTY_ALARM_ERROR",e.message ?: "Erreur alarme Android",null)
      }
    }
  }
}
