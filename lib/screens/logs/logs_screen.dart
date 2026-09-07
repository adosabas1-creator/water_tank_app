import 'package:flutter/material.dart';
import '../../models/operation_log.dart';
import '../../services/operation_log_service.dart';

class LogsScreen extends StatefulWidget {
  const LogsScreen({super.key});
  @override
  State<LogsScreen> createState() => _LogsScreenState();
}

class _LogsScreenState extends State<LogsScreen> {
  final OperationLogService _service = OperationLogService();
  late Future<List<OperationLog>> _future;

  @override
  void initState() {
    super.initState();
    _future = _service.getAllLogs();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('سجل العمليات')),
      body: FutureBuilder<List<OperationLog>>(
        future: _future,
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final logs = snapshot.data!;
          if (logs.isEmpty) return const Center(child: Text('لا توجد عمليات مسجلة'));
          return ListView.builder(
            itemCount: logs.length,
            itemBuilder: (context, index) {
              final log = logs[index];
              return ListTile(
                leading: Icon(
                  log.action == 'create' ? Icons.add_circle : log.action == 'update' ? Icons.edit : Icons.delete,
                  color: log.action == 'create' ? Colors.green : log.action == 'update' ? Colors.blue : Colors.red,
                ),
                title: Text('${log.tableName} #${log.recordId}'),
                subtitle: Text(log.details ?? ''),
                trailing: Text(log.timestamp.substring(0, 16)),
              );
            },
          );
        },
      ),
    );
  }
}
