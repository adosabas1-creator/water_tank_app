#!/usr/bin/env bash

# إنشاء خدمة سجل العمليات
cat > lib/services/operation_log_service.dart << 'DART'
import 'package:sqflite/sqflite.dart';
import '../core/database/database_helper.dart';
import '../models/operation_log.dart';

class OperationLogService {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  Future<int> addLog(OperationLog log) async {
    final db = await _dbHelper.database;
    return await db.insert('operation_logs', log.toMap());
  }

  Future<List<OperationLog>> getAllLogs() async {
    final db = await _dbHelper.database;
    final result = await db.query('operation_logs', orderBy: 'timestamp DESC');
    return result.map((e) => OperationLog.fromMap(e)).toList();
  }

  Future<void> deleteLog(int id) async {
    final db = await _dbHelper.database;
    await db.delete('operation_logs', where: 'id = ?', whereArgs: [id]);
  }
}
DART

# إنشاء نموذج OperationLog
cat > lib/models/operation_log.dart << 'DART'
class OperationLog {
  final int? id;
  final int userId;
  final String action;
  final String tableName;
  final int recordId;
  final String? details;
  final String timestamp;

  OperationLog({
    this.id,
    required this.userId,
    required this.action,
    required this.tableName,
    required this.recordId,
    this.details,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'action': action,
      'table_name': tableName,
      'record_id': recordId,
      'details': details,
      'timestamp': timestamp,
    };
  }

  factory OperationLog.fromMap(Map<String, dynamic> map) {
    return OperationLog(
      id: map['id'],
      userId: map['user_id'],
      action: map['action'],
      tableName: map['table_name'],
      recordId: map['record_id'],
      details: map['details'],
      timestamp: map['timestamp'],
    );
  }
}
DART

# إنشاء خدمة الاتصال
cat > lib/core/network/communication_service.dart << 'DART'
import 'package:url_launcher/url_launcher.dart';

class CommunicationService {
  static Future<void> callPhone(String phone) async {
    final Uri url = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }

  static Future<void> sendSMS(String phone, String message) async {
    final Uri url = Uri(scheme: 'sms', path: phone, query: 'body=${Uri.encodeComponent(message)}');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }

  static Future<void> openWhatsApp(String phone, String message) async {
    final String formattedPhone = phone.replaceAll('+', '').replaceAll(' ', '');
    final Uri url = Uri.parse('https://wa.me/$formattedPhone?text=${Uri.encodeComponent(message)}');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }
}
DART

echo "تم تنفيذ الجزء الأول بنجاح"
