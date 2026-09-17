import 'package:flutter/material.dart';

import '../../services/sale_service.dart';
import '../../services/expense_service.dart';
import '../../core/auth/permission_service.dart';
import '../../core/constants/permissions.dart';
import 'package:provider/provider.dart';
import '../../core/auth/user_provider.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final SaleService _saleService = SaleService();
  final ExpenseService _expenseService = ExpenseService();

  double _totalSales = 0;
  double _totalCostOfSales = 0;
  double _totalExpenses = 0;
  double _grossProfit = 0;
  double _netProfit = 0;
  List<Map<String, dynamic>> _supplierSalesShare = [];

  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();

    final user = context.read<UserProvider>().currentUser;
    if (!PermissionService.hasPermission(
      user,
      PermissionKeys.profitsView,
    )) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).pop();
      });
      return;
    }

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
      final expenses = await _expenseService.getAllExpenses();
      final supplierSalesShare =
          await _saleService.getSupplierSalesShareReport();

      final totalSales = sales.fold<double>(
        0,
        (sum, sale) => sum + sale.totalAmount,
      );

      final totalCostOfSales = sales.fold<double>(
        0,
        (sum, sale) => sum + sale.costAmount,
      );

      final totalExpenses = expenses.fold<double>(
        0,
        (sum, expense) => sum + expense.amount,
      );

      final grossProfit = totalSales - totalCostOfSales;
      final netProfit = grossProfit - totalExpenses;

      if (!mounted) return;

      setState(() {
        _totalSales = totalSales;
        _totalCostOfSales = totalCostOfSales;
        _totalExpenses = totalExpenses;
        _grossProfit = grossProfit;
        _netProfit = netProfit;
        _supplierSalesShare = supplierSalesShare;
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
          ? const Center(child: CircularProgressIndicator())
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
                        'تكلفة المبيعات',
                        _totalCostOfSales,
                        Icons.inventory_2_outlined,
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
                        'إجمالي الربح',
                        _grossProfit,
                        Icons.trending_up,
                        color: _grossProfit >= 0 ? Colors.green : Colors.red,
                      ),
                      _buildCard(
                        'صافي الربح',
                        _netProfit,
                        Icons.account_balance_wallet_outlined,
                        color: _netProfit >= 0 ? Colors.green : Colors.red,
                      ),
                      const SizedBox(height: 16),
                      const Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          'تكلفة مخزون الموردين المباع',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (_supplierSalesShare.isEmpty)
                        const Card(
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: Text(
                              'لا توجد مبيعات مرتبطة بمخزون الموردين حتى الآن.',
                            ),
                          ),
                        )
                      else
                        ..._supplierSalesShare.map(
                          (supplier) => Card(
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Text(
                                    supplier['supplier_name']?.toString() ??
                                        'مورد غير معروف',
                                    style: const TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'الوحدات المباعة: ${supplier['sold_units'] ?? 0}',
                                  ),
                                  Text(
                                    'تكلفة الوحدات المباعة: ${(supplier['cost_amount'] ?? 0).toStringAsFixed(2)} ريال',
                                  ),
                                  Text(
                                    'قيمة المبيعات: ${(supplier['sales_amount'] ?? 0).toStringAsFixed(2)} ريال',
                                  ),
                                  Text(
                                    'الربح: ${(supplier['profit_amount'] ?? 0).toStringAsFixed(2)} ريال',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color:
                                          (supplier['profit_amount'] ?? 0) >= 0
                                              ? Colors.green
                                              : Colors.red,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
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
            const Icon(Icons.error_outline, size: 48),
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
