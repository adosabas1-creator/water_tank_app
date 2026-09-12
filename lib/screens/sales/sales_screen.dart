import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/auth/user_provider.dart';
import '../../models/client.dart';
import '../../models/sale.dart';
import '../../models/supplier.dart';
import '../../services/client_service.dart';
import '../../services/sale_service.dart';
import '../../services/supplier_service.dart';

class SalesScreen extends StatefulWidget {
  const SalesScreen({super.key});

  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> {
  final _formKey = GlobalKey<FormState>();

  final _quantityController = TextEditingController();
  final _priceController = TextEditingController();
  final _notesController = TextEditingController();

  final _saleService = SaleService();
  final _clientService = ClientService();
  final _supplierService = SupplierService();

  List<Client> _clients = [];
  List<Supplier> _suppliers = [];
  List<Sale> _sales = [];

  int? _selectedClientId;
  int? _selectedSupplierId;

  DateTime _selectedDate = DateTime.now();

  String _clientPaymentStatus = 'paid';
  String _supplierPaymentStatus = 'paid';

  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadData();
    _quantityController.addListener(_refreshTotal);
    _priceController.addListener(_refreshTotal);
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _priceController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final clients = await _clientService.getAllClients();
      final suppliers = await _supplierService.getAllSuppliers();
      final sales = await _saleService.getAllSales();

      if (!mounted) return;

      setState(() {
        _clients = clients;
        _suppliers = suppliers;
        _sales = sales;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() => _loading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر تحميل بيانات المبيعات: $e')),
      );
    }
  }

  void _refreshTotal() {
    if (mounted) {
      setState(() {});
    }
  }

  double get _total {
    final quantity = int.tryParse(_quantityController.text.trim()) ?? 0;
    final price = double.tryParse(_priceController.text.trim()) ?? 0;
    return quantity * price;
  }

  String _formatNumber(double value) {
    if (value == value.roundToDouble()) {
      return value.toStringAsFixed(0);
    }
    return value.toStringAsFixed(2);
  }

  String _formatDate(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  String _paymentLabel(String? value) {
    switch (value) {
      case 'paid':
        return 'مدفوع';
      case 'unpaid':
        return 'آجل';
      case 'partial':
        return 'مدفوع جزئيًا';
      default:
        return 'غير محدد';
    }
  }

  String _supplierName(int? id) {
    if (id == null) return 'غير محدد';

    for (final supplier in _suppliers) {
      if (supplier.id == id) return supplier.name;
    }

    return 'مورد رقم $id';
  }

  String _clientName(int? id) {
    if (id == null) return 'عميل غير مسجل';

    for (final client in _clients) {
      if (client.id == id) return client.name;
    }

    return 'عميل رقم $id';
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      locale: const Locale('ar'),
    );

    if (picked != null && mounted) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _openSuppliers() async {
    await Navigator.of(context).pushNamed('/suppliers');

    if (!mounted) return;
    await _loadData();
  }

  Future<void> _openClients() async {
    await Navigator.of(context).pushNamed('/clients');

    if (!mounted) return;
    await _loadData();
  }

  Future<void> _saveSale() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final user = context.read<UserProvider>().currentUser;

    if (user == null || user.id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يجب تسجيل الدخول قبل حفظ البيع'),
        ),
      );
      return;
    }

    if (_selectedSupplierId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى اختيار المورد أولًا'),
        ),
      );
      return;
    }

    final quantity = int.tryParse(_quantityController.text.trim());
    final price = double.tryParse(_priceController.text.trim());

    if (quantity == null || quantity <= 0) {
      return;
    }

    if (price == null || price < 0) {
      return;
    }

    final total = quantity * price;
    final now = DateTime.now().toIso8601String();

    final userName = user.fullName.trim().isEmpty
        ? user.username
        : user.fullName.trim();

    setState(() {
      _saving = true;
    });

    try {
      final sale = Sale(
        syncId: 'sale_${DateTime.now().microsecondsSinceEpoch}',
        saleNumber: 'S-${DateTime.now().millisecondsSinceEpoch}',

        clientId: _selectedClientId,

        // لا يتم استخدام الخزان أو السائق في المبيعات الجديدة.
        tankId: null,
        driverId: null,

        supplierId: _selectedSupplierId!,
        units: quantity,
        salePrice: price,
        totalAmount: total,
        costAmount: 0,
        profitAmount: total,
        saleDate: _formatDate(_selectedDate),

        // حقل قديم للتوافق: نساوي حالة العميل.
        paymentStatus: _clientPaymentStatus,

        clientPaymentStatus: _clientPaymentStatus,
        supplierPaymentStatus: _supplierPaymentStatus,
        createdByName: userName,

        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),

        createdBy: user.id!,
        createdAt: now,
        updatedAt: now,
      );

      await _saleService.addSale(sale);

      if (!mounted) return;

      await _loadData();

      _showReceipt(
        saleNumber: sale.saleNumber ?? '-',
        supplierName: _supplierName(sale.supplierId),
        clientName: _clientName(sale.clientId),
        quantity: quantity,
        price: price,
        total: total,
        date: sale.saleDate,
        clientPaymentStatus: sale.clientPaymentStatus ?? 'paid',
        supplierPaymentStatus: sale.supplierPaymentStatus ?? 'paid',
        userName: sale.createdByName ?? userName,
      );

      _clearForm();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر حفظ البيع: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  void _clearForm() {
    _quantityController.clear();
    _priceController.clear();
    _notesController.clear();

    setState(() {
      _selectedClientId = null;
      _selectedSupplierId = null;
      _selectedDate = DateTime.now();
      _clientPaymentStatus = 'paid';
      _supplierPaymentStatus = 'paid';
    });
  }

  void _showReceipt({
    required String saleNumber,
    required String supplierName,
    required String clientName,
    required int quantity,
    required double price,
    required double total,
    required String date,
    required String clientPaymentStatus,
    required String supplierPaymentStatus,
    required String userName,
  }) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.receipt_long),
              SizedBox(width: 8),
              Text('إيصال البيع'),
            ],
          ),
          content: SingleChildScrollView(
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'رقم البيع: $saleNumber',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const Divider(),

                  _receiptRow('المورد', supplierName),
                  _receiptRow('العميل', clientName),
                  _receiptRow('عدد الوحدات', '$quantity'),
                  _receiptRow('سعر الوحدة', _formatNumber(price)),
                  _receiptRow('التاريخ', date),

                  const SizedBox(height: 4),

                  _receiptRow(
                    'دفع العميل',
                    _paymentLabel(clientPaymentStatus),
                  ),
                  _receiptRow(
                    'دفع المورد',
                    _paymentLabel(supplierPaymentStatus),
                  ),

                  _receiptRow('المستخدم', userName),

                  const Divider(),

                  _receiptRow(
                    'الإجمالي',
                    _formatNumber(total),
                    bold: true,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            FilledButton.icon(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.check),
              label: const Text('تم'),
            ),
          ],
        );
      },
    );
  }

  Widget _receiptRow(
    String title,
    String value, {
    bool bold = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontWeight: bold ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _decoration(String label, {String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      border: const OutlineInputBorder(),
      filled: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('المبيعات'),
        actions: [
          IconButton(
            onPressed: _loading ? null : _loadData,
            icon: const Icon(Icons.refresh),
            tooltip: 'تحديث',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildSaleForm(),
                  const SizedBox(height: 24),
                  _buildSalesList(),
                ],
              ),
            ),
    );
  }

  Widget _buildSaleForm() {
    final user = context.read<UserProvider>().currentUser;
    final userName = user == null
        ? 'غير مسجل'
        : (user.fullName.trim().isEmpty
            ? user.username
            : user.fullName.trim());

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _sectionTitle('إضافة مبيعة', Icons.point_of_sale),

              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      initialValue: _selectedSupplierId,
                      decoration: _decoration('المورد ⭐'),
                      hint: const Text('اختر المورد'),
                      items: _suppliers
                          .where((s) => s.id != null)
                          .map(
                            (supplier) => DropdownMenuItem<int>(
                              value: supplier.id!,
                              child: Text(supplier.name),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedSupplierId = value;
                        });
                      },
                      validator: (value) {
                        if (value == null) {
                          return 'المورد مطلوب';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _openSuppliers,
                    tooltip: 'إضافة مورد',
                    icon: const Icon(Icons.add),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: DropdownButtonFormField<int?>(
                      initialValue: _selectedClientId,
                      decoration: _decoration('العميل'),
                      hint: const Text('اختر العميل'),
                      items: [
                        const DropdownMenuItem<int?>(
                          value: null,
                          child: Text('عميل غير مسجل / بيع نقدي'),
                        ),
                        ..._clients.where((c) => c.id != null).map(
                              (client) => DropdownMenuItem<int?>(
                                value: client.id!,
                                child: Text(
                                  client.phone == null ||
                                          client.phone!.trim().isEmpty
                                      ? client.name
                                      : '${client.name} - ${client.phone}',
                                ),
                              ),
                            ),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _selectedClientId = value;
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _openClients,
                    tooltip: 'إضافة عميل',
                    icon: const Icon(Icons.person_add),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              TextFormField(
                controller: _quantityController,
                keyboardType: TextInputType.number,
                decoration: _decoration('عدد الوحدات'),
                validator: (value) {
                  final number = int.tryParse(value?.trim() ?? '');
                  if (number == null || number <= 0) {
                    return 'أدخل عدد وحدات صحيح';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 12),

              TextFormField(
                controller: _priceController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: _decoration('سعر الوحدة'),
                validator: (value) {
                  final number = double.tryParse(value?.trim() ?? '');
                  if (number == null || number < 0) {
                    return 'أدخل سعرًا صحيحًا';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 12),

              Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'الإجمالي',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Text(
                        _formatNumber(_total),
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),

              InkWell(
                onTap: _pickDate,
                borderRadius: BorderRadius.circular(4),
                child: InputDecorator(
                  decoration: _decoration('التاريخ'),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(_formatDate(_selectedDate)),
                      ),
                      const Icon(Icons.calendar_month),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),

              DropdownButtonFormField<String>(
                initialValue: _clientPaymentStatus,
                decoration: _decoration('حالة دفع العميل'),
                items: const [
                  DropdownMenuItem(
                    value: 'paid',
                    child: Text('مدفوع'),
                  ),
                  DropdownMenuItem(
                    value: 'unpaid',
                    child: Text('آجل'),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _clientPaymentStatus = value;
                    });
                  }
                },
              ),

              const SizedBox(height: 12),

              DropdownButtonFormField<String>(
                initialValue: _supplierPaymentStatus,
                decoration: _decoration('حالة دفع المورد'),
                items: const [
                  DropdownMenuItem(
                    value: 'paid',
                    child: Text('مدفوع'),
                  ),
                  DropdownMenuItem(
                    value: 'unpaid',
                    child: Text('آجل'),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _supplierPaymentStatus = value;
                    });
                  }
                },
              ),

              const SizedBox(height: 12),

              InputDecorator(
                decoration: _decoration('المستخدم'),
                child: Row(
                  children: [
                    const Icon(Icons.person),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(userName),
                    ),
                    const Icon(Icons.lock_outline, size: 18),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              TextFormField(
                controller: _notesController,
                maxLines: 2,
                decoration: _decoration('ملاحظات (اختياري)'),
              ),

              const SizedBox(height: 16),

              FilledButton.icon(
                onPressed: _saving ? null : _saveSale,
                icon: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.receipt_long),
                label: Text(
                  _saving
                      ? 'جارٍ حفظ المبيعة...'
                      : 'حفظ المبيعة وإصدار الإيصال',
                ),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSalesList() {
    if (_sales.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Center(
            child: Text('لا توجد مبيعات حتى الآن'),
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _sectionTitle('آخر المبيعات', Icons.history),
            ..._sales.take(20).map(
                  (sale) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const CircleAvatar(
                      child: Icon(Icons.receipt_long),
                    ),
                    title: Text(
                      '${_clientName(sale.clientId)} — '
                      '${_formatNumber(sale.totalAmount)}',
                    ),
                    subtitle: Text(
                      '${_supplierName(sale.supplierId)} • '
                      '${sale.saleDate} • '
                      'العميل: ${_paymentLabel(sale.clientPaymentStatus ?? sale.paymentStatus)} • '
                      'المورد: ${_paymentLabel(sale.supplierPaymentStatus)}',
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}
