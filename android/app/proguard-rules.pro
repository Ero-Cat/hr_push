# Flutter + plugin keep rules
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.plugins.** { *; }

# Preserve platform views and generated registrants
-keep class * extends io.flutter.embedding.engine.plugins.FlutterPlugin
-keep class * extends io.flutter.embedding.android.FlutterActivity
-keep class * extends io.flutter.embedding.android.FlutterFragment

# Keep protobuf/JSON models that may be reflected by plugins
-keepclassmembers class ** {
  @com.google.gson.annotations.SerializedName *;
}

# Permission handler plugin uses reflection
-keep class com.permissionhandler.** { *; }
-keep class com.libserialport.** { *; }
