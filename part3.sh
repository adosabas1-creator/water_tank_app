#!/usr/bin/env bash

# 1. شاشة كشف حساب عميل
cat > lib/screens/statements/client_statement_screen.dart << 'DART'
import 'package:flutter/material.dart';
import '../../models/client.dart';
import '../../services/client_service.dart';
import '../../services/sale_service.dart';
import '../../services/payment_service.dart';

class ClientStatementScreen extends StatefulWidget {
  final int clientId;
  const ClientStatementScreen({super.key, required this.clientId});

  @override
  State<ClientStatementScreen> createState() => _ClientStatementScreenState();
}

class _ClientStatementScreenState extends State<ClientStatementScreen> {
  final ClientService _clientService = ClientService();
  final SaleService _saleService = SaleService();
  final PaymentService _paymentService = PaymentService();

  Client? _client;
  double _totalSales = 0;
  double _totalPayments = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final client = await _clientService.getClientById(widget.clientId);
    final sales = await _saleService.getAllSales();
    final payments = await _paymentService.getPaymentsForClient(widget.clientId);

    final clientSales = sales.where((s) => s.clientId == widget.clientId).toList();
    _totalSales = clientSales.fold(0, (sum, s) => sum + s.totalAmount);
    _totalPayments = payments.fold(0, (sum, p) => sum + p.amount);

    setState(() {
      _client = client;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_client == null) {
      return const Scaffold(body: Center(child: Text('العميل غير موجود')));
    }
    final balance = _totalSales - _totalPayments;
    return Scaffold(
      appBar: AppBar(title: Text('كشف حساب: ${_client!.name}')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    const Text('الرصيد السابق', style: TextStyle(fontSize: 16)),
                    Text('${_totalSales - _totalPayments} ريال', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            _buildRow('إجمالي المبيعات', _totalSales),
            _buildRow('إجمالي المدفوعات', _totalPayments),
            Divider(),
            _buildRow('الرصيد المتبقي', balance, bold: true),
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
DART

# 2. شاشة كشف حساب مورد
cat > lib/screens/statements/supplier_statement_screen.dart << 'DART'
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
DART

# 3. شاشة كشوف الحسابات (تبويب عملاء وموردون)
cat > lib/screens/statements/statements_screen.dart << 'DART'
import 'package:flutter/material.dart';
import 'client_statement_screen.dart';
import 'supplier_statement_screen.dart';
import '../../services/client_service.dart';
import '../../services/supplier_service.dart';

class StatementsScreen extends StatefulWidget {
  const StatementsScreen({super.key});
  @override
  State<StatementsScreen> createState() => _StatementsScreenState();
}

class _StatementsScreenState extends State<StatementsScreen> {
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('كشوف الحسابات'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'العملاء'),
              Tab(text: 'الموردون'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildClientList(),
            _buildSupplierList(),
          ],
        ),
      ),
    );
  }

  Widget _buildClientList() {
    return FutureBuilder(
      future: ClientService().getAllClients(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final clients = snapshot.data!;
        return ListView.builder(
          itemCount: clients.length,
          itemBuilder: (context, index) {
            final client = clients[index];
            return ListTile(
              title: Text(client.name),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ClientStatementScreen(clientId: client.id!))),
            );
          },
        );
      },
    );
  }

  Widget _buildSupplierList() {
    return FutureBuilder(
      future: SupplierService().getAllSuppliers(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final suppliers = snapshot.data!;
        return ListView.builder(
          itemCount: suppliers.length,
          itemBuilder: (context, index) {
            final supplier = suppliers[index];
            return ListTile(
              title: Text(supplier.name),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SupplierStatementScreen(supplierId: supplier.id!))),
            );
          },
        );
      },
    );
  }
}
DART

# 4. شاشة التقارير
cat > lib/screens/reports/reports_screen.dart << 'DART'
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
DART

echo "✅ تم إنشاء الجزء الثالث بنجاح!"
