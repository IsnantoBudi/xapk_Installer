# ProGuard / R8 Rules for XAPK Installer

# Keep Flutter Framework and Embedder classes
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Keep MainActivity and its method channel callbacks
-keep class com.xapk.installer.xapk_installer.** { *; }

# Keep AndroidX DocumentFile for SAF (Storage Access Framework) OBB operations
-keep class androidx.documentfile.** { *; }
-dontwarn androidx.documentfile.**

# Keep PackageInstaller native APIs
-keep class android.content.pm.PackageInstaller** { *; }
-keep class android.content.pm.PackageInfo** { *; }

# Suppress common non-fatal warnings
-dontwarn io.flutter.**
