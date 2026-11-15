# Flutter Core
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Google Play Core / Deferred Components
-dontwarn com.google.android.play.core.**

# PowerSync & SQLite Async dependencies
-keep class com.powersync.** { *; }
-keep class com.sqliteasync.** { *; }
-keep class * extends com.powersync.** { *; }
-keep class * extends com.sqliteasync.** { *; }
-keep public class * extends sqlite_async.** { *; }
-keep class com.journeyapps.** { *; }

# OkHttp & WebSocket libraries
-dontwarn okhttp3.**
-dontwarn okio.**
-keep class okhttp3.** { *; }
-keep interface okhttp3.** { *; }

# Supabase Auth Storage & App Links
-keep class io.flutter.plugins.sharedpreferences.** { *; }
-keep class com.llfbandit.app_links.** { *; }

# App Main Activity & Settings Channel
-keep class com.axis.axis.** { *; }

# Awesome Notifications & Audio
-keep class me.carda.awesome_notifications.** { *; }
-keep class me.carda.** { *; }

-keepattributes *Annotation*,Signature,Exception,InnerClasses
