# R8 ProGuard rules for Vyayama

# Suppress warning for legacy firebase-iid replaced by firebase-messaging
-dontwarn com.google.firebase.iid.**

# CameraX & ML Kit ProGuard rules for release builds
-keep class androidx.camera.** { *; }
-dontwarn androidx.camera.**

-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.internal.mlkit_vision_barcode.** { *; }
-keep class com.google.android.libraries.barhopper.** { *; }
-dontwarn com.google.mlkit.**
-dontwarn com.google.android.gms.internal.mlkit_vision_barcode.**
-dontwarn com.google.android.libraries.barhopper.**

# Preserve generic type signatures, annotations, and inner classes for reflection (required by Gson & flutter_local_notifications)
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes EnclosingMethod,InnerClasses

# Gson ProGuard rules (required for deserializing scheduled alarms from SharedPreferences)
-keep class com.google.gson.** { *; }
-dontwarn com.google.gson.**
-keep class * extends com.google.gson.reflect.TypeToken
-keep class * implements com.google.gson.TypeAdapter
-keep class * implements com.google.gson.TypeAdapterFactory
-keepclassmembers class * extends com.google.gson.reflect.TypeToken {
    *;
}

# flutter_local_notifications ProGuard rules
-keep class com.dexterous.flutterlocalnotifications.** { *; }
-dontwarn com.dexterous.flutterlocalnotifications.**
-keepclassmembers class com.dexterous.flutterlocalnotifications.** { *; }


