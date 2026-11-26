package com.bharatsaathi.bharat_saathi

import android.app.Notification
import android.media.AudioAttributes
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import android.speech.tts.TextToSpeech
import android.util.Log
import org.json.JSONArray
import org.json.JSONObject
import java.util.Locale

class SoundBoxNotificationListener : NotificationListenerService() {
    companion object {
        private const val TAG = "BharatSaathiSoundBox"
        private const val PREFS = "bharat_saathi_soundbox"
        private const val MAX_HISTORY = 300

        private val supportedApps = mapOf(
            "com.phonepe.app" to "PhonePe",
            "com.google.android.apps.nbu.paisa.user" to "Google Pay",
            "net.one97.paytm" to "Paytm",
            "in.org.npci.upiapp" to "BHIM",
            "com.mobikwik_new" to "MobiKwik",
            "com.amazon.mShop.android.shopping" to "Amazon Pay",
            "in.amazon.mShop.android.shopping" to "Amazon Pay",
            "com.dreamplug.androidapp" to "CRED",
            "com.freecharge.android" to "Freecharge"
        )

        private val incomingPattern = Regex(
            "(?i)(received|credited|paid\\\\s+you|sent\\\\s+you|payment\\\\s+from|money\\\\s+received|you\\\\s+got|deposited|जमा|प्राप्त|मिला|मिली|आए|आया)"
        )
        private val outgoingPattern = Regex(
            "(?i)(you\\\\s+(?:sent|paid)|paid\\\\s+to|debited|withdrawn|payment\\\\s+failed|failed|declined|pending|collect\\\\s+request|request\\\\s+to\\\\s+pay|autopay|mandate)"
        )
        private val amountPatterns = listOf(
            Regex("(?i)(?:₹|rs\\\\.?\\\\s*|inr\\\\s*)([0-9][0-9,]*(?:\\\\.[0-9]{1,2})?)"),
            Regex("(?i)([0-9][0-9,]*(?:\\\\.[0-9]{1,2})?)\\\\s*(?:rupees|rs\\\\.?|inr)")
        )
        private val referencePattern = Regex(
            "(?i)(?:upi\\\\s*(?:ref(?:erence)?|txn(?:\\\\s*id)?)|utr|transaction\\\\s*id)\\\\s*[:#-]?\\\\s*([A-Z0-9]{8,})"
        )
    }

    private var tts: TextToSpeech? = null
    @Volatile private var ttsReady = false
    private val pendingSpeech = mutableListOf<String>()

    private fun prefs() = getSharedPreferences(PREFS, MODE_PRIVATE)

    override fun onCreate() {
        super.onCreate()
        tts = TextToSpeech(applicationContext) { status ->
            if (status == TextToSpeech.SUCCESS) {
                val language = prefs().getString("language", "hi") ?: "hi"
                val locale = if (language == "en") Locale.US else Locale("hi", "IN")
                tts?.setLanguage(locale)
                tts?.setSpeechRate(prefs().getFloat("speech_rate", 1.0f))
                tts?.setAudioAttributes(
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_ASSISTANCE_ACCESSIBILITY)
                        .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
                        .build()
                )
                ttsReady = true
                synchronized(pendingSpeech) {
                    pendingSpeech.forEach { speakNow(it) }
                    pendingSpeech.clear()
                }
            } else {
                Log.w(TAG, "TextToSpeech initialization failed: " + status)
            }
        }
    }

    override fun onNotificationPosted(sbn: StatusBarNotification) {
        if (!prefs().getBoolean("enabled", true)) return
        val source = supportedApps[sbn.packageName] ?: return
        val extras = sbn.notification.extras ?: return
        val parts = mutableListOf<String>()
        listOf(
            Notification.EXTRA_TITLE,
            Notification.EXTRA_TEXT,
            Notification.EXTRA_BIG_TEXT,
            Notification.EXTRA_SUB_TEXT,
            Notification.EXTRA_SUMMARY_TEXT
        ).forEach { key ->
            extras.getCharSequence(key)?.toString()?.trim()?.takeIf { it.isNotEmpty() }?.let(parts::add)
        }
        extras.getCharSequenceArray(Notification.EXTRA_TEXT_LINES)?.forEach { line ->
            line?.toString()?.trim()?.takeIf { it.isNotEmpty() }?.let(parts::add)
        }
        val message = parts.distinct().joinToString(" • ").take(1200)
        if (message.isBlank()) return
        val parsed = parseIncomingPayment(message) ?: return
        val notificationKey = sbn.packageName + "|" + sbn.key + "|" + sbn.postTime + "|" + parsed.first
        val reference = referencePattern.find(message)?.groupValues?.getOrNull(1)
        val dedupeKey = reference ?: notificationKey
        if (!savePayment(dedupeKey, source, sbn.packageName, parsed.first, message, reference, sbn.postTime)) return

        val amountText = formatAmount(parsed.first)
        val language = prefs().getString("language", "hi") ?: "hi"
        val speech = if (language == "en") {
            "Payment received: " + amountText + " rupees"
        } else {
            "आपको " + amountText + " रुपये प्राप्त हुए हैं"
        }
        queueSpeech(speech)
    }

    private fun parseIncomingPayment(message: String): Pair<Double, String>? {
        if (outgoingPattern.containsMatchIn(message)) return null
        if (!incomingPattern.containsMatchIn(message)) return null
        for (pattern in amountPatterns) {
            val match = pattern.find(message) ?: continue
            val raw = match.groupValues.getOrNull(1)?.replace(",", "") ?: continue
            val amount = raw.toDoubleOrNull() ?: continue
            if (amount > 0.0 && amount.isFinite()) return Pair(amount, raw)
        }
        return null
    }

    private fun savePayment(
        dedupeKey: String,
        source: String,
        packageName: String,
        amount: Double,
        message: String,
        reference: String?,
        timestamp: Long
    ): Boolean {
        return try {
            val preferences = prefs()
            val old = JSONArray(preferences.getString("history", "[]") ?: "[]")
            for (index in 0 until old.length()) {
                if (old.optJSONObject(index)?.optString("dedupeKey") == dedupeKey) return false
            }
            val record = JSONObject()
                .put("amount", amount)
                .put("source", source)
                .put("sourcePackage", packageName)
                .put("message", message.take(280))
                .put("timestamp", timestamp)
                .put("reference", reference ?: JSONObject.NULL)
                .put("dedupeKey", dedupeKey)
                .put("verified", false)
            val updated = JSONArray().put(record)
            for (index in 0 until minOf(old.length(), MAX_HISTORY - 1)) {
                updated.put(old.getJSONObject(index))
            }
            preferences.edit().putString("history", updated.toString()).apply()
            true
        } catch (error: Exception) {
            Log.e(TAG, "Could not save payment notification", error)
            false
        }
    }

    private fun queueSpeech(message: String) {
        synchronized(pendingSpeech) {
            if (ttsReady) {
                speakNow(message)
            } else {
                pendingSpeech.add(message)
            }
        }
    }

    private fun speakNow(message: String) {
        val engine = tts ?: return
        val language = prefs().getString("language", "hi") ?: "hi"
        engine.setLanguage(if (language == "en") Locale.US else Locale("hi", "IN"))
        engine.setSpeechRate(prefs().getFloat("speech_rate", 1.0f))
        engine.speak(message, TextToSpeech.QUEUE_ADD, null, "payment-" + System.currentTimeMillis())
    }

    private fun formatAmount(amount: Double): String {
        return if (amount % 1.0 == 0.0) amount.toLong().toString() else String.format(Locale.US, "%.2f", amount)
    }

    override fun onDestroy() {
        ttsReady = false
        tts?.stop()
        tts?.shutdown()
        tts = null
        super.onDestroy()
    }
}
