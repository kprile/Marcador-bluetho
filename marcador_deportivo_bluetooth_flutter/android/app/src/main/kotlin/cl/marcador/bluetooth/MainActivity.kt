package cl.marcador.bluetooth

import android.os.Bundle
import android.content.Intent
import android.media.AudioAttributes
import java.util.concurrent.Executors
import android.speech.tts.TextToSpeech
import android.view.KeyEvent
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.util.Locale

class MainActivity : FlutterActivity(), TextToSpeech.OnInitListener {
    private var sink: EventChannel.EventSink? = null
    private var capture = -1
    private var deviceDescriptor: String? = null
    private val storageWorker = Executors.newSingleThreadExecutor()
    private var tts: TextToSpeech? = null
    private var ttsReady = false
    private var ttsInitialized = false
    private var voicesReply: MethodChannel.Result? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        tts = TextToSpeech(this, this)
    }
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, "cl.marcador/keys")
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) { sink = events }
                override fun onCancel(arguments: Any?) { sink = null }
            })
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "cl.marcador/native")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "read" -> result.success(getSharedPreferences("match", MODE_PRIVATE).getString("data", ""))
                    "write" -> {
                        val data = call.arguments as String
                        storageWorker.execute {
                            val ok = getSharedPreferences("match", MODE_PRIVATE).edit().putString("data", data).commit()
                            runOnUiThread {
                                if (ok) result.success(null) else result.error("STORAGE", "No se pudo guardar", null)
                            }
                        }
                    }
                    "awake" -> {
                        if (call.arguments == true) window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                        else window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                        result.success(null)
                    }
                    "capture" -> {
                        val args = call.arguments as Map<*, *>
                        val code = (args["code"] as Number).toInt()
                        capture = if (code in 1..999 && code !in listOf(3, 4, 26, 187)) code else -1
                        deviceDescriptor = args["descriptor"] as? String
                        result.success(null)
                    }
                    "stop" -> { tts?.stop(); result.success(null) }
                    "ttsSettings" -> {
                        try { startActivity(Intent("com.android.settings.TTS_SETTINGS")); result.success(null) }
                        catch (e: Exception) { result.error("SETTINGS", "Abre los ajustes de síntesis de voz de Android", null) }
                    }
                    "voices" -> if (ttsInitialized) result.success(offlineVoices()) else {
                        voicesReply?.success(emptyList<Map<String, String>>())
                        voicesReply = result
                    }
                    "speak" -> {
                        if (!ttsReady) { result.error("TTS", "Motor de voz no disponible", null); return@setMethodCallHandler }
                        val args = call.arguments as Map<*, *>
                        val offline = tts?.voices?.filter { !it.isNetworkConnectionRequired && it.locale.language == "es" && !it.features.contains("notInstalled") } ?: emptyList()
                        val voice = offline.firstOrNull { it.name == args["voice"] }
                            ?: offline.firstOrNull { it.locale.country == "CL" } ?: offline.firstOrNull()
                        if (voice == null) { result.error("VOICE", "Instala una voz española sin conexión en Android", null); return@setMethodCallHandler }
                        tts?.voice = voice
                        tts?.setSpeechRate((args["rate"] as? Number)?.toFloat() ?: 1f)
                        val status = tts?.speak(args["text"] as String, TextToSpeech.QUEUE_FLUSH, null, "score")
                        if (status == TextToSpeech.ERROR) result.error("TTS", "Falló el anuncio", null) else result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }
    private fun offlineVoices(): List<Map<String, String>> = tts?.voices
        ?.filter { !it.isNetworkConnectionRequired && it.locale.language == "es" && !it.features.contains("notInstalled") }
        ?.sortedBy { it.name }?.map { mapOf("name" to it.name, "locale" to it.locale.toLanguageTag()) } ?: emptyList()
    override fun onInit(status: Int) {
        ttsInitialized = true
        ttsReady = status == TextToSpeech.SUCCESS
        if (ttsReady) {
            tts?.language = Locale("es", "CL")
            tts?.setAudioAttributes(AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_MEDIA)
                .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH).build())
        }
        voicesReply?.success(offlineVoices()); voicesReply = null
    }
    override fun dispatchKeyEvent(event: KeyEvent): Boolean {
        // Observe all hardware keys; consume ONLY the configured key while armed.
        sink?.success(mapOf("code" to event.keyCode, "scan" to event.scanCode,
            "action" to event.action, "repeat" to event.repeatCount,
            "descriptor" to event.device?.descriptor, "device" to (event.device?.name ?: "desconocido")))
        if (capture > 0 && event.keyCode == capture &&
            (deviceDescriptor == null || deviceDescriptor == event.device?.descriptor)) return true
        return super.dispatchKeyEvent(event)
    }
    override fun onPause() { capture = -1; tts?.stop(); super.onPause() }
    override fun onDestroy() {
        voicesReply?.success(emptyList<Map<String, String>>()); voicesReply = null
        storageWorker.shutdown(); tts?.stop(); tts?.shutdown(); super.onDestroy()
    }
}
