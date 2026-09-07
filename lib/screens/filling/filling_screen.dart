import 'package:flutter/material.dart';
import '../../models/filling_operation.dart';
import '../../services/filling_operation_service.dart';

class FillingScreen extends StatefulWidget {
  const FillingScreen({super.key});
  @override
  State<FillingScreen> createState() => _FillingScreenState();
}

class _FillingScreenState extends State<FillingScreen> {
  final FillingOperationService _service = FillingOperationService();
  late Future<List<FillingOperation>> _future;
  @override
  void initState() { super.initState(); _future = _service.getAllOperations(); }
  void _refresh() => setState(() => _future = _service.getAllOperations());
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('عمليات التعبئة')),
      body: FutureBuilder<List<FillingOperation>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (!snapshot.hasData || snapshot.data!.isEmpty) return const Center(child: Text('لا توجد عمليات'));
          return ListView.builder(
            itemCount: snapshot.data!.length,
            itemBuilder: (context, index) {
              final op = snapshot.data![index];
              return ListTile(title: Text('عملية #${op.id}'), subtitle: Text('الوحدات: ${op.units}'));
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(onPressed: () {}, child: const Icon(Icons.add)),
    );
  }
}
