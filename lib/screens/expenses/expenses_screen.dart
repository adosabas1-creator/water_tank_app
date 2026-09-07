import 'package:flutter/material.dart';
import '../../models/expense.dart';
import '../../services/expense_service.dart';

class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({super.key});
  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  final ExpenseService _service = ExpenseService();
  late Future<List<Expense>> _future;
  @override
  void initState() { super.initState(); _future = _service.getAllExpenses(); }
  void _refresh() => setState(() => _future = _service.getAllExpenses());
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('المصروفات')),
      body: FutureBuilder<List<Expense>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (!snapshot.hasData || snapshot.data!.isEmpty) return const Center(child: Text('لا توجد مصروفات'));
          return ListView.builder(
            itemCount: snapshot.data!.length,
            itemBuilder: (context, index) {
              final expense = snapshot.data![index];
              return ListTile(title: Text(expense.expenseType), subtitle: Text('المبلغ: ${expense.amount}'));
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(onPressed: () {}, child: const Icon(Icons.add)),
    );
  }
}
