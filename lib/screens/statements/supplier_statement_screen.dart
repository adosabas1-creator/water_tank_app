import 'package:flutter/material.dart';

import '../../models/supplier.dart';
import 'add_account_transaction_screen.dart';
import '../../services/account_transaction_service.dart';
import '../../services/payment_service.dart';
import '../../services/supplier_service.dart';

class SupplierStatementScreen extends StatefulWidget {
  final int supplierId;

  const SupplierStatementScreen({
    super.key,
    required this.supplierId,
  });

  @override
  State<SupplierStatementScreen> createState() =>
      _SupplierStatementScreenState();
}

class _SupplierStatementScreenState extends State<SupplierStatementScreen> {
  final SupplierService _supplierService = SupplierService();
  final AccountTransactionService _accountService = AccountTransactionService();
  final PaymentService _paymentService = PaymentService();

  Supplier? _supplier;
  double _totalTransactions = 0;
  double _totalPayments = 0;

  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      final supplier = await _supplierService.getSupplierById(
        widget.supplierId,
      );

      final totalTransactions = await _accountService.getTotalAmount(
        accountType: 'supplier',
        referenceId: widget.supplierId,
      );

      final payments = await _paymentService.getPaymentsForSupplier(
        widget.supplierId,
      );

      final totalPayments = payments.fold<double>(
        0,
        (sum, payment) => sum + payment.amount,
      );

      if (!mounted) return;

      setState(() {
        _supplier = supplier;
        _totalTransactions = totalTransactions;
        _totalPayments = totalPayments;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _error = 'حدث خطأ أثناء تحميل كشف الحساب:\n$e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('كشف حساب المورد'),
        ),
        body: _buildError(),
      );
    }

    if (_supplier == null) {
      return const Scaffold(
        body: Center(
          child: Text('المورد غير موجود'),
        ),
      );
    }

    final remaining = _totalTransactions - _totalPayments;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'كشف حساب: ${_supplier!.name}',
        ),
        actions: [
          IconButton(
            onPressed: _isLoading ? null : _addTransaction,
            tooltip: 'إضافة حركة',
            icon: const Icon(Icons.add),
          ),
          IconButton(
            onPressed: _isLoading ? null : _loadData,
            tooltip: 'تحديث',
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    const Icon(
                      Icons.account_balance_wallet,
                      size: 42,
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'المتبقي للمورد',
                      style: TextStyle(
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${remaining.toStringAsFixed(2)} ريال',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: remaining > 0
                            ? Colors.red
                            : remaining < 0
                                ? Colors.green
                                : null,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            _buildRow(
              'إجمالي الحركات',
              _totalTransactions,
            ),
            _buildRow(
              'إجمالي المدفوعات',
              _totalPayments,
            ),
            const Divider(height: 24),
            _buildRow(
              'المتبقي للمورد',
              remaining,
              bold: true,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addTransaction() async {
    if (_supplier == null) return;

    final added = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AddAccountTransactionScreen(
          accountType: 'supplier',
          referenceId: widget.supplierId,
          accountName: _supplier!.name,
        ),
      ),
    );

    if (added == true && mounted) {
      await _loadData();
    }
  }

  Widget _buildRow(
    String title,
    double value, {
    bool bold = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: TextStyle(
              fontWeight: bold ? FontWeight.bold : null,
            ),
          ),
          Text(
            '${value.toStringAsFixed(2)} ريال',
            style: TextStyle(
              fontWeight: bold ? FontWeight.bold : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
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
              onPressed: _loadData,
              icon: const Icon(Icons.refresh),
              label: const Text('إعادة المحاولة'),
            ),
          ],
        ),
      ),
    );
  }
}
