# Keep Google ML Kit classes
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.mlkit.**
-dontwarn com.google.android.gms.**

# Keep Firebase classes
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**

# Keep encryption classes
-keep class javax.crypto.** { *; }
-keep class javax.crypto.spec.** { *; }

# Keep image processing classes
-keep class com.yalantis.ucrop.** { *; }
-dontwarn com.yalantis.ucrop.**



