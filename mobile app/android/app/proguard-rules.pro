# Flutter Wrapper Proguard Rules
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Agora RTC Engine Proguard Rules
-keep class io.agora.** { *; }
-keep class io.agora.rtc2.** { *; }
-keep class io.agora.base.** { *; }
-keep class io.agora.iris.** { *; }
-dontwarn io.agora.**

# Socket.IO & Engine.IO Proguard Rules
-keep class io.socket.** { *; }
-keep class io.socket.client.** { *; }
-keep class io.socket.engineio.** { *; }
-dontwarn io.socket.**
-dontwarn okhttp3.**

# Gson & JSON Deserialization
-keepattributes Signature
-keepattributes *Annotation*
-dontwarn sun.misc.**
-keep class com.google.gson.** { *; }

# Google Sign-In & Google Play Services Auth
-keep class com.google.android.gms.auth.api.signin.** { *; }
-keep class com.google.android.gms.common.** { *; }
-keep class com.google.android.gms.tasks.** { *; }
-keep class com.google.firebase.auth.** { *; }
-keep class com.google.firebase.** { *; }
-dontwarn com.google.android.gms.**
-dontwarn com.google.firebase.**
