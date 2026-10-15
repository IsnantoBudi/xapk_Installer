package com.xapk.installer.xapk_installer

import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageInstaller
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Environment
import android.provider.Settings
import androidx.documentfile.provider.DocumentFile
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileInputStream
import java.io.FileOutputStream

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.xapk.installer/channel"
    private val ACTION_INSTALL_STATUS = "com.xapk.installer.ACTION_INSTALL_STATUS"
    private var methodChannel: MethodChannel? = null

    private val installReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            if (intent == null || context == null) return
            val status = intent.getIntExtra(PackageInstaller.EXTRA_STATUS, PackageInstaller.STATUS_FAILURE)
            val message = intent.getStringExtra(PackageInstaller.EXTRA_STATUS_MESSAGE) ?: ""
            val otherPackageName = intent.getStringExtra(PackageInstaller.EXTRA_OTHER_PACKAGE_NAME) ?: ""

            when (status) {
                PackageInstaller.STATUS_PENDING_USER_ACTION -> {
                    val confirmIntent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                        intent.getParcelableExtra(Intent.EXTRA_INTENT, Intent::class.java)
                    } else {
                        @Suppress("DEPRECATION")
                        intent.getParcelableExtra(Intent.EXTRA_INTENT)
                    }
                    if (confirmIntent != null) {
                        confirmIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        context.startActivity(confirmIntent)
                    }
                }
                PackageInstaller.STATUS_SUCCESS -> {
                    runOnUiThread {
                        methodChannel?.invokeMethod("onInstallResult", mapOf(
                            "status" to "SUCCESS",
                            "message" to "Installation completed successfully."
                        ))
                    }
                }
                else -> {
                    val isMiui = isMiuiDevice()
                    val detailedMsg = when {
                        message.contains("INSTALL_FAILED_OLDER_SDK", ignoreCase = true) ||
                        message.contains("Requires newer sdk", ignoreCase = true) -> {
                            "Versi Android perangkat Anda terlalu rendah untuk aplikasi ini (INSTALL_FAILED_OLDER_SDK). Silakan unduh versi berkas XAPK yang lebih lama."
                        }
                        isMiui && (message.contains("verification", ignoreCase = true) || message.contains("internal", ignoreCase = true)) -> {
                            "MIUI Optimization memblokir instalasi Split APK. Matikan 'Turn on MIUI Optimization' di Opsi Pengembang (Developer Options)."
                        }
                        else -> {
                            message.ifEmpty { "Gagal menginstal paket (Kode status: $status)" }
                        }
                    }
                    runOnUiThread {
                        methodChannel?.invokeMethod("onInstallResult", mapOf(
                            "status" to "FAILED",
                            "statusCode" to status,
                            "message" to detailedMsg,
                            "isMiui" to isMiui,
                            "otherPackage" to otherPackageName
                        ))
                    }
                }
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val filter = IntentFilter(ACTION_INSTALL_STATUS)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(installReceiver, filter, Context.RECEIVER_EXPORTED)
        } else {
            registerReceiver(installReceiver, filter)
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        try {
            unregisterReceiver(installReceiver)
        } catch (e: Exception) {
            // Ignored
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        methodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "installSplitApks" -> {
                    val paths = call.argument<List<String>>("paths")
                    if (paths.isNullOrEmpty()) {
                        result.error("EMPTY_PATHS", "Daftar file APK tidak ditemukan", null)
                        return@setMethodCallHandler
                    }
                    try {
                        installSplitApkFiles(paths)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("INSTALL_ERROR", e.localizedMessage, null)
                    }
                }
                "canRequestPackageInstalls" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        result.success(packageManager.canRequestPackageInstalls())
                    } else {
                        result.success(true)
                    }
                }
                "openInstallPermissionSettings" -> {
                    try {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            val intent = Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES).apply {
                                data = Uri.parse("package:$packageName")
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            }
                            startActivity(intent)
                            result.success(true)
                        } else {
                            result.success(false)
                        }
                    } catch (e: Exception) {
                        result.error("SETTINGS_ERROR", e.localizedMessage, null)
                    }
                }
                "isMiuiDevice" -> {
                    result.success(isMiuiDevice())
                }
                "getDeviceInfo" -> {
                    result.success(mapOf(
                        "sdkInt" to Build.VERSION.SDK_INT,
                        "release" to (Build.VERSION.RELEASE ?: ""),
                        "model" to (Build.MODEL ?: ""),
                        "manufacturer" to (Build.MANUFACTURER ?: ""),
                        "brand" to (Build.BRAND ?: "")
                    ))
                }
                "openDeveloperSettings" -> {
                    try {
                        val intent = Intent(Settings.ACTION_APPLICATION_DEVELOPMENT_SETTINGS).apply {
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("SETTINGS_ERROR", e.localizedMessage, null)
                    }
                }
                "requestStoragePermission" -> {
                    try {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                            if (!Environment.isExternalStorageManager()) {
                                try {
                                    val intent = Intent(Settings.ACTION_MANAGE_APP_ALL_FILES_ACCESS_PERMISSION).apply {
                                        data = Uri.parse("package:$packageName")
                                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                    }
                                    startActivity(intent)
                                } catch (ex: Exception) {
                                    val intent = Intent(Settings.ACTION_MANAGE_ALL_FILES_ACCESS_PERMISSION).apply {
                                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                    }
                                    startActivity(intent)
                                }
                            }
                            result.success(true)
                        } else {
                            requestPermissions(arrayOf(android.Manifest.permission.READ_EXTERNAL_STORAGE), 101)
                            result.success(true)
                        }
                    } catch (e: Exception) {
                        result.error("PERMISSION_ERROR", e.localizedMessage, null)
                    }
                }
                "copyObbFile" -> {
                    val sourcePath = call.argument<String>("sourcePath")
                    val pkgName = call.argument<String>("packageName")
                    val obbName = call.argument<String>("obbFileName")
                    val treeUriStr = call.argument<String>("treeUri")

                    if (sourcePath == null || pkgName == null || obbName == null) {
                        result.error("INVALID_ARGS", "Parameter OBB tidak lengkap", null)
                        return@setMethodCallHandler
                    }

                    Thread {
                        try {
                            val success = copyObb(sourcePath, pkgName, obbName, treeUriStr)
                            runOnUiThread {
                                if (success) {
                                    result.success(true)
                                } else {
                                    result.error("COPY_FAILED", "Gagal menyalin file OBB", null)
                                }
                            }
                        } catch (e: Exception) {
                            runOnUiThread {
                                result.error("COPY_EXCEPTION", e.localizedMessage, null)
                            }
                        }
                    }.start()
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun installSplitApkFiles(apkPaths: List<String>) {
        val packageInstaller = packageManager.packageInstaller
        val params = PackageInstaller.SessionParams(PackageInstaller.SessionParams.MODE_FULL_INSTALL)
        
        val sessionId = packageInstaller.createSession(params)
        val session = packageInstaller.openSession(sessionId)

        for (path in apkPaths) {
            val file = File(path)
            if (!file.exists()) continue
            val input = FileInputStream(file)
            val length = file.length()
            val output = session.openWrite(file.name, 0, length)
            input.use { inStream ->
                inStream.copyTo(output)
            }
            session.fsync(output)
            output.close()
        }

        val intent = Intent(ACTION_INSTALL_STATUS).apply {
            setPackage(packageName)
        }
        val flags = PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE
        val pendingIntent = PendingIntent.getBroadcast(this, sessionId, intent, flags)

        session.commit(pendingIntent.intentSender)
        session.close()
    }

    private fun isMiuiDevice(): Boolean {
        val manufacturer = Build.MANUFACTURER.lowercase()
        val brand = Build.BRAND.lowercase()
        if (manufacturer.contains("xiaomi") || manufacturer.contains("redmi") ||
            brand.contains("xiaomi") || brand.contains("redmi")) {
            return true
        }
        try {
            val propClass = Class.forName("android.os.SystemProperties")
            val getMethod = propClass.getMethod("get", String::class.java)
            val miuiVersion = getMethod.invoke(null, "ro.miui.ui.version.name") as? String
            if (miuiVersion != null && miuiVersion.isNotEmpty()) {
                return true
            }
        } catch (e: Exception) {
            // Ignored
        }
        return false
    }

    private fun copyObb(sourcePath: String, packageName: String, obbFileName: String, treeUriStr: String?): Boolean {
        val sourceFile = File(sourcePath)
        if (!sourceFile.exists()) return false

        val targetDir = File("/sdcard/Android/obb/$packageName")
        if (!targetDir.exists()) {
            targetDir.mkdirs()
        }
        if (targetDir.exists() && targetDir.canWrite()) {
            val targetFile = File(targetDir, obbFileName)
            sourceFile.inputStream().use { input ->
                FileOutputStream(targetFile).use { output ->
                    input.copyTo(output)
                }
            }
            return true
        }

        if (!treeUriStr.isNullOrEmpty()) {
            val rootTreeUri = Uri.parse(treeUriStr)
            val rootDocument = DocumentFile.fromTreeUri(this, rootTreeUri) ?: return false

            var packageDir = rootDocument.findFile(packageName)
            if (packageDir == null || !packageDir.isDirectory) {
                packageDir = rootDocument.createDirectory(packageName) ?: return false
            }

            var destFile = packageDir.findFile(obbFileName)
            if (destFile != null) {
                destFile.delete()
            }
            destFile = packageDir.createFile("application/octet-stream", obbFileName) ?: return false

            contentResolver.openOutputStream(destFile.uri)?.use { output ->
                sourceFile.inputStream().use { input ->
                    input.copyTo(output)
                }
            }
            return true
        }

        return false
    }
}
