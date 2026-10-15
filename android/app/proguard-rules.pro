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
