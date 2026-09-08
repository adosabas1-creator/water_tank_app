import 'package:flutter/material.dart';

import '../../models/client.dart';
import '../../services/client_service.dart';
import '../../services/sale_service.dart';
import '../../services/payment_service.dart';

class ClientStatementScreen extends StatefulWidget {
  final int clientId;

  const ClientStatementScreen({
    super.key,
    required this.clientId,
  });

  @override
  State<ClientStatementScreen> createState() =>
      _ClientStatementScreenState();
}

class _ClientStatementScreenState
    extends State<ClientStatementScreen> {
  final ClientService _clientService = ClientService();
  final SaleService _saleService = SaleService();
  final PaymentService _paymentService = PaymentService();

  Client? _client;
  double _totalSales = 0;
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
      final client = await _clientService.getClientById(
        widget.clientId,
      );

      final sales = await _saleService.getAllSales();

      final payments =
          await _paymentService.getPaymentsForClient(
        widget.clientId,
      );

      final clientSales = sales
          .where((sale) => sale.clientId == widget.clientId)
          .toList();

      final totalSales = clientSales.fold<double>(
        0,
        (sum, sale) => sum + sale.totalAmount,
      );

      final totalPayments = payments.fold<double>(
        0,
        (sum, payment) => sum + payment.amount,
      );

      if (!mounted) return;

      setState(() {
        _client = client;
        _totalSales = totalSales;
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
          title: const Text('كشف حساب العميل'),
        ),
        body: _buildError(),
      );
    }

    if (_client == null) {
      return const Scaffold(
        body: Center(
          child: Text('العميل غير موجود'),
        ),
      );
    }

    final balance = _totalSales - _totalPayments;

    return Scaffold(
      appBar: AppBar(
        title: Text('كشف حساب: ${_client!.name}'),
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
                      'الرصيد الحالي',
                      style: TextStyle(
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${balance.toStringAsFixed(2)} ريال',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: balance > 0
                            ? Colors.red
                            : balance < 0
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
              'إجمالي المبيعات',
              _totalSales,
            ),
            _buildRow(
              'إجمالي المدفوعات',
              _totalPayments,
            ),
            const Divider(height: 24),
            _buildRow(
              'الرصيد المتبقي',
              balance,
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
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 16,
              fontWeight:
                  bold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            '${value.toStringAsFixed(2)} ريال',
            style: TextStyle(
              fontSize: 16,
              fontWeight:
                  bold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}
