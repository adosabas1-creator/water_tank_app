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
  final FillingOperationService _fillingService =
      FillingOperationService();
  final ExpenseService _expenseService = ExpenseService();

  double _totalSales = 0;
  double _totalPurchases = 0;
  double _totalExpenses = 0;
  double _profit = 0;

  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  Future<void> _loadReport() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      final sales = await _saleService.getAllSales();
      final fillings =
          await _fillingService.getAllOperations();
      final expenses =
          await _expenseService.getAllExpenses();

      final totalSales = sales.fold<double>(
        0,
        (sum, sale) => sum + sale.totalAmount,
      );

      final totalPurchases = fillings.fold<double>(
        0,
        (sum, filling) =>
            sum + (filling.units * filling.purchasePrice),
      );

      final totalExpenses = expenses.fold<double>(
        0,
        (sum, expense) => sum + expense.amount,
      );

      final profit =
          totalSales - totalPurchases - totalExpenses;

      if (!mounted) return;

      setState(() {
        _totalSales = totalSales;
        _totalPurchases = totalPurchases;
        _totalExpenses = totalExpenses;
        _profit = profit;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _error = 'حدث خطأ أثناء تحميل التقارير:\n$e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('التقارير'),
        actions: [
          IconButton(
            onPressed: _isLoading ? null : _loadReport,
            tooltip: 'تحديث',
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : _error != null
              ? _buildError()
              : RefreshIndicator(
                  onRefresh: _loadReport,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _buildCard(
                        'إجمالي المبيعات',
                        _totalSales,
                        Icons.shopping_cart,
                      ),
                      _buildCard(
                        'إجمالي المشتريات',
                        _totalPurchases,
                        Icons.local_gas_station,
                      ),
                      _buildCard(
                        'إجمالي المصروفات',
                        _totalExpenses,
                        Icons.money_off,
                      ),
                      const SizedBox(height: 8),
                      const Divider(),
                      const SizedBox(height: 8),
                      _buildCard(
                        'الأرباح',
                        _profit,
                        Icons.trending_up,
                        color: _profit >= 0
                            ? Colors.green
                            : Colors.red,
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline,
              size: 48,
            ),
            const SizedBox(height: 12),
            Text(
              _error!,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _loadReport,
              icon: const Icon(Icons.refresh),
              label: const Text('إعادة المحاولة'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCard(
    String label,
    double value,
    IconData icon, {
    Color? color,
  }) {
    return Card(
      child: ListTile(
        leading: Icon(
          icon,
          color: color ?? Colors.blue,
        ),
        title: Text(label),
        trailing: Text(
          '${value.toStringAsFixed(2)} ريال',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ),
    );
  }
}
