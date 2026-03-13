# Flutter wrapper (minimal)
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.FlutterInjector { *; }

# Mobile Scanner (CameraX + ML Kit)
-keep class com.google.mlkit.** { *; }
-keep class androidx.camera.** { *; }

# Play Store deferred components (referenced by Flutter engine)
-dontwarn com.google.android.play.core.splitcompat.**
-dontwarn com.google.android.play.core.splitinstall.**
-dontwarn com.google.android.play.core.tasks.**
