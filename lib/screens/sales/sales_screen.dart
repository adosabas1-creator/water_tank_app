
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../models/client.dart';
import '../../models/driver.dart';
import '../../models/sale.dart';
import '../../models/supplier.dart';
import '../../services/client_service.dart';
import '../../services/driver_service.dart';
import '../../services/sale_service.dart';
import '../../services/supplier_service.dart';

class SalesScreen extends StatefulWidget {
  const SalesScreen({super.key});

  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> {
  final SaleService _saleService = SaleService();
  final ClientService _clientService = ClientService();
  final SupplierService _supplierService = SupplierService();
  final DriverService _driverService = DriverService();

  late Future<List<Sale>> _futureSales;

  List<Client> _clients = [];
  List<Supplier> _suppliers = [];
  List<Driver> _drivers = [];

  @override
  void initState() {
    super.initState();
    _futureSales = _loadData();
  }

  Future<List<Sale>> _loadData() async {
    final results = await Future.wait([
      _saleService.getAllSales(),
      _clientService.getAllClients(),
      _supplierService.getAllSuppliers(),
      _driverService.getAllDrivers(),
    ]);

    _clients = results[1] as List<Client>;
    _suppliers = results[2] as List<Supplier>;
    _drivers = results[3] as List<Driver>;

    return results[0] as List<Sale>;
  }

  Future<void> _refresh() async {
    setState(() {
      _futureSales = _loadData();
    });
    await _futureSales;
  }

  Client? _clientById(int? id) {
    if (id == null) return null;
    for (final item in _clients) {
      if (item.id == id) return item;
    }
    return null;
  }

  Supplier? _supplierById(int id) {
    for (final item in _suppliers) {
      if (item.id == id) return item;
    }
    return null;
  }

  Driver? _driverById(int? id) {
    if (id == null) return null;
    for (final item in _drivers) {
      if (item.id == id) return item;
    }
    return null;
  }

  String _clientName(int? id) {
    final client = _clientById(id);
    if (client == null) return 'غير محدد';
    return client.name;
  }

  String _clientPhone(int? id) {
    final client = _clientById(id);
    return client?.phone ?? '';
  }

  String _supplierName(int id) {
    return _supplierById(id)?.name ?? 'غير محدد';
  }

  String _driverName(int? id) {
    final driver = _driverById(id);
    if (driver == null) return 'غير محدد';
    return driver.name;
  }

  Future<void> _showSaleDialog({Sale? sale}) async {
    final formKey = GlobalKey<FormState>();

    final saleNumberController =
        TextEditingController(text: sale?.saleNumber ?? '');
    final tankIdController =
        TextEditingController(text: sale?.tankId?.toString() ?? '');
    final unitsController =
        TextEditingController(text: sale?.units.toString() ?? '1');
    final salePriceController =
        TextEditingController(text: sale?.salePrice.toString() ?? '');
    final costAmountController =
        TextEditingController(text: sale?.costAmount.toString() ?? '0');
    final notesController =
        TextEditingController(text: sale?.notes ?? '');

    int? selectedClientId = sale?.clientId;
    int? selectedDriverId = sale?.driverId;
    int? selectedSupplierId = sale?.supplierId;

    String selectedPaymentStatus = sale?.paymentStatus ?? 'غير مدفوع';
    DateTime selectedDate =
        DateTime.tryParse(sale?.saleDate ?? '') ?? DateTime.now();

    const currentUserId = 1;

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(
                sale == null ? 'إضافة عملية بيع' : 'تعديل عملية بيع',
              ),
              content: SizedBox(
                width: 500,
                child: SingleChildScrollView(
                  child: Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextFormField(
                          controller: saleNumberController,
                          decoration: const InputDecoration(
                            labelText: 'رقم البيع',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),

                        DropdownButtonFormField<Client>(
                          initialValue: _clientById(selectedClientId),
                          decoration: const InputDecoration(
                            labelText: 'العميل',
                            border: OutlineInputBorder(),
                          ),
                          items: _clients.map((client) {
                            return DropdownMenuItem<Client>(
                              value: client,
                              child: Text(
                                client.phone == null || client.phone!.isEmpty
                                    ? client.name
                                    : '${client.name} - ${client.phone}',
                              ),
                            );
                          }).toList(),
                          onChanged: (client) {
                            setDialogState(() {
                              selectedClientId = client?.id;
                            });
                          },
                          validator: (value) {
                            if (value == null) {
                              return 'اختر العميل';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),

                        DropdownButtonFormField<Supplier>(
                          initialValue: selectedSupplierId == null
                              ? null
                              : _supplierById(selectedSupplierId!),
                          decoration: const InputDecoration(
                            labelText: 'المورد',
                            border: OutlineInputBorder(),
                          ),
                          items: _suppliers.map((supplier) {
                            return DropdownMenuItem<Supplier>(
                              value: supplier,
                              child: Text(
                                supplier.phone == null ||
                                        supplier.phone!.isEmpty
                                    ? supplier.name
                                    : '${supplier.name} - ${supplier.phone}',
                              ),
                            );
                          }).toList(),
                          onChanged: (supplier) {
                            setDialogState(() {
                              selectedSupplierId = supplier?.id;
                            });
                          },
                          validator: (value) {
                            if (value == null) {
                              return 'اختر المورد';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),

                        DropdownButtonFormField<Driver>(
                          initialValue: _driverById(selectedDriverId),
                          decoration: const InputDecoration(
                            labelText: 'السائق',
                            border: OutlineInputBorder(),
                          ),
                          items: _drivers.map((driver) {
                            return DropdownMenuItem<Driver>(
                              value: driver,
                              child: Text(driver.name),
                            );
                          }).toList(),
                          onChanged: (driver) {
                            setDialogState(() {
                              selectedDriverId = driver?.id;
                            });
                          },
                        ),
                        const SizedBox(height: 12),

                        TextFormField(
                          controller: tankIdController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'رقم الصهريج',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),

                        TextFormField(
                          controller: unitsController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'عدد الوحدات',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) {
                            final number = int.tryParse(value ?? '');
                            if (number == null || number <= 0) {
                              return 'أدخل عدد وحدات صحيح';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),

                        TextFormField(
                          controller: salePriceController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'سعر البيع',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) {
                            if (double.tryParse(value ?? '') == null) {
                              return 'أدخل سعرًا صحيحًا';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),

                        TextFormField(
                          controller: costAmountController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'التكلفة',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) {
                            if (double.tryParse(value ?? '') == null) {
                              return 'أدخل تكلفة صحيحة';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),

                        DropdownButtonFormField<String>(
                          initialValue: selectedPaymentStatus,
                          decoration: const InputDecoration(
                            labelText: 'حالة الدفع',
                            border: OutlineInputBorder(),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'غير مدفوع',
                              child: Text('غير مدفوع'),
                            ),
                            DropdownMenuItem(
                              value: 'مدفوع جزئياً',
                              child: Text('مدفوع جزئياً'),
                            ),
                            DropdownMenuItem(
                              value: 'مدفوع',
                              child: Text('مدفوع'),
                            ),
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              setDialogState(() {
                                selectedPaymentStatus = value;
                              });
                            }
                          },
                        ),
                        const SizedBox(height: 12),

                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('تاريخ البيع'),
                          subtitle: Text(
                            '${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}',
                          ),
                          trailing: const Icon(Icons.calendar_month),
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: selectedDate,
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2100),
                            );

                            if (picked != null) {
                              setDialogState(() {
                                selectedDate = picked;
                              });
                            }
                          },
                        ),

                        TextFormField(
                          controller: notesController,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            labelText: 'ملاحظات',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('إلغاء'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (!formKey.currentState!.validate()) {
                      return;
                    }

                    if (selectedSupplierId == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('يجب اختيار المورد'),
                        ),
                      );
                      return;
                    }

                    final units = int.parse(unitsController.text.trim());
                    final salePrice =
                        double.parse(salePriceController.text.trim());
                    final costAmount =
                        double.parse(costAmountController.text.trim());
                    final totalAmount = units * salePrice;
                    final profitAmount = totalAmount - costAmount;

                    final newSale = Sale(
                      id: sale?.id,
                      syncId: sale?.syncId ?? const Uuid().v4(),
                      saleNumber: saleNumberController.text.trim().isEmpty
                          ? null
                          : saleNumberController.text.trim(),
                      clientId: selectedClientId,
                      tankId: int.tryParse(tankIdController.text.trim()),
                      driverId: selectedDriverId,
                      supplierId: selectedSupplierId!,
                      units: units,
                      salePrice: salePrice,
                      totalAmount: totalAmount,
                      costAmount: costAmount,
                      profitAmount: profitAmount,
                      saleDate:
                          '${selectedDate.year.toString().padLeft(4, '0')}-'
                          '${selectedDate.month.toString().padLeft(2, '0')}-'
                          '${selectedDate.day.toString().padLeft(2, '0')}',
                      paymentStatus: selectedPaymentStatus,
                      notes: notesController.text.trim().isEmpty
                          ? null
                          : notesController.text.trim(),
                      createdBy: sale?.createdBy ?? currentUserId,
                      createdAt:
                          sale?.createdAt ?? DateTime.now().toIso8601String(),
                      updatedAt: DateTime.now().toIso8601String(),
                      isDeleted: false,
                      isSynced: false,
                    );

                    try {
                      if (sale == null) {
                        await _saleService.addSale(newSale);
                      } else {
                        await _saleService.updateSale(newSale);
                      }

                      if (dialogContext.mounted) {
                        Navigator.pop(dialogContext);
                      }

                      await _refresh();

                      if (mounted) {
                        ScaffoldMessenger.of(this.context).showSnackBar(
                          SnackBar(
                            content: Text(
                              sale == null
                                  ? 'تمت إضافة البيع بنجاح'
                                  : 'تم تعديل البيع بنجاح',
                            ),
                          ),
                        );
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(this.context).showSnackBar(
                          SnackBar(
                            content: Text('حدث خطأ: $e'),
                          ),
                        );
                      }
                    }
                  },
                  child: Text(sale == null ? 'حفظ' : 'تحديث'),
                ),
              ],
            );
          },
        );
      },
    );

    saleNumberController.dispose();
    tankIdController.dispose();
    unitsController.dispose();
    salePriceController.dispose();
    costAmountController.dispose();
    notesController.dispose();
  }

  Future<void> _deleteSale(Sale sale) async {
    if (sale.id == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('حذف البيع'),
          content: const Text('هل أنت متأكد من حذف عملية البيع؟'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('حذف'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      await _saleService.deleteSale(sale.id!);
      await _refresh();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم حذف البيع')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حدث خطأ أثناء الحذف: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('المبيعات'),
        actions: [
          IconButton(
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
            tooltip: 'تحديث',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showSaleDialog(),
        child: const Icon(Icons.add),
      ),
      body: FutureBuilder<List<Sale>>(
        future: _futureSales,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  'حدث خطأ أثناء تحميل المبيعات:\n${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final sales = snapshot.data ?? [];

          if (sales.isEmpty) {
            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                children: const [
                  SizedBox(height: 180),
                  Center(
                    child: Text('لا توجد عمليات بيع'),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: sales.length,
              itemBuilder: (context, index) {
                final sale = sales[index];
                final clientName = _clientName(sale.clientId);
                final clientPhone = _clientPhone(sale.clientId);
                final supplierName = _supplierName(sale.supplierId);
                final driverName = _driverName(sale.driverId);

                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    leading: CircleAvatar(
                      child: Text('${sale.units}'),
                    ),
                    title: Text(
                      sale.saleNumber == null ||
                              sale.saleNumber!.trim().isEmpty
                          ? 'بيع رقم ${sale.id ?? ''}'
                          : 'بيع ${sale.saleNumber}',
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('العميل: $clientName'),
                          if (clientPhone.isNotEmpty)
                            Text('هاتف العميل: $clientPhone'),
                          Text('المورد: $supplierName'),
                          Text('السائق: $driverName'),
                          Text('الصهريج: ${sale.tankId ?? 'غير محدد'}'),
                          Text(
                            'الإجمالي: ${sale.totalAmount.toStringAsFixed(2)}',
                          ),
                          Text(
                            'الربح: ${sale.profitAmount.toStringAsFixed(2)}',
                          ),
                          Text('حالة الدفع: ${sale.paymentStatus}'),
                          Text('التاريخ: ${sale.saleDate}'),
                        ],
                      ),
                    ),
                    isThreeLine: true,
                    trailing: PopupMenuButton<String>(
                      onSelected: (value) {
                        if (value == 'edit') {
                          _showSaleDialog(sale: sale);
                        } else if (value == 'delete') {
                          _deleteSale(sale);
                        }
                      },
                      itemBuilder: (context) => const [
                        PopupMenuItem(
                          value: 'edit',
                          child: Text('تعديل'),
                        ),
                        PopupMenuItem(
                          value: 'delete',
                          child: Text('حذف'),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
