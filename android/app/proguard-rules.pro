# Flutter Wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class com.google.firebase.** { *; }
-dontwarn io.flutter.embedding.**

# Local Auth
-keep class androidx.biometric.** { *; }
-keep class androidx.core.hardware.fingerprint.** { *; }
-dontwarn androidx.biometric.**
-keep class androidx.fragment.app.** { *; }

# Flutter Secure Storage
-keep class com.it_nomads.fluttersecurestorage.** { *; }

# Error Prone / Tink
-dontwarn com.google.errorprone.annotations.**
-dontwarn javax.annotation.**
-dontwarn javax.annotation.concurrent.**

# Google API Client
-dontwarn com.google.api.client.http.**

# Joda Time
-dontwarn org.joda.time.**

# Keep all public classes
-keep public class * { public *; }

# Keep enum classes
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}

# Keep serializable classes
-keepclassmembers class * implements java.io.Serializable {
    static final long serialVersionUID;
    private static final java.io.ObjectStreamField[] serialPersistentFields;
    private void writeObject(java.io.ObjectOutputStream);
    private void readObject(java.io.ObjectInputStream);
    java.lang.Object writeReplace();
    java.lang.Object readResolve();
}

# Keep Kotlin metadata
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes Exceptions
-keepattributes InnerClasses
-keepattributes EnclosingMethod

# Keep all native methods
-keepclasseswithmembernames class * {
    native <methods>;
}

# Keep setters in Views so that animations can still work
-keepclassmembers public class * extends android.view.View {
    void set*(***);
    *** get*();
}

# Keep all application classes
-keep class com.ritme.ritme.** { *; }

# flutter_local_notifications: herhalende meldingen worden via Gson
# (TypeToken) in SharedPreferences bewaard. R8 stript zonder deze regels de
# generic-signature, waardoor ELKE cancel()/uitlezen van geplande meldingen
# in release-builds faalt met "Missing type parameter" (debug heeft geen
# minify en merkt er niets van — vandaar dat dit alleen op het toestel stuk
# ging: 0 ingepland, geen enkele herinnering).
-keep class com.dexterous.flutterlocalnotifications.** { *; }
-keep class com.google.gson.reflect.TypeToken { *; }
-keep class * extends com.google.gson.reflect.TypeToken
