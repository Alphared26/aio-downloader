# Flutter Wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Flutter Foreground Task
-keep class com.pravera.flutter_foreground_task.** { *; }

# Google Fonts
-keep class com.google.fonts.** { *; }

# Receive Sharing Intent
-keep class com.kasem.receive_sharing_intent.** { *; }

# Path Provider
-keep class com.tekartik.sqflite.** { *; } # Often used with path provider

# OkHttp (used by http and cached_network_image)
-keepattributes Signature
-keepattributes *Annotation*
-keep class okhttp3.** { *; }
-keep interface okhttp3.** { *; }
-dontwarn okhttp3.**

# Gson/JSON usage (if any in plugins)
-keep class com.google.gson.** { *; }

# Retain GeneratedPluginRegistrant
-keep class io.flutter.plugins.GeneratedPluginRegistrant { *; }

# Preserve custom MainActivity if needed
-keep class com.aio_downloader.alphared26.MainActivity { *; }

# Flutter Local Notifications
-keep class com.dexterous.flutterlocalnotifications.** { *; }

# Shared Preferences
-keep class io.flutter.plugins.sharedpreferences.** { *; }

# Google Play Core (often required by Flutter embedding)
-dontwarn com.google.android.play.core.**
-keep class com.google.android.play.core.** { *; }

