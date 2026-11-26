package com.bharatsaathi.bharat_saathi

import android.content.ComponentName
import android.content.Intent
import android.provider.Settings
import android.speech.tts.TextToSpeech
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.Locale

class MainActivity : FlutterActivity() {
    private val channelName = "bharat_saathi/soundbox"
    private val prefsName = "bharat_saathi_soundbox"
    private var testTts: TextToSpeech? = null

    private fun soundPrefs() = getSharedPreferences(prefsName, MODE_PRIVATE)

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName).setMethodCallHandler { call, result ->
            when (call.method) {
                "hasNotificationAccess" -> result.success(hasNotificationAccess())
                "openNotificationSettings" -> {
                    try {
                        startActivity(Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS))
                        result.success(true)
                    } catch (error: Exception) {
                        result.error("SETTINGS_ERROR", error.message, null)
                    }
                }
                "getEnabled" -> result.success(soundPrefs().getBoolean("enabled", true))
                "setEnabled" -> {
                    val enabled = call.argument<Boolean>("enabled") ?: true
                    soundPrefs().edit().putBoolean("enabled", enabled).apply()
                    result.success(true)
                }
                "getHistory" -> result.success(soundPrefs().getString("history", "[]") ?: "[]")
                "clearHistory" -> {
                    soundPrefs().edit().putString("history", "[]").apply()
                    result.success(true)
                }
                "getLanguage" -> result.success(soundPrefs().getString("language", "hi") ?: "hi")
                "setLanguage" -> {
                    val language = call.argument<String>("language") ?: "hi"
                    soundPrefs().edit().putString("language", if (language == "en") "en" else "hi").apply()
                    result.success(true)
                }
                "getSpeechRate" -> result.success(soundPrefs().getFloat("speech_rate", 1.0f).toDouble())
                "setSpeechRate" -> {
                    val rate = (call.argument<Double>("rate") ?: 1.0).toFloat().coerceIn(0.7f, 1.3f)
                    soundPrefs().edit().putFloat("speech_rate", rate).apply()
                    result.success(true)
                }
                "testSpeech" -> speakTest(result)
                else -> result.notImplemented()
            }
        }
    }

    private fun hasNotificationAccess(): Boolean {
        val enabledListeners = Settings.Secure.getString(
            contentResolver,
            "enabled_notification_listeners"
        ) ?: return false
        val expected = ComponentName(this, SoundBoxNotificationListener::class.java)
        return enabledListeners.split(':')
            .asSequence()
            .mapNotNull { ComponentName.unflattenFromString(it.trim()) }
            .any { it == expected }
    }

    private fun speakTest(result: MethodChannel.Result) {
        testTts?.shutdown()
        testTts = TextToSpeech(this) { status ->
            val engine = testTts
            if (status != TextToSpeech.SUCCESS || engine == null) {
                result.error("TTS_INIT_FAILED", "Text to speech could not start", null)
                return@TextToSpeech
            }
            val language = soundPrefs().getString("language", "hi") ?: "hi"
            val locale = if (language == "en") Locale.US else Locale("hi", "IN")
            val languageStatus = engine.setLanguage(locale)
            if (languageStatus == TextToSpeech.LANG_MISSING_DATA || languageStatus == TextToSpeech.LANG_NOT_SUPPORTED) {
                result.error("TTS_LANGUAGE_UNAVAILABLE", "Selected speech language is unavailable on this device", null)
                return@TextToSpeech
            }
            engine.setSpeechRate(soundPrefs().getFloat("speech_rate", 1.0f))
            engine.setAudioAttributes(
                android.media.AudioAttributes.Builder()
                    .setUsage(android.media.AudioAttributes.USAGE_MEDIA)
                    .setContentType(android.media.AudioAttributes.CONTENT_TYPE_SPEECH)
                    .build()
            )
            val message = if (language == "en") "Bharat Saathi Sound Box is ready" else "भारत साथी साउंड बॉक्स की आवाज़ जांच"
            val speakStatus = engine.speak(message, TextToSpeech.QUEUE_FLUSH, null, "soundbox-test")
            if (speakStatus == TextToSpeech.ERROR) {
                result.error("TTS_SPEAK_FAILED", "Text to speech engine rejected the test message", null)
            } else {
                result.success(true)
            }
        }
    }

    override fun onDestroy() {
        testTts?.stop()
        testTts?.shutdown()
        testTts = null
        super.onDestroy()
    }
}
