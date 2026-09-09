package com.alborai.water_tank_app

import android.content.Intent
import android.net.Uri
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {

    private val channelName = "com.alborai.water_tank_app/backup"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            channelName
        ).setMethodCallHandler { call, result ->

            when (call.method) {
                "sendBackupByEmail" -> {
                    val filePath = call.argument<String>("filePath")

                    if (filePath.isNullOrBlank()) {
                        result.error(
                            "INVALID_FILE",
                            "مسار النسخة الاحتياطية غير صحيح",
                            null
                        )
                        return@setMethodCallHandler
                    }

                    try {
                        val file = File(filePath)

                        if (!file.exists()) {
                            result.error(
                                "FILE_NOT_FOUND",
                                "ملف النسخة الاحتياطية غير موجود",
                                null
                            )
                            return@setMethodCallHandler
                        }

                        val uri: Uri = FileProvider.getUriForFile(
                            this,
                            "${applicationContext.packageName}.fileprovider",
                            file
                        )

                        val intent = Intent(Intent.ACTION_SEND).apply {
                            type = "application/octet-stream"
                            putExtra(
                                Intent.EXTRA_EMAIL,
                                arrayOf("adosabm1@gmail.com")
                            )
                            putExtra(
                                Intent.EXTRA_SUBJECT,
                                "نسخة احتياطية - شركة البرعي للمياه"
                            )
                            putExtra(
                                Intent.EXTRA_TEXT,
                                "مرفق النسخة الاحتياطية لقاعدة بيانات التطبيق."
                            )
                            putExtra(Intent.EXTRA_STREAM, uri)
                            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                        }

                        startActivity(
                            Intent.createChooser(
                                intent,
                                "إرسال النسخة الاحتياطية"
                            )
                        )

                        result.success(true)
                    } catch (e: Exception) {
                        result.error(
                            "EMAIL_ERROR",
                            "تعذر فتح تطبيق البريد: ${e.message}",
                            null
                        )
                    }
                }

                else -> result.notImplemented()
            }
        }
    }
}
