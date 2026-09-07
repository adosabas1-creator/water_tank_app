import 'package:flutter/material.dart';
import '../../services/sale_service.dart';
import '../../services/filling_operation_service.dart';
import '../../services/expense_service.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});
  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final SaleService _saleService = SaleService();
  final FillingOperationService _fillingService = FillingOperationService();
  final ExpenseService _expenseService = ExpenseService();

  double _totalSales = 0;
  double _totalPurchases = 0;
  double _totalExpenses = 0;
  double _profit = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  Future<void> _loadReport() async {
    setState(() => _isLoading = true);
    final sales = await _saleService.getAllSales();
    final fillings = await _fillingService.getAllOperations();
    final expenses = await _expenseService.getAllExpenses();

    _totalSales = sales.fold(0, (sum, s) => sum + s.totalAmount);
    _totalPurchases = fillings.fold(0, (sum, f) => sum + (f.units * f.purchasePrice));
    _totalExpenses = expenses.fold(0, (sum, e) => sum + e.amount);
    _profit = _totalSales - _totalPurchases - _totalExpenses;

    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('التقارير')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildCard('إجمالي المبيعات', _totalSales, Icons.shopping_cart),
                  _buildCard('إجمالي المشتريات', _totalPurchases, Icons.local_gas_station),
                  _buildCard('إجمالي المصروفات', _totalExpenses, Icons.money_off),
                  Divider(),
                  _buildCard('الأرباح', _profit, Icons.trending_up, color: _profit >= 0 ? Colors.green : Colors.red),
                ],
              ),
            ),
    );
  }

  Widget _buildCard(String label, double value, IconData icon, {Color? color}) {
    return Card(
      child: ListTile(
        leading: Icon(icon, color: color ?? Colors.blue),
        title: Text(label),
        trailing: Text(
          '${value.toStringAsFixed(2)} ريال',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color),
        ),
      ),
    );
  }
}
