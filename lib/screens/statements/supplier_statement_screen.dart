import 'package:flutter/material.dart';
import '../../models/supplier.dart';
import '../../services/supplier_service.dart';
import '../../services/filling_operation_service.dart';
import '../../services/payment_service.dart';

class SupplierStatementScreen extends StatefulWidget {
  final int supplierId;
  const SupplierStatementScreen({super.key, required this.supplierId});

  @override
  State<SupplierStatementScreen> createState() => _SupplierStatementScreenState();
}

class _SupplierStatementScreenState extends State<SupplierStatementScreen> {
  Supplier? _supplier;
  double _totalPurchases = 0;
  double _totalPayments = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final supplierService = SupplierService();
    final fillingService = FillingOperationService();
    final paymentService = PaymentService();

    final supplier = await supplierService.getSupplierById(widget.supplierId);
    final operations = await fillingService.getAllOperations();
    final payments = await paymentService.getPaymentsForSupplier(widget.supplierId);

    final supplierOps = operations.where((op) => op.supplierId == widget.supplierId).toList();
    _totalPurchases = supplierOps.fold(0, (sum, op) => sum + (op.units * op.purchasePrice));
    _totalPayments = payments.fold(0, (sum, p) => sum + p.amount);

    setState(() {
      _supplier = supplier;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_supplier == null) return const Scaffold(body: Center(child: Text('المورد غير موجود')));
    final remaining = _totalPurchases - _totalPayments;
    return Scaffold(
      appBar: AppBar(title: Text('كشف حساب: ${_supplier!.name}')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildRow('إجمالي المشتريات', _totalPurchases),
            _buildRow('إجمالي المدفوعات', _totalPayments),
            Divider(),
            _buildRow('المتبقي للمورد', remaining, bold: true),
          ],
        ),
      ),
    );
  }

  Widget _buildRow(String label, double value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 16, fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
          Text('${value.toStringAsFixed(2)} ريال', style: TextStyle(fontSize: 16, fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
        ],
      ),
    );
  }
}
