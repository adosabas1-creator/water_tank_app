import 'package:flutter/material.dart';

import '../../models/supplier.dart';
import '../../services/account_transaction_service.dart';
import '../../services/payment_service.dart';
import '../../services/supplier_service.dart';
import '../payments/payments_screen.dart';
import 'add_account_transaction_screen.dart';

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
  bool _isLoading = true;
  int _debugTransactionCount = 0;
  int _debugPaymentCount = 0;
  String? _error;

  List<_SupplierStatementEntry> _entries = [];
  double _totalDebit = 0;
  double _totalCredit = 0;

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

      if (supplier == null) {
        if (!mounted) return;

        setState(() {
          _supplier = null;
          _isLoading = false;
        });
        return;
      }

      final transactions = await _accountService.getTransactions(
        accountType: 'supplier',
        referenceId: widget.supplierId,
      );

      final payments = await _paymentService.getPaymentsForSupplier(
        widget.supplierId,
      );

      _debugTransactionCount = transactions.length;
      _debugPaymentCount = payments.length;

      final entries = <_SupplierStatementEntry>[];

      debugPrint(
          'SUPPLIER DEBUG: id=${widget.supplierId}, transactions=${transactions.length}, payments=${payments.length}');

      for (final transaction in transactions) {
        entries.add(
          _SupplierStatementEntry(
            date: transaction.transactionDate,
            description: _transactionDescription(
              transaction.transactionType,
            ),
            debit: transaction.amount,
            credit: 0,
            notes: transaction.notes,
            icon: Icons.add_card,
          ),
        );
      }

      for (final payment in payments) {
        entries.add(
          _SupplierStatementEntry(
            date: payment.paymentDate,
            description: 'دفعة مورد',
            debit: 0,
            credit: payment.amount,
            notes: _paymentNotes(
              payment.paymentMethod,
              payment.referenceNumber,
              payment.notes,
            ),
            icon: Icons.payments,
          ),
        );
      }

      entries.sort(
        (a, b) =>
            DateTime.tryParse(a.date)?.compareTo(
              DateTime.tryParse(b.date) ?? DateTime(1900),
            ) ??
            0,
      );

      double debit = 0;
      double credit = 0;

      for (final entry in entries) {
        debit += entry.debit;
        credit += entry.credit;
        entry.balance = debit - credit;
      }

      if (!mounted) return;

      setState(() {
        _supplier = supplier;
        _entries = entries;
        _totalDebit = debit;
        _totalCredit = credit;
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

  String _transactionDescription(String type) {
    switch (type) {
      case 'opening_balance':
        return 'رصيد افتتاحي';
      case 'debt':
        return 'إضافة دين';
      case 'adjustment':
        return 'تسوية حساب';
      default:
        return 'حركة حساب';
    }
  }

  String? _paymentNotes(
    String? method,
    String? referenceNumber,
    String? notes,
  ) {
    final parts = <String>[];

    if (method != null && method.isNotEmpty) {
      final methodText = switch (method) {
        'cash' => 'نقدي',
        'transfer' => 'حوالة',
        'bank_transfer' => 'تحويل بنكي',
        'other' => 'أخرى',
        _ => method,
      };

      parts.add('طريقة الدفع: $methodText');
    }

    if (referenceNumber != null && referenceNumber.isNotEmpty) {
      parts.add('رقم المرجع: $referenceNumber');
    }

    if (notes != null && notes.isNotEmpty) {
      parts.add(notes);
    }

    return parts.isEmpty ? null : parts.join(' • ');
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

  Future<void> _addPayment() async {
    if (_supplier == null) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PaymentsScreen(
          initialPaymentType: 'supplier_payment',
          initialReferenceId: widget.supplierId,
        ),
      ),
    );

    if (mounted) {
      await _loadData();
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

    final balance = _totalDebit - _totalCredit;

    return Scaffold(
      appBar: AppBar(
        title: Text('كشف حساب: ${_supplier!.name}'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'payment') {
                _addPayment();
              } else if (value == 'transaction') {
                _addTransaction();
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'payment',
                child: ListTile(
                  leading: Icon(Icons.payments),
                  title: Text('إضافة دفعة مورد'),
                ),
              ),
              PopupMenuItem(
                value: 'transaction',
                child: ListTile(
                  leading: Icon(Icons.add_card),
                  title: Text('إضافة حركة حساب'),
                ),
              ),
            ],
          ),
          IconButton(
            onPressed: _loadData,
            tooltip: 'تحديث',
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(12),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const Text(
                      'الرصيد المتبقي للمورد',
                      style: TextStyle(fontSize: 16),
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
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: _summaryItem(
                            'إجمالي المدين',
                            _totalDebit,
                            Icons.arrow_downward,
                          ),
                        ),
                        Expanded(
                          child: _summaryItem(
                            'إجمالي الدائن (المدفوعات)',
                            _totalCredit,
                            Icons.arrow_upward,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (_entries.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('لا توجد حركات في حساب المورد'),
                        const SizedBox(height: 8),
                        Text('رقم المورد: ${widget.supplierId}'),
                        Text('حركات الحساب: $_debugTransactionCount'),
                        Text('دفعات المورد: $_debugPaymentCount'),
                      ],
                    ),
                  ),
                ),
              )
            else
              ..._entries.map(_buildEntry),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addPayment,
        icon: const Icon(Icons.payments),
        label: const Text('إضافة دفعة'),
      ),
    );
  }

  Widget _summaryItem(
    String title,
    double value,
    IconData icon,
  ) {
    return Column(
      children: [
        Icon(icon, size: 20),
        const SizedBox(height: 4),
        Text(title),
        const SizedBox(height: 2),
        Text(
          '${value.toStringAsFixed(2)} ريال',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildEntry(_SupplierStatementEntry entry) {
    final date = DateTime.tryParse(entry.date);

    final dateText = date == null
        ? entry.date
        : '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

    return Card(
      child: ListTile(
        leading: CircleAvatar(
          child: Icon(entry.icon),
        ),
        title: Text(
          entry.description,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('التاريخ: $dateText'),
            if (entry.notes != null && entry.notes!.isNotEmpty)
              Text(entry.notes!),
            Text(
              'الرصيد الجاري: ${entry.balance.toStringAsFixed(2)} ريال',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        isThreeLine: true,
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (entry.debit > 0)
              Text(
                'مدين ${entry.debit.toStringAsFixed(2)}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            if (entry.credit > 0)
              Text(
                'دائن ${entry.credit.toStringAsFixed(2)}',
                style: const TextStyle(fontWeight: FontWeight.bold),
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
}

class _SupplierStatementEntry {
  final String date;
  final String description;
  final double debit;
  final double credit;
  final String? notes;
  final IconData icon;
  double balance = 0;

  _SupplierStatementEntry({
    required this.date,
    required this.description,
    required this.debit,
    required this.credit,
    this.notes,
    required this.icon,
  });
}
