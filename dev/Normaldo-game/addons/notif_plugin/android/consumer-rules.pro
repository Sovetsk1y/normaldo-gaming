# Godot loads the plugin class by name (reflection) from the manifest meta-data,
# and the OS instantiates the receiver by name from the manifest — both are
# invisible to R8's reachability analysis, so keep them explicitly.
-keep class com.normaldo.notif.NotifPluginAndroid { *; }
-keep class com.normaldo.notif.NotifAlarmReceiver { *; }
-keep class com.normaldo.notif.NotifScheduler { *; }
-keep class com.normaldo.notif.NormaldoFcmService { *; }

# GodotPlugin reflects over @UsedByGodot-annotated methods.
-keepclassmembers class com.normaldo.notif.** {
    @org.godotengine.godot.plugin.UsedByGodot *;
}
