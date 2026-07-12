# ProGuard / R8 rules for TakipVersie1 (Flutter + Firebase) — Android 16 (API 36)
# Flutter-specific rules
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.**

# Firebase rules (with 16KB page size compatibility)
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**

# Keep Google Sign-In
-keep class com.google.android.gms.auth.api.signin.** { *; }

# Keep data model classes used with Firestore (reflection may be needed)
-keepattributes Signature
-keepattributes *Annotation*
-keep class com.example.takipversie1.** { *; }

# General Android
-keepattributes InnerClasses
-keepattributes EnclosingMethod
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile

# Remove logging in release
-assumenosideeffects class android.util.Log {
    public static boolean isLoggable(java.lang.String, int);
    public static int v(...);
    public static int d(...);
    public static int i(...);
}

# Android 16 — Edge-to-Edge / Predictive Back
-keep class androidx.activity.** { *; }
-keep class androidx.core.** { *; }

# Prevent obfuscation of Firebase model classes (Gson/reflection based)
-keepattributes *Annotation*
-keepclassmembers class * {
    @com.google.firebase.firestore.PropertyName <fields>;
}
