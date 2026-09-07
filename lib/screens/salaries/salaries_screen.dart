import 'package:flutter/material.dart';
import '../../models/salary.dart';
import '../../services/salary_service.dart';

class SalariesScreen extends StatefulWidget {
  const SalariesScreen({super.key});
  @override
  State<SalariesScreen> createState() => _SalariesScreenState();
}

class _SalariesScreenState extends State<SalariesScreen> {
  final SalaryService _service = SalaryService();
  late Future<List<Salary>> _future;
  @override
  void initState() { super.initState(); _future = _service.getAllSalaries(); }
  void _refresh() => setState(() => _future = _service.getAllSalaries());
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الرواتب')),
      body: FutureBuilder<List<Salary>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (!snapshot.hasData || snapshot.data!.isEmpty) return const Center(child: Text('لا توجد رواتب'));
          return ListView.builder(
            itemCount: snapshot.data!.length,
            itemBuilder: (context, index) {
              final salary = snapshot.data![index];
              return ListTile(title: Text('موظف: ${salary.employeeId}'), subtitle: Text('الصافي: ${salary.netSalary}'));
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(onPressed: () {}, child: const Icon(Icons.add)),
    );
  }
}
