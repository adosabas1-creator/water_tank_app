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
