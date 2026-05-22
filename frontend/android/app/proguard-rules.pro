# Flutter-specific ProGuard rules
-keep class io.flutter.** { *; }
-keep class io.flutter.embedding.** { *; }

# Keep JSON serialization classes
-keepattributes *Annotation*
-keepclassmembers class * {
    @com.google.gson.annotations.SerializedName <fields>;
}

# OkHttp / Retrofit (if used internally)
-dontwarn okhttp3.**
-dontwarn retrofit2.**
