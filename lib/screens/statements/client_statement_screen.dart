import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../../models/client.dart';
import '../../services/account_transaction_service.dart';
import '../../services/client_service.dart';
import '../../services/payment_service.dart';
import '../payments/payments_screen.dart';
import 'add_account_transaction_screen.dart';

class ClientStatementScreen extends StatefulWidget {
  final int clientId;

  const ClientStatementScreen({
    super.key,
    required this.clientId,
  });

  @override
  State<ClientStatementScreen> createState() => _ClientStatementScreenState();
}

class _ClientStatementScreenState extends State<ClientStatementScreen> {
  final ClientService _clientService = ClientService();
  final PaymentService _paymentService = PaymentService();
  final AccountTransactionService _accountService = AccountTransactionService();

  Client? _client;
  bool _isLoading = true;
  String? _error;

  List<_StatementEntry> _entries = [];
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
      final client = await _clientService.getClientById(widget.clientId);

      if (client == null) {
        if (!mounted) return;
        setState(() {
          _client = null;
          _isLoading = false;
        });
        return;
      }

      final transactions = await _accountService.getTransactions(
        accountType: 'client',
        referenceId: widget.clientId,
      );
      final payments = await _paymentService.getPaymentsForClient(
        widget.clientId,
      );

      final entries = <_StatementEntry>[];

      for (final transaction in transactions) {
        entries.add(
          _StatementEntry(
            date: transaction.transactionDate,
            description: _transactionDescription(transaction.transactionType),
            debit: transaction.amount,
            credit: 0,
            notes: transaction.notes,
            icon: Icons.add_card,
          ),
        );
      }

      for (final payment in payments) {
        entries.add(
          _StatementEntry(
            date: payment.paymentDate,
            description: 'دفعة عميل',
            debit: 0,
            credit: payment.amount,
            notes: _paymentNotes(
                payment.paymentMethod, payment.referenceNumber, payment.notes),
            icon: Icons.payments,
          ),
        );
      }

      entries.sort(
        (a, b) =>
            DateTime.tryParse(a.date)
                ?.compareTo(DateTime.tryParse(b.date) ?? DateTime(1900)) ??
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
        _client = client;
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
      case 'debt':
        return 'عليه';
      case 'adjustment':
        return 'له';
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
    if (_client == null) return;

    final added = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AddAccountTransactionScreen(
          accountType: 'client',
          referenceId: widget.clientId,
          accountName: _client!.name,
        ),
      ),
    );

    if (added == true && mounted) {
      await _loadData();
    }
  }

  Future<void> _addPayment() async {
    if (_client == null) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PaymentsScreen(
          initialPaymentType: 'client_payment',
          initialReferenceId: widget.clientId,
        ),
      ),
    );

    if (mounted) {
      await _loadData();
    }
  }

  Future<void> _shareStatementPdf() async {
    if (_client == null) return;

    try {
      final regularFontData =
          await rootBundle.load('assets/fonts/Cairo-Regular.ttf');
      final boldFontData =
          await rootBundle.load('assets/fonts/Cairo-Bold.ttf');

      final regularFont = pw.Font.ttf(regularFontData);
      final boldFont = pw.Font.ttf(boldFontData);

      final document = pw.Document();

      final rows = <List<String>>[
        ['التاريخ', 'البيان', 'عليه', 'له', 'الرصيد'],
        ..._entries.map((entry) {
          final date = DateTime.tryParse(entry.date);
          final dateText = date == null
              ? entry.date
              : '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

          return [
            dateText,
            entry.description,
            entry.debit > 0 ? entry.debit.toStringAsFixed(2) : '-',
            entry.credit > 0 ? entry.credit.toStringAsFixed(2) : '-',
            entry.balance.toStringAsFixed(2),
          ];
        }),
      ];

      final balance = _totalDebit - _totalCredit;

      document.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          textDirection: pw.TextDirection.rtl,
          theme: pw.ThemeData.withFont(
            base: regularFont,
            bold: boldFont,
          ),
          build: (context) => [
            pw.Directionality(
              textDirection: pw.TextDirection.rtl,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                children: [
                  pw.Text(
                    'كشف حساب العميل',
                    textAlign: pw.TextAlign.center,
                    style: pw.TextStyle(
                      font: boldFont,
                      fontSize: 20,
                    ),
                  ),
                  pw.SizedBox(height: 8),
                  pw.Text(
                    'العميل: ${_client!.name}',
                    style: pw.TextStyle(font: boldFont, fontSize: 14),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'تاريخ الكشف: ${DateTime.now().toString().substring(0, 10)}',
                    style: pw.TextStyle(font: regularFont, fontSize: 10),
                  ),
                  pw.SizedBox(height: 16),
                  pw.TableHelper.fromTextArray(
                    headers: rows.first,
                    data: rows.skip(1).toList(),
                    headerStyle: pw.TextStyle(
                      font: boldFont,
                      fontSize: 9,
                    ),
                    cellStyle: pw.TextStyle(
                      font: regularFont,
                      fontSize: 8,
                    ),
                    headerDecoration:
                        const pw.BoxDecoration(color: PdfColors.grey300),
                    cellAlignment: pw.Alignment.center,
                    headerAlignment: pw.Alignment.center,
                    border: pw.TableBorder.all(
                      color: PdfColors.grey,
                      width: 0.5,
                    ),
                    cellPadding: const pw.EdgeInsets.all(4),
                  ),
                  pw.SizedBox(height: 16),
                  pw.Text(
                    'إجمالي عليه: ${_totalDebit.toStringAsFixed(2)} ريال',
                    style: pw.TextStyle(font: boldFont, fontSize: 12),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'إجمالي له: ${_totalCredit.toStringAsFixed(2)} ريال',
                    style: pw.TextStyle(font: boldFont, fontSize: 12),
                  ),
                  pw.SizedBox(height: 6),
                  pw.Text(
                    balance > 0
                        ? 'المتبقي عليه: ${balance.toStringAsFixed(2)} ريال'
                        : balance < 0
                            ? 'الرصيد له: ${balance.abs().toStringAsFixed(2)} ريال'
                            : 'الحساب مسدد بالكامل',
                    style: pw.TextStyle(font: boldFont, fontSize: 14),
                  ),
                ],
              ),
            ),
          ],
        ),
      );

      final bytes = await document.save();
      final safeName = _client!.name
          .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
          .trim();

      await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile.fromData(
              bytes,
              name: 'كشف_حساب_$safeName.pdf',
              mimeType: 'application/pdf',
            ),
          ],
          subject: 'كشف حساب العميل ${_client!.name}',
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تعذر إنشاء أو مشاركة كشف الحساب: $e'),
        ),
      );
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

    final balance = _totalDebit - _totalCredit;

    return Scaffold(
      appBar: AppBar(
        title: Text('كشف حساب: ${_client!.name}'),
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
                  title: Text('إضافة دفعة عميل'),
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
            onPressed: _shareStatementPdf,
            tooltip: 'مشاركة كشف الحساب',
            icon: const Icon(Icons.share),
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
                      'المبلغ المتبقي على العميل',
                      style: TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 6),
                    _buildBalanceDisplay(balance),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: _summaryItem(
                            'عليه',
                            _totalDebit,
                            Icons.arrow_downward,
                          ),
                        ),
                        Expanded(
                          child: _summaryItem(
                            'له',
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
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(
                    child: Text('لا توجد حركات في حساب العميل'),
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

  Widget _buildBalanceDisplay(double balance) {
    final amount = balance.abs().toStringAsFixed(2);

    String title;
    Color? color;

    if (balance > 0) {
      title = 'عليه $amount ريال';
      color = Colors.red;
    } else if (balance < 0) {
      title = 'له $amount ريال';
      color = Colors.green;
    } else {
      title = 'مسدد 0.00 ريال';
    }

    return Text(
      title,
      style: TextStyle(
        fontSize: 26,
        fontWeight: FontWeight.bold,
        color: color,
      ),
      textAlign: TextAlign.center,
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

  Widget _buildEntry(_StatementEntry entry) {
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
                'عليه ${entry.debit.toStringAsFixed(2)}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            if (entry.credit > 0)
              Text(
                'له ${entry.credit.toStringAsFixed(2)}',
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

class _StatementEntry {
  final String date;
  final String description;
  final double debit;
  final double credit;
  final String? notes;
  final IconData icon;
  double balance = 0;

  _StatementEntry({
    required this.date,
    required this.description,
    required this.debit,
    required this.credit,
    this.notes,
    required this.icon,
  });
}
