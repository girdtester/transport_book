# Flutter wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# Keep all native methods
-keepclasseswithmembernames class * {
    native <methods>;
}

# Keep all classes from flutter_contacts plugin
-keep class com.github.contactlister.** { *; }

# Keep image_picker classes
-keep class io.flutter.plugins.imagepicker.** { *; }

# Keep share_plus classes
-keep class dev.fluttercommunity.plus.share.** { *; }

# Keep url_launcher classes
-keep class io.flutter.plugins.urllauncher.** { *; }

# Keep HTTP client classes
-keep class java.net.** { *; }
-keep class javax.net.** { *; }
-keep class okhttp3.** { *; }

# Don't warn about missing classes
-dontwarn io.flutter.**
-dontwarn com.github.contactlister.**
