package com.goofynugtz.wllt

import android.app.ActivityManager
import android.content.Context
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.xmlpull.v1.XmlPullParser
import org.xmlpull.v1.XmlPullParserFactory
import java.io.File

class MainActivity : FlutterActivity() {

    companion object {
        private const val CHANNEL = "com.goofynugtz.wllt/system_font"
        private const val DEVICE_INFO_CHANNEL = "com.goofynugtz.wllt/device_info"
        private const val SYSTEM_FONTS_DIR = "/system/fonts"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getSystemFontBytes" -> result.success(getSystemFontBytes())
                    else -> result.notImplemented()
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, DEVICE_INFO_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getTotalRamBytes" -> result.success(getTotalRamBytes())
                    else -> result.notImplemented()
                }
            }
    }

    /** Total physical device RAM in bytes, used to gate the on-device AI model tier. */
    private fun getTotalRamBytes(): Long {
        val activityManager = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
        val info = ActivityManager.MemoryInfo()
        activityManager.getMemoryInfo(info)
        return info.totalMem
    }

    /**
     * Returns the raw bytes of the device's default (regular-weight) system font,
     * or null if it cannot be located. Flutter loads these bytes via FontLoader,
     * bypassing minikin's name-based font resolution entirely — which is necessary
     * because OEMs like Samsung apply font overrides through proprietary settings
     * rather than modifying fonts.xml.
     */
    private fun getSystemFontBytes(): ByteArray? {
        val path = findSystemFontPath() ?: return null
        return try {
            File(path).readBytes()
        } catch (_: Exception) {
            null
        }
    }

    /**
     * Tries multiple strategies to locate the active system font file, in order
     * of reliability for OEM devices:
     *   1. Samsung-specific System Settings keys
     *   2. fonts.xml (works on stock Android and some OEMs)
     */
    private fun findSystemFontPath(): String? =
        findViaSamsungSettings() ?: findViaFontsXml()

    // ── Samsung ───────────────────────────────────────────────────────────────

    private fun findViaSamsungSettings(): String? {
        if (!android.os.Build.MANUFACTURER.equals("samsung", ignoreCase = true)) return null

        // Samsung stores the active font as either a directory path or a font name
        val settingsKeys = listOf("current_sec_font_path", "samsung_font_typeface")
        for (key in settingsKeys) {
            try {
                val value = Settings.System.getString(contentResolver, key)
                    ?.trim()
                    ?.takeIf { it.isNotEmpty() }
                    ?: continue

                // Case A: value is a directory  →  find the Regular .ttf/.otf inside it
                val dir = File(value)
                if (dir.isDirectory) {
                    val font = regularFontInDir(dir)
                    if (font != null) return font
                }

                // Case B: value is a font family name  →  look in /system/fonts/
                for (candidate in listOf(
                    "$SYSTEM_FONTS_DIR/${value}-Regular.ttf",
                    "$SYSTEM_FONTS_DIR/${value}-Regular.otf",
                    "$SYSTEM_FONTS_DIR/$value.ttf",
                    "$SYSTEM_FONTS_DIR/$value.otf",
                )) {
                    if (File(candidate).exists()) return candidate
                }
            } catch (_: Exception) {
                // Settings key unavailable on this device — try next
            }
        }
        return null
    }

    /** Picks the Regular-weight font file from a directory, or any .ttf/.otf as fallback. */
    private fun regularFontInDir(dir: File): String? {
        val files = dir.listFiles()?.filter {
            it.extension.lowercase() in listOf("ttf", "otf")
        } ?: return null
        return (files.firstOrNull { it.nameWithoutExtension.contains("Regular", ignoreCase = true) }
            ?: files.firstOrNull())?.absolutePath
    }

    // ── fonts.xml ─────────────────────────────────────────────────────────────

    private fun findViaFontsXml(): String? {
        val xmlCandidates = listOf("/system/etc/fonts.xml", "/system/etc/system_fonts.xml")
        for (xmlPath in xmlCandidates) {
            try {
                val xmlFile = File(xmlPath)
                if (!xmlFile.exists()) continue
                val filename = parseSansSerifFontFile(xmlFile) ?: continue
                val fullPath = "$SYSTEM_FONTS_DIR/$filename"
                if (File(fullPath).exists()) return fullPath
            } catch (_: Exception) {}
        }
        return null
    }

    /**
     * Parses fonts.xml and returns the filename of the weight-400 (Regular) font
     * in the sans-serif family. Falls back to the first font in the family if no
     * weight-400 entry exists.
     */
    private fun parseSansSerifFontFile(file: File): String? {
        val parser: XmlPullParser = XmlPullParserFactory.newInstance().newPullParser()
        parser.setInput(file.inputStream(), "UTF-8")

        var inSansSerif = false
        var firstFont: String? = null

        while (true) {
            val event = parser.next()
            if (event == XmlPullParser.END_DOCUMENT) break

            when (event) {
                XmlPullParser.START_TAG -> when (parser.name) {
                    "family" -> {
                        inSansSerif = parser.getAttributeValue(null, "name") == "sans-serif"
                    }
                    "font" -> if (inSansSerif) {
                        val weight = parser.getAttributeValue(null, "weight")?.toIntOrNull()
                        if (parser.next() == XmlPullParser.TEXT) {
                            val filename = parser.text?.trim()
                            if (!filename.isNullOrEmpty()) {
                                if (firstFont == null) firstFont = filename
                                if (weight == 400) return filename  // ideal: Regular weight
                            }
                        }
                    }
                }
                XmlPullParser.END_TAG -> if (parser.name == "family" && inSansSerif) {
                    inSansSerif = false
                    if (firstFont != null) return firstFont  // best available in this family
                }
            }
        }
        return firstFont
    }
}
