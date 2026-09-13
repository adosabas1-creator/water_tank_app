import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../core/auth/user_provider.dart';
import '../../models/purchase_invoice.dart';
import '../../models/purchase_item.dart';
import '../../models/supplier.dart';
import '../../services/purchase_service.dart';
import '../../services/supplier_service.dart';

class PurchasesScreen extends StatefulWidget {
  const PurchasesScreen({super.key});

  @override
  State<PurchasesScreen> createState() => _PurchasesScreenState();
}

class _PurchasesScreenState extends State<PurchasesScreen> {
  final SupplierService _supplierService = SupplierService();
  final PurchaseService _purchaseService = PurchaseService();

  final TextEditingController _quantityController =
      TextEditingController();
  final TextEditingController _priceController =
      TextEditingController();
  final TextEditingController _notesController =
      TextEditingController();

  List<Supplier> _suppliers = [];
  int? _selectedSupplierId;
  DateTime _purchaseDate = DateTime.now();
  String _paymentStatus = 'paid';
  bool _loading = true;
  bool _saving = false;

  int get _quantity {
    return int.tryParse(_quantityController.text.trim()) ?? 0;
  }

  double get _unitPrice {
    return double.tryParse(_priceController.text.trim()) ?? 0;
  }

  double get _total {
    return _quantity * _unitPrice;
  }

  @override
  void initState() {
    super.initState();
    _loadSuppliers();

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

  void _refreshTotal() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _loadSuppliers() async {
    try {
      final suppliers = await _supplierService.getAllSuppliers();

      if (!mounted) return;

      setState(() {
        _suppliers = suppliers;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تعذر تحميل الموردين: $e'),
        ),
      );
    }
  }

  Future<void> _selectDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _purchaseDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      helpText: 'اختر تاريخ الشراء',
    );

    if (selected != null) {
      setState(() {
        _purchaseDate = selected;
      });
    }
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
  }

  Future<void> _savePurchase() async {
    final user = context.read<UserProvider>().currentUser;

    if (user == null || user.id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يجب تسجيل الدخول أولًا'),
        ),
      );
      return;
    }

    if (_selectedSupplierId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('اختر المورد أولًا'),
        ),
      );
      return;
    }

    if (_quantity <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('أدخل كمية صحيحة'),
        ),
      );
      return;
    }

    if (_unitPrice <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('أدخل سعر شراء صحيح'),
        ),
      );
      return;
    }

    final now = DateTime.now();
    const invoicePrefix = 'PUR';
    const uuid = Uuid();
    final invoiceNumber =
        '$invoicePrefix-${now.year}${now.month.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')}-${now.millisecondsSinceEpoch}';
    final total = _total;


    final invoice = PurchaseInvoice(
      invoiceNumber: invoiceNumber,
      supplierId: _selectedSupplierId!,
      purchaseDate: _purchaseDate,
      totalAmount: total,
      paymentStatus: _paymentStatus,
      notes: _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
      createdBy: user.id!,
      createdAt: now,
      updatedAt: now,
      syncId: 'purchase_$invoiceNumber',
    );

    final item = PurchaseItem(
      purchaseInvoiceId: 0,
      itemType: 'tank',
      units: _quantity.toInt(),
      purchasePrice: _unitPrice,
      totalAmount: total,
      createdAt: now,
      updatedAt: now,
      syncId: 'purchase_item_${uuid.v4()}',
    );

    setState(() {
      _saving = true;
    });

    try {
      await _purchaseService.addPurchase(
        invoice: invoice,
        item: item,
      );

      if (!mounted) return;

      _quantityController.clear();
      _priceController.clear();
      _notesController.clear();

      setState(() {
        _saving = false;
        _selectedSupplierId = null;
        _paymentStatus = 'paid';
        _purchaseDate = DateTime.now();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم حفظ فاتورة الشراء بنجاح'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _saving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تعذر حفظ فاتورة الشراء: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('فاتورة شراء'),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DropdownButtonFormField<int>(
                    initialValue: _selectedSupplierId,
                    decoration: const InputDecoration(
                      labelText: 'المورد *',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.business),
                    ),
                    items: _suppliers
                        .map(
                          (supplier) => DropdownMenuItem<int>(
                            value: supplier.id,
                            child: Text(supplier.name),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedSupplierId = value;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _quantityController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: false,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'الكمية',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.inventory_2),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _priceController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'سعر الشراء للوحدة',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.price_change),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'الإجمالي',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '${_total.toStringAsFixed(2)} ريال',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: _paymentStatus,
                    decoration: const InputDecoration(
                      labelText: 'حالة السداد',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.payments),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'paid',
                        child: Text('نقدي'),
                      ),
                      DropdownMenuItem(
                        value: 'unpaid',
                        child: Text('آجل'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value == null) return;

                      setState(() {
                        _paymentStatus = value;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  InkWell(
                    onTap: _selectDate,
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'تاريخ الشراء',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.calendar_today),
                      ),
                      child: Text(_formatDate(_purchaseDate)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _notesController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'ملاحظات',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.notes),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: _saving ? null : _savePurchase,
                      icon: _saving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(Icons.save),
                      label: Text(
                        _saving ? 'جاري الحفظ...' : 'حفظ فاتورة الشراء',
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
