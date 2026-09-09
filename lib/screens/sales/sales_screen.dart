import 'package:uuid/uuid.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/sale.dart';
import '../../services/sale_service.dart';
import '../../core/auth/user_provider.dart';
import '../../core/auth/auth_service.dart';
import '../../models/user.dart';
import '../../models/driver.dart';
import '../../services/driver_service.dart';

class SalesScreen extends StatefulWidget {
  const SalesScreen({super.key});

  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> {
  final SaleService _service = SaleService();
  final AuthService _authService = AuthService();
  final DriverService _driverService = DriverService();
  late Future<List<Sale>> _future;
  List<User> _users = [];
  List<Driver> _drivers = [];

  @override
  void initState() {
    super.initState();
    _future = _service.getAllSales();
    _loadNames();
  }

  Future<void> _loadNames() async {
    try {
      final users = await _authService.getAllUsers();
      final drivers = await _driverService.getAllDrivers();
      if (!mounted) return;
      setState(() {
        _users = users;
        _drivers = drivers;
      });
    } catch (_) {}
  }

  String _userName(int id) {
    final user = _users.where((u) => u.id == id).firstOrNull;
    return user?.fullName ?? 'مستخدم #$id';
  }

  String _driverName(int? id) {
    if (id == null) return 'غير محدد';
    final driver = _drivers.where((d) => d.id == id).firstOrNull;
    return driver?.name ?? 'سائق #$id';
  }

  void _refresh() {
    setState(() {
      _future = _service.getAllSales();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('المبيعات'),
      ),
      body: FutureBuilder<List<Sale>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Text('حدث خطأ: ${snapshot.error}'),
            );
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: Text('لا توجد مبيعات'),
            );
          }

          final sales = snapshot.data!;

          return ListView.builder(
            itemCount: sales.length,
            itemBuilder: (context, index) {
              final sale = sales[index];

              return Card(
                margin: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                child: ListTile(
                  leading: const CircleAvatar(
                    child: Icon(Icons.shopping_cart),
                  ),
                  title: Text(
                    sale.saleNumber?.isNotEmpty == true
                        ? 'فاتورة ${sale.saleNumber}'
                        : 'بيع #${sale.id}',
                  ),
                  subtitle: Text(
                    'العميل: ${sale.clientId} | '
                    'الصهريج: ${sale.tankId}\n'
                    'الوحدات: ${sale.units} | '
                    'الإجمالي: ${sale.totalAmount.toStringAsFixed(2)} ريال\n'
                    'سجّلها: ${_userName(sale.createdBy)}\n'
                    'السائق: ${_driverName(sale.driverId)}\n'
                    'التاريخ: ${sale.saleDate} | '
                    'الحالة: ${_paymentStatusText(sale.paymentStatus)}',
                  ),
                  isThreeLine: true,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: () => _showSaleDialog(sale),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete),
                        onPressed: () => _confirmDelete(sale),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showSaleDialog(null),
        child: const Icon(Icons.add),
      ),
    );
  }

  String _paymentStatusText(String status) {
    switch (status) {
      case 'paid':
        return 'مدفوع';
      case 'partial':
        return 'جزئي';
      case 'unpaid':
        return 'غير مدفوع';
      default:
        return status;
    }
  }

  void _showSaleDialog(Sale? existing) {
    final saleNumberCtrl = TextEditingController(
      text: existing?.saleNumber ?? '',
    );

    final clientIdCtrl = TextEditingController(
      text: existing?.clientId.toString() ?? '',
    );

    final tankIdCtrl = TextEditingController(
      text: existing?.tankId.toString() ?? '',
    );

    final driverIdCtrl = TextEditingController(
      text: existing?.driverId?.toString() ?? '',
    );

    final supplierIdCtrl = TextEditingController(
      text: existing?.supplierId?.toString() ?? '',
    );

    final unitsCtrl = TextEditingController(
      text: existing?.units.toString() ?? '',
    );

    final salePriceCtrl = TextEditingController(
      text: existing?.salePrice.toString() ?? '',
    );

    final costAmountCtrl = TextEditingController(
      text: existing?.costAmount.toString() ?? '',
    );

    final saleDateCtrl = TextEditingController(
      text: existing?.saleDate ??
          DateTime.now().toIso8601String().split('T').first,
    );

    final notesCtrl = TextEditingController(
      text: existing?.notes ?? '',
    );

    String paymentStatus = existing?.paymentStatus ?? 'unpaid';

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(
                existing == null ? 'إضافة مبيعة' : 'تعديل مبيعة',
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: saleNumberCtrl,
                      decoration: const InputDecoration(
                        labelText: 'رقم الفاتورة',
                        hintText: 'اختياري',
                      ),
                    ),
                    TextField(
                      controller: clientIdCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'رقم العميل *',
                      ),
                    ),
                    TextField(
                      controller: tankIdCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'رقم الصهريج *',
                      ),
                    ),
                    TextField(
                      controller: driverIdCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'رقم السائق',
                        hintText: 'اختياري',
                      ),
                    ),
                    TextField(
                      controller: supplierIdCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'رقم المورد',
                        hintText: 'اختياري',
                      ),
                    ),
                    TextField(
                      controller: unitsCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'عدد الوحدات *',
                      ),
                    ),
                    TextField(
                      controller: salePriceCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'سعر البيع للوحدة *',
                      ),
                    ),
                    TextField(
                      controller: costAmountCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'إجمالي التكلفة *',
                      ),
                    ),
                    TextField(
                      controller: saleDateCtrl,
                      decoration: const InputDecoration(
                        labelText: 'تاريخ البيع *',
                        hintText: 'YYYY-MM-DD',
                      ),
                    ),
                    DropdownButtonFormField<String>(
                      initialValue: paymentStatus,
                      decoration: const InputDecoration(
                        labelText: 'حالة الدفع',
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'paid',
                          child: Text('مدفوع'),
                        ),
                        DropdownMenuItem(
                          value: 'partial',
                          child: Text('جزئي'),
                        ),
                        DropdownMenuItem(
                          value: 'unpaid',
                          child: Text('غير مدفوع'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() {
                            paymentStatus = value;
                          });
                        }
                      },
                    ),
                    TextField(
                      controller: notesCtrl,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'ملاحظات',
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('إلغاء'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final clientId = int.tryParse(
                      clientIdCtrl.text.trim(),
                    );

                    final tankId = int.tryParse(
                      tankIdCtrl.text.trim(),
                    );

                    final driverText = driverIdCtrl.text.trim();
                    final driverId =
                        driverText.isEmpty ? null : int.tryParse(driverText);

                    final supplierText = supplierIdCtrl.text.trim();
                    final supplierId = supplierText.isEmpty
                        ? null
                        : int.tryParse(supplierText);

                    final units = int.tryParse(
                      unitsCtrl.text.trim(),
                    );

                    final salePrice = double.tryParse(
                      salePriceCtrl.text.trim(),
                    );

                    final costAmount = double.tryParse(
                      costAmountCtrl.text.trim(),
                    );

                    final saleDate = saleDateCtrl.text.trim();

                    if (clientId == null || clientId <= 0) {
                      _showDialogError(
                        dialogContext,
                        'يرجى إدخال رقم عميل صحيح',
                      );
                      return;
                    }

                    if (tankId == null || tankId <= 0) {
                      _showDialogError(
                        dialogContext,
                        'يرجى إدخال رقم صهريج صحيح',
                      );
                      return;
                    }

                    if (driverText.isNotEmpty && driverId == null) {
                      _showDialogError(
                        dialogContext,
                        'رقم السائق غير صحيح',
                      );
                      return;
                    }

                    if (supplierText.isNotEmpty && supplierId == null) {
                      _showDialogError(
                        dialogContext,
                        'رقم المورد غير صحيح',
                      );
                      return;
                    }

                    if (units == null || units <= 0) {
                      _showDialogError(
                        dialogContext,
                        'يرجى إدخال عدد وحدات صحيح أكبر من صفر',
                      );
                      return;
                    }

                    if (salePrice == null || salePrice < 0) {
                      _showDialogError(
                        dialogContext,
                        'يرجى إدخال سعر بيع صحيح',
                      );
                      return;
                    }

                    if (costAmount == null || costAmount < 0) {
                      _showDialogError(
                        dialogContext,
                        'يرجى إدخال إجمالي تكلفة صحيح',
                      );
                      return;
                    }

                    if (saleDate.isEmpty) {
                      _showDialogError(
                        dialogContext,
                        'يرجى إدخال تاريخ البيع',
                      );
                      return;
                    }

                    final user = context.read<UserProvider>().currentUser;

                    if (user?.id == null) {
                      _showDialogError(
                        dialogContext,
                        'لا يوجد مستخدم مسجل لإنشاء المبيعة',
                      );
                      return;
                    }

                    final totalAmount = units * salePrice;
                    final profitAmount = totalAmount - costAmount;
                    final now = DateTime.now().toIso8601String();

                    final sale = Sale(
                      id: existing?.id,
                      syncId: existing?.syncId ?? const Uuid().v4(),
                      saleNumber: saleNumberCtrl.text.trim().isEmpty
                          ? null
                          : saleNumberCtrl.text.trim(),
                      clientId: clientId,
                      tankId: tankId,
                      driverId: driverId,
                      supplierId: supplierId,
                      units: units,
                      salePrice: salePrice,
                      totalAmount: totalAmount,
                      costAmount: costAmount,
                      profitAmount: profitAmount,
                      saleDate: saleDate,
                      paymentStatus: paymentStatus,
                      notes: notesCtrl.text.trim().isEmpty
                          ? null
                          : notesCtrl.text.trim(),
                      createdBy: existing?.createdBy ?? user!.id!,
                      createdAt: existing?.createdAt ?? now,
                      updatedAt: now,
                    );

                    try {
                      if (existing == null) {
                        await _service.addSale(sale);
                      } else {
                        await _service.updateSale(sale);
                      }

                      if (!mounted || !dialogContext.mounted) return;

                      Navigator.pop(dialogContext);
                      _refresh();

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            existing == null
                                ? 'تمت إضافة المبيعة بنجاح'
                                : 'تم تعديل المبيعة بنجاح',
                          ),
                        ),
                      );
                    } catch (e) {
                      if (!dialogContext.mounted) return;

                      ScaffoldMessenger.of(dialogContext).showSnackBar(
                        SnackBar(
                          content: Text(
                            'حدث خطأ أثناء الحفظ: $e',
                          ),
                        ),
                      );
                    }
                  },
                  child: const Text('حفظ'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showDialogError(
    BuildContext dialogContext,
    String message,
  ) {
    ScaffoldMessenger.of(dialogContext).showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  void _confirmDelete(Sale sale) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('تأكيد الحذف'),
          content: Text(
            'هل تريد حذف المبيعة '
            '"${sale.saleNumber ?? sale.id}"؟',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  await _service.deleteSale(sale.id!);

                  if (!mounted || !dialogContext.mounted) return;

                  Navigator.pop(dialogContext);
                  _refresh();

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('تم حذف المبيعة بنجاح'),
                    ),
                  );
                } catch (e) {
                  if (!dialogContext.mounted) return;

                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    SnackBar(
                      content: Text(
                        'حدث خطأ أثناء الحذف: $e',
                      ),
                    ),
                  );
                }
              },
              child: const Text('حذف'),
            ),
          ],
        );
      },
    );
  }
}
