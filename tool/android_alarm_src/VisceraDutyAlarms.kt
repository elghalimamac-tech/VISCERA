package com.viscera.viscera

import android.app.*
import android.content.*
import android.graphics.Color
import android.media.*
import android.net.Uri
import android.os.*
import android.provider.Settings
import android.view.*
import android.widget.*
import org.json.JSONObject

/** Alarmes locales personnelles. Aucun dossier patient et aucun accès réseau. */
object DutyAlarmNative {
  private const val STORE = "viscera_duty_native_v1"
  const val FIRE = "viscera.DUTY_FIRE"
  const val STOP = "viscera.DUTY_STOP"
  const val SNOOZE = "viscera.DUTY_SNOOZE"
  const val CHANNEL = "viscera_alarm_ringing_v1"
  const val FALLBACK = "viscera_alarm_fallback_v1"
  const val NOTIFICATION = 970901
  private fun prefs(c:Context) = c.getSharedPreferences(STORE,Context.MODE_PRIVATE)
  private fun alarmManager(c:Context) = c.getSystemService(Context.ALARM_SERVICE) as AlarmManager
  private fun pi(c:Context,id:Int,title:String) = PendingIntent.getBroadcast(c,id,
    Intent(c,DutyAlarmReceiver::class.java).setAction(FIRE)
      .putExtra("id",id).putExtra("title",title),
    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
  fun status(c:Context):Map<String,Any> {
    val nm = c.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
    val am = c.getSystemService(Context.AUDIO_SERVICE) as AudioManager
    return mapOf(
      "exact" to (Build.VERSION.SDK_INT<31 || alarmManager(c).canScheduleExactAlarms()),
      "fullScreen" to (Build.VERSION.SDK_INT<34 || nm.canUseFullScreenIntent()),
      "notifications" to (Build.VERSION.SDK_INT<24 || nm.areNotificationsEnabled()),
      "volume" to am.getStreamVolume(AudioManager.STREAM_ALARM),
      "maxVolume" to am.getStreamMaxVolume(AudioManager.STREAM_ALARM).coerceAtLeast(1))
  }
  fun openFullScreen(c:Context) {
    if (Build.VERSION.SDK_INT>=34) c.startActivity(
      Intent(Settings.ACTION_MANAGE_APP_USE_FULL_SCREEN_INTENT)
        .setData(Uri.parse("package:" + c.packageName))
        .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
  }
  fun openVolume(c:Context) {
    c.startActivity(Intent(Settings.ACTION_SOUND_SETTINGS)
      .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
  }
  private fun schedule(c:Context,id:Int,at:Long,title:String) {
    val am=alarmManager(c);val pending=pi(c,id,title)
    if (Build.VERSION.SDK_INT>=31 && !am.canScheduleExactAlarms())
      am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP,at,pending)
    else try {
      am.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP,at,pending)
    } catch (_:SecurityException) {
      am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP,at,pending)
    }
  }
  @Synchronized fun syncMonth(c:Context,month:String,rows:List<Map<*,*>>):Int {
    require(Regex("""\d{4}-\d{2}""").matches(month))
    val all=JSONObject(prefs(c).getString("entries","{}") ?: "{}")
    for (key in all.keys().asSequence().toList()) {
      val entry=all.optJSONObject(key)
      if (entry?.optString("month")==month) {
        val id=key.toIntOrNull()
        if(id!=null) alarmManager(c).cancel(pi(c,id,entry.optString("title")))
        all.remove(key)
      }
    }
    var count=0
    for(row in rows.take(100)) {
      val id=(row["id"] as? Number)?.toInt() ?: continue
      val at=(row["time"] as? Number)?.toLong() ?: continue
      val title=(row["title"] as? String)?.take(95) ?: "VISCERA · Garde"
      if(id<=0 || at<=System.currentTimeMillis()) continue
      all.put(id.toString(),JSONObject().put("month",month).put("at",at)
        .put("title",title))
      schedule(c,id,at,title);count++
    }
    prefs(c).edit().putString("entries",all.toString()).apply()
    return count
  }
  @Synchronized fun cancelAll(c:Context) {
    val all=JSONObject(prefs(c).getString("entries","{}") ?: "{}")
    for(key in all.keys()) {
      val id=key.toIntOrNull() ?: continue
      alarmManager(c).cancel(pi(c,id,all.optJSONObject(key)?.optString("title") ?: "Garde"))
    }
    prefs(c).edit().remove("entries").apply()
    c.stopService(Intent(c,DutyAlarmService::class.java))
  }
  @Synchronized fun fired(c:Context,id:Int):Boolean {
    val all=JSONObject(prefs(c).getString("entries","{}") ?: "{}")
    if(!all.has(id.toString())) return false
    all.remove(id.toString())
    prefs(c).edit().putString("entries",all.toString()).apply()
    return true
  }
  @Synchronized fun snooze(c:Context,id:Int,title:String) {
    val all=JSONObject(prefs(c).getString("entries","{}") ?: "{}")
    val at=System.currentTimeMillis()+600000L
    all.put(id.toString(),JSONObject().put("month","snooze").put("at",at)
      .put("title",title))
    prefs(c).edit().putString("entries",all.toString()).apply()
    schedule(c,id,at,title)
  }
  @Synchronized fun restore(c:Context) {
    val all=JSONObject(prefs(c).getString("entries","{}") ?: "{}")
    for(key in all.keys().asSequence().toList()) {
      val id=key.toIntOrNull() ?: continue
      val entry=all.optJSONObject(key) ?: continue
      if(entry.optLong("at")>System.currentTimeMillis())
        schedule(c,id,entry.getLong("at"),entry.optString("title"))
      else all.remove(key)
    }
    prefs(c).edit().putString("entries",all.toString()).apply()
  }
}

class DutyAlarmReceiver:BroadcastReceiver() {
  override fun onReceive(c:Context,intent:Intent) {
    if(intent.action==Intent.ACTION_BOOT_COMPLETED ||
      intent.action==Intent.ACTION_MY_PACKAGE_REPLACED ||
      intent.action=="android.app.action.SCHEDULE_EXACT_ALARM_PERMISSION_STATE_CHANGED") {
      DutyAlarmNative.restore(c);return
    }
    if(intent.action!=DutyAlarmNative.FIRE) return
    val id=intent.getIntExtra("id",-1)
    if(id<=0 || !DutyAlarmNative.fired(c,id)) return
    val title=intent.getStringExtra("title") ?: "VISCERA · Garde"
    try {
      val service=Intent(c,DutyAlarmService::class.java)
        .putExtra("id",id).putExtra("title",title)
      if(Build.VERSION.SDK_INT>=26) c.startForegroundService(service)
      else c.startService(service)
    } catch (_:Exception) { DutyAlarmService.fallback(c,id,title) }
  }
}

/** Actions sans relancement de service foreground : pas de crash après expiration. */
class DutyAlarmActionReceiver:BroadcastReceiver() {
  override fun onReceive(c:Context,intent:Intent) {
    val id=intent.getIntExtra("id",-1)
    val title=intent.getStringExtra("title") ?: "VISCERA · Garde"
    if(intent.action==DutyAlarmNative.SNOOZE && id>0 &&
       !title.contains("Essai alarme")) {
      DutyAlarmNative.snooze(c,id,title)
    }
    c.stopService(Intent(c,DutyAlarmService::class.java))
    val nm=c.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
    nm.cancel(DutyAlarmNative.NOTIFICATION)
    if(id>0)nm.cancel(id)
  }
}

/** La sonnerie tourne sur le volume ALARME Android, maximum 3 minutes.
    Le service fonctionne même lorsque l'écran Flutter n'est pas ouvert. */
class DutyAlarmService:Service() {
  private var player:MediaPlayer?=null
  private val handler=Handler(Looper.getMainLooper())
  private val timeout=Runnable { stopSelf() }
  private var id=-1
  private var title="VISCERA · Garde"
  override fun onBind(intent:Intent?):IBinder?=null
  override fun onStartCommand(intent:Intent?,flags:Int,startId:Int):Int {
    val action=intent?.action
    if(action==DutyAlarmNative.STOP || action==DutyAlarmNative.SNOOZE) {
      val alarmId=intent.getIntExtra("id",id)
      if(action==DutyAlarmNative.SNOOZE && alarmId>0)
        DutyAlarmNative.snooze(this,alarmId,intent.getStringExtra("title") ?: title)
      stopSelf();return START_NOT_STICKY
    }
    id=intent?.getIntExtra("id",-1) ?: -1
    title=intent?.getStringExtra("title") ?: title
    try {
      createChannel(this)
      startForeground(DutyAlarmNative.NOTIFICATION,notification(this,id,title,false))
      player?.release()
      player=MediaPlayer().apply {
        setAudioAttributes(AudioAttributes.Builder()
          .setUsage(AudioAttributes.USAGE_ALARM)
          .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION).build())
        setWakeMode(applicationContext,PowerManager.PARTIAL_WAKE_LOCK)
        setDataSource(applicationContext,Uri.parse(
          "android.resource://" + packageName + "/" + R.raw.viscera_duty_alarm))
        isLooping=true
        prepare()
        start()
      }
      handler.removeCallbacks(timeout)
      handler.postDelayed(timeout,180000L)
    } catch (_:Exception) {
      fallback(this,id,title);stopSelf()
    }
    return START_NOT_STICKY
  }
  override fun onDestroy() {
    handler.removeCallbacks(timeout)
    player?.let { runCatching { if(it.isPlaying)it.stop() };it.release() }
    player=null
    super.onDestroy()
  }
  companion object {
    private fun activityIntent(c:Context,id:Int,title:String)=
      PendingIntent.getActivity(c,id,Intent(c,DutyAlarmActivity::class.java)
        .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
        .putExtra("id",id).putExtra("title",title),
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
    private fun action(c:Context,id:Int,title:String,which:String,offset:Int):PendingIntent {
      val intent=Intent(c,DutyAlarmActionReceiver::class.java).setAction(which)
        .putExtra("id",id).putExtra("title",title)
      val flags=PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
      return PendingIntent.getBroadcast(c,id+offset,intent,flags)
    }
    private fun createChannel(c:Context) {
      val nm=c.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
      val channel=NotificationChannel(DutyAlarmNative.CHANNEL,"Alarmes de garde VISCERA",
        NotificationManager.IMPORTANCE_HIGH)
      channel.description="Sonnerie prolongée, volume Alarme du téléphone"
      channel.enableVibration(true)
      channel.setSound(null,null) // Le MediaPlayer joue la sonnerie en boucle.
      nm.createNotificationChannel(channel)
    }
    private fun notification(c:Context,id:Int,title:String,backup:Boolean):Notification {
      val channel=if(backup)DutyAlarmNative.FALLBACK else DutyAlarmNative.CHANNEL
      val full=activityIntent(c,id,title)
      return Notification.Builder(c,channel)
        .setSmallIcon(R.drawable.viscera_notification)
        .setContentTitle(title)
        .setContentText("Alarme de garde · toucher pour arrêter ou reporter")
        .setCategory(Notification.CATEGORY_ALARM)
        .setPriority(Notification.PRIORITY_MAX)
        .setVisibility(Notification.VISIBILITY_PUBLIC)
        .setOngoing(!backup).setAutoCancel(false)
        .setFullScreenIntent(full,true).setContentIntent(full)
        .addAction(Notification.Action.Builder(null,"Arrêter",
          action(c,id,title,DutyAlarmNative.STOP,500)).build())
        .addAction(Notification.Action.Builder(null,"Reporter 10 min",
          action(c,id,title,DutyAlarmNative.SNOOZE,600)).build())
        .build()
    }
    fun fallback(c:Context,id:Int,title:String) {
      val nm=c.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
      val channel=NotificationChannel(DutyAlarmNative.FALLBACK,
        "Alarme de garde de secours",NotificationManager.IMPORTANCE_HIGH)
      channel.setSound(RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM),
        AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_ALARM).build())
      channel.enableVibration(true);nm.createNotificationChannel(channel)
      runCatching { nm.notify(id,notification(c,id,title,true)) }
    }
  }
}

class DutyAlarmActivity:Activity() {
  private var id=-1
  private var title="VISCERA · Garde"
  override fun onCreate(state:Bundle?) {
    super.onCreate(state)
    id=intent.getIntExtra("id",-1)
    title=intent.getStringExtra("title") ?: title
    if(Build.VERSION.SDK_INT>=27) {
      setShowWhenLocked(true);setTurnScreenOn(true)
    } else {
      @Suppress("DEPRECATION")
      window.addFlags(WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
        WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON)
    }
    window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
    val ui=LinearLayout(this).apply {
      orientation=LinearLayout.VERTICAL;gravity=Gravity.CENTER
      setPadding(42,56,42,56);setBackgroundColor(Color.rgb(8,59,70))
    }
    fun label(value:String,size:Float,color:Int)=TextView(this).apply {
      text=value;textSize=size;setTextColor(color);gravity=Gravity.CENTER
      setPadding(5,14,5,14)
    }
    ui.addView(label("VISCERA",35f,Color.WHITE))
    ui.addView(label("ALARME DE GARDE",18f,Color.rgb(19,184,176)))
    ui.addView(label(title,23f,Color.WHITE))
    ui.addView(label("Sonnerie sur le volume Alarme Android",13f,Color.WHITE))
    val stop=Button(this).apply {
      text="ARRÊTER L’ALARME"
      setOnClickListener {
        sendBroadcast(Intent(this@DutyAlarmActivity,DutyAlarmActionReceiver::class.java)
          .setAction(DutyAlarmNative.STOP).putExtra("id",id))
        finish()
      }
    }
    val snooze=Button(this).apply {
      text="REPORTER DE 10 MIN"
      setOnClickListener {
        sendBroadcast(Intent(this@DutyAlarmActivity,DutyAlarmActionReceiver::class.java)
          .setAction(DutyAlarmNative.SNOOZE).putExtra("id",id)
          .putExtra("title",title))
        finish()
      }
    }
    ui.addView(stop,LinearLayout.LayoutParams(-1,-2))
    ui.addView(snooze,LinearLayout.LayoutParams(-1,-2))
    setContentView(ui)
  }
}
