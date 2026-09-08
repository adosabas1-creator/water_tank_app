import 'package:flutter/material.dart';

import '../../models/supplier.dart';
import '../../services/supplier_service.dart';
import '../../services/filling_operation_service.dart';
import '../../services/payment_service.dart';

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

class _SupplierStatementScreenState
    extends State<SupplierStatementScreen> {
  final SupplierService _supplierService = SupplierService();
  final FillingOperationService _fillingService =
      FillingOperationService();
  final PaymentService _paymentService = PaymentService();

  Supplier? _supplier;

  double _totalPurchases = 0;
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
      final supplier =
          await _supplierService.getSupplierById(
        widget.supplierId,
      );

      final operations =
          await _fillingService.getAllOperations();

      final payments =
          await _paymentService.getPaymentsForSupplier(
        widget.supplierId,
      );

      final supplierOperations = operations
          .where(
            (operation) =>
                operation.supplierId == widget.supplierId,
          )
          .toList();

      final totalPurchases =
          supplierOperations.fold<double>(
        0,
        (sum, operation) =>
            sum +
            (operation.units * operation.purchasePrice),
      );

      final totalPayments = payments.fold<double>(
        0,
        (sum, payment) => sum + payment.amount,
      );

      if (!mounted) return;

      setState(() {
        _supplier = supplier;
        _totalPurchases = totalPurchases;
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

    final remaining =
        _totalPurchases - _totalPayments;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'كشف حساب: ${_supplier!.name}',
        ),
        actions: [
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
              'إجمالي المشتريات',
              _totalPurchases,
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

  Widget _buildRow(
    String label,
    double value, {
    bool bold = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment:
            MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 16,
              fontWeight: bold
                  ? FontWeight.bold
                  : FontWeight.normal,
            ),
          ),
          Text(
            '${value.toStringAsFixed(2)} ريال',
            style: TextStyle(
              fontSize: 16,
              fontWeight: bold
                  ? FontWeight.bold
                  : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}
