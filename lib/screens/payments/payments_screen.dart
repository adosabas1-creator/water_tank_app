import 'package:uuid/uuid.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/payment.dart';
import '../../models/client.dart';
import '../../models/supplier.dart';
import '../../services/payment_service.dart';
import '../../services/client_service.dart';
import '../../services/supplier_service.dart';
import '../../core/auth/user_provider.dart';

class PaymentsScreen extends StatefulWidget {
  final String? initialPaymentType;
  final int? initialReferenceId;

  const PaymentsScreen({
    super.key,
    this.initialPaymentType,
    this.initialReferenceId,
  });

  @override
  State<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends State<PaymentsScreen> {
  final PaymentService _service = PaymentService();
  final ClientService _clientService = ClientService();
  final SupplierService _supplierService = SupplierService();

  late Future<List<Payment>> _future;
  Map<int, String> _clientNames = {};
  Map<int, String> _supplierNames = {};

  Future<void> _loadReferenceNames() async {
    final clients = await _clientService.getAllClients();
    final suppliers = await _supplierService.getAllSuppliers();

    if (!mounted) return;

    setState(() {
      _clientNames = {
        for (final client in clients)
          if (client.id != null) client.id!: client.name,
      };
      _supplierNames = {
        for (final supplier in suppliers)
          if (supplier.id != null) supplier.id!: supplier.name,
      };
    });
  }

  String _referenceName(Payment payment) {
    if (payment.paymentType == 'client_payment') {
      return _clientNames[payment.referenceId] ?? 'عميل غير معروف';
    }
    return _supplierNames[payment.referenceId] ?? 'مورد غير معروف';
  }

  @override
  void initState() {
    super.initState();
    _future = _service.getAllPayments();
    _loadReferenceNames();

    if (widget.initialPaymentType != null &&
        widget.initialReferenceId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _showPaymentDialog(
            initialPaymentType: widget.initialPaymentType,
            initialReferenceId: widget.initialReferenceId,
          );
        }
      });
    }
  }

  void _refresh() {
    setState(() {
      _future = _service.getAllPayments();
    });
  }

  String _paymentTypeText(String type) {
    if (type == 'client_payment') {
      return 'دفعة عميل';
    }
    return 'دفعة مورد';
  }

  Future<void> _showPaymentDialog({
    Payment? payment,
    String? initialPaymentType,
    int? initialReferenceId,
  }) async {
    final formKey = GlobalKey<FormState>();
    final userProvider = context.read<UserProvider>();

    final List<Client> clients = await _clientService.getAllClients();
    final List<Supplier> suppliers = await _supplierService.getAllSuppliers();

    String paymentType =
        payment?.paymentType ?? initialPaymentType ?? 'client_payment';

    int? selectedReferenceId = payment?.referenceId ?? initialReferenceId;
    String? selectedReferenceName;
    final referenceNameController = TextEditingController();

    void updateSelectedReferenceName() {
      selectedReferenceName = null;

      if (paymentType == 'client_payment') {
        for (final client in clients) {
          if (client.id == selectedReferenceId) {
            selectedReferenceName = client.name;
            break;
          }
        }
      } else {
        for (final supplier in suppliers) {
          if (supplier.id == selectedReferenceId) {
            selectedReferenceName = supplier.name;
            break;
          }
        }
      }

      referenceNameController.text = selectedReferenceName ?? '';
    }

    updateSelectedReferenceName();

    final amountController = TextEditingController(
      text: payment?.amount.toString() ?? '',
    );

    final notesController = TextEditingController(
      text: payment?.notes ?? '',
    );

    final bool accountLocked = payment == null &&
        initialPaymentType != null &&
        initialReferenceId != null;
    String paymentMethod = payment?.paymentMethod ?? 'cash';
    final referenceNumberController =
        TextEditingController(text: payment?.referenceNumber ?? '');

    DateTime selectedDate = payment != null
        ? DateTime.tryParse(payment.paymentDate) ?? DateTime.now()
        : DateTime.now();

    bool saving = false;

    int? createdBy;

    // نحاول الحصول على معرف المستخدم الحالي بطريقة آمنة.
    // إذا كان المستخدم الحالي غير متوفر، نستخدم 0 كقيمة افتراضية.
    try {
      final dynamic currentUser = userProvider.currentUser;
      createdBy = currentUser?.id as int?;
    } catch (_) {
      createdBy = null;
    }

    createdBy ??= payment?.createdBy ?? 0;

    if (!mounted) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> save() async {
              if (!formKey.currentState!.validate()) {
                return;
              }

              setDialogState(() {
                saving = true;
              });

              try {
                final referenceId = selectedReferenceId;

                if (referenceId == null || selectedReferenceName == null) {
                  setDialogState(() {
                    saving = false;
                  });
                  return;
                }

                final amount = double.parse(amountController.text.trim());

                final now = DateTime.now().toIso8601String();

                if (payment == null) {
                  final syncId = const Uuid().v4();

                  final voucherPrefix = paymentType == 'client_payment' ? 'RC' : 'PV';

                  final paymentKey = '$voucherPrefix-${DateTime.now().millisecondsSinceEpoch}';


                  final newPayment = Payment(

                    syncId: syncId,

                    paymentKey: paymentKey,
                    paymentType: paymentType,
                    referenceId: referenceId,
                    amount: amount,
                    paymentMethod: paymentMethod,
                    referenceNumber:
                        referenceNumberController.text.trim().isEmpty
                            ? null
                            : referenceNumberController.text.trim(),
                    paymentDate: selectedDate.toIso8601String(),
                    notes: notesController.text.trim().isEmpty
                        ? null
                        : notesController.text.trim(),
                    createdBy: createdBy!,
                    createdAt: now,
                    updatedAt: now,
                    isDeleted: false,
                    isSynced: false,
                  );

                  await _service.addPayment(newPayment);
                } else {
                  final updatedPayment = Payment(
                    syncId: payment.syncId,
                    id: payment.id,
                    paymentKey: payment.paymentKey.trim().isEmpty
                        ? payment.syncId
                        : payment.paymentKey,
                    paymentType: paymentType,
                    referenceId: referenceId,
                    amount: amount,
                    paymentMethod: paymentMethod,
                    referenceNumber:
                        referenceNumberController.text.trim().isEmpty
                            ? null
                            : referenceNumberController.text.trim(),
                    paymentDate: selectedDate.toIso8601String(),
                    notes: notesController.text.trim().isEmpty
                        ? null
                        : notesController.text.trim(),
                    createdBy: payment.createdBy,
                    createdAt: payment.createdAt,
                    updatedAt: now,
                    isDeleted: payment.isDeleted,
                    isSynced: false,
                  );

                  await _service.updatePayment(updatedPayment);
                }

                if (!dialogContext.mounted) return;

                Navigator.of(dialogContext).pop();

                if (!mounted) return;

                _refresh();

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      payment == null
                          ? 'تمت إضافة الدفعة بنجاح'
                          : 'تم تعديل الدفعة بنجاح',
                    ),
                  ),
                );
              } catch (e) {
                if (!dialogContext.mounted) return;

                setDialogState(() {
                  saving = false;
                });

                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  SnackBar(
                    content: Text('حدث خطأ: $e'),
                  ),
                );
              }
            }

            return AlertDialog(
              title: Text(
                payment == null ? 'إضافة دفعة' : 'تعديل الدفعة',
              ),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DropdownButtonFormField<String>(
                        initialValue: paymentType,
                        decoration: const InputDecoration(
                          labelText: 'نوع الدفع',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'client_payment',
                            child: Text('دفعة عميل'),
                          ),
                          DropdownMenuItem(
                            value: 'supplier_payment',
                            child: Text('دفعة مورد'),
                          ),
                        ],
                        onChanged: saving || accountLocked
                            ? null
                            : (value) {
                                if (value != null) {
                                  setDialogState(() {
                                    paymentType = value;
                                    selectedReferenceId = null;
                                    selectedReferenceName = null;
                                    referenceNameController.clear();
                                  });
                                }
                              },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: referenceNameController,
                        readOnly: true,
                        enabled: !saving && !accountLocked,
                        decoration: InputDecoration(
                          labelText: paymentType == 'client_payment'
                              ? 'العميل'
                              : 'المورد',
                          hintText: paymentType == 'client_payment'
                              ? 'اضغط لاختيار العميل بالاسم'
                              : 'اضغط لاختيار المورد بالاسم',
                          border: const OutlineInputBorder(),
                          suffixIcon: const Icon(Icons.search),
                        ),
                        onTap: saving || accountLocked
                            ? null
                            : () async {
                                final List<Map<String, dynamic>> accounts =
                                    paymentType == 'client_payment'
                                        ? clients
                                            .map((client) => {
                                                  'id': client.id,
                                                  'name': client.name,
                                                })
                                            .toList()
                                        : suppliers
                                            .map((supplier) => {
                                                  'id': supplier.id,
                                                  'name': supplier.name,
                                                })
                                            .toList();

                                final searchController =
                                    TextEditingController();

                                final pickedId = await showDialog<int>(
                                  context: context,
                                  builder: (pickerContext) {
                                    return StatefulBuilder(
                                      builder:
                                          (pickerContext, setPickerState) {
                                        final query = searchController.text
                                            .trim()
                                            .toLowerCase();

                                        final filtered =
                                            accounts.where((account) {
                                          return account['name']
                                              .toString()
                                              .toLowerCase()
                                              .contains(query);
                                        }).toList();

                                        return AlertDialog(
                                          title: Text(
                                            paymentType == 'client_payment'
                                                ? 'اختيار العميل'
                                                : 'اختيار المورد',
                                          ),
                                          content: SizedBox(
                                            width: double.maxFinite,
                                            height: 360,
                                            child: Column(
                                              children: [
                                                TextField(
                                                  controller:
                                                      searchController,
                                                  autofocus: true,
                                                  decoration:
                                                      const InputDecoration(
                                                    labelText: 'بحث بالاسم',
                                                    prefixIcon:
                                                        Icon(Icons.search),
                                                    border:
                                                        OutlineInputBorder(),
                                                  ),
                                                  onChanged: (_) =>
                                                      setPickerState(() {}),
                                                ),
                                                const SizedBox(height: 12),
                                                Expanded(
                                                  child: filtered.isEmpty
                                                      ? const Center(
                                                          child: Text(
                                                            'لا توجد نتائج',
                                                          ),
                                                        )
                                                      : ListView.builder(
                                                          itemCount:
                                                              filtered.length,
                                                          itemBuilder:
                                                              (context, index) {
                                                            final account =
                                                                filtered[index];

                                                            return ListTile(
                                                              title: Text(
                                                                account['name'],
                                                              ),
                                                              onTap: () =>
                                                                  Navigator.of(
                                                                pickerContext,
                                                              ).pop(
                                                                account['id'],
                                                              ),
                                                            );
                                                          },
                                                        ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        );
                                      },
                                    );
                                  },
                                );

                                searchController.dispose();

                                if (pickedId != null) {
                                  setDialogState(() {
                                    selectedReferenceId = pickedId;
                                    updateSelectedReferenceName();
                                  });
                                }
                              },
                        validator: (_) {
                          if (selectedReferenceId == null ||
                              selectedReferenceName == null) {
                            return paymentType == 'client_payment'
                                ? 'اختر العميل'
                                : 'اختر المورد';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: paymentMethod,
                        decoration: const InputDecoration(
                          labelText: 'طريقة الدفع',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'cash', child: Text('نقدي')),
                          DropdownMenuItem(
                              value: 'transfer', child: Text('حوالة')),
                          DropdownMenuItem(
                              value: 'bank_transfer',
                              child: Text('تحويل بنكي')),
                          DropdownMenuItem(value: 'other', child: Text('أخرى')),
                        ],
                        onChanged: saving
                            ? null
                            : (value) {
                                if (value != null) {
                                  setDialogState(() {
                                    paymentMethod = value;
                                  });
                                }
                              },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: referenceNumberController,
                        enabled: saving == false &&
                            (paymentMethod == 'transfer' ||
                                paymentMethod == 'bank_transfer'),
                        decoration: const InputDecoration(
                            labelText: 'رقم الحوالة / التحويل',
                            border: OutlineInputBorder()),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: amountController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        enabled: !saving,
                        decoration: const InputDecoration(
                          labelText: 'المبلغ',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          final amount = double.tryParse(value?.trim() ?? '');

                          if (amount == null || amount <= 0) {
                            return 'أدخل مبلغًا صحيحًا أكبر من صفر';
                          }

                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      InkWell(
                        onTap: saving
                            ? null
                            : () async {
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
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'تاريخ الدفع',
                            border: OutlineInputBorder(),
                          ),
                          child: Text(
                            '${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}',
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: notesController,
                        maxLines: 3,
                        enabled: !saving,
                        decoration: const InputDecoration(
                          labelText: 'ملاحظات',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed:
                      saving ? null : () => Navigator.of(dialogContext).pop(),
                  child: const Text('إلغاء'),
                ),
                FilledButton(
                  onPressed: saving ? null : save,
                  child: saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          payment == null ? 'إضافة' : 'حفظ',
                        ),
                ),
              ],
            );
          },
        );
      },
    );

    referenceNameController.dispose();
    amountController.dispose();
    notesController.dispose();
    referenceNumberController.dispose();
  }

  Future<void> _deletePayment(Payment payment) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('حذف الدفعة'),
          content: Text(
            'هل أنت متأكد من حذف الدفعة رقم ${payment.id}؟',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('حذف'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      await _service.deletePayment(payment.id!);

      if (!mounted) return;

      _refresh();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم حذف الدفعة بنجاح'),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('حدث خطأ أثناء الحذف: $e'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('المدفوعات'),
        actions: [
          IconButton(
            onPressed: _refresh,
            tooltip: 'تحديث',
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: FutureBuilder<List<Payment>>(
        future: _future,
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
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 48,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'حدث خطأ أثناء تحميل المدفوعات\n${snapshot.error}',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: _refresh,
                      icon: const Icon(Icons.refresh),
                      label: const Text('إعادة المحاولة'),
                    ),
                  ],
                ),
              ),
            );
          }

          final payments = snapshot.data ?? [];

          if (payments.isEmpty) {
            return const Center(
              child: Text('لا توجد مدفوعات'),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              _refresh();
              await _future;
            },
            child: ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: payments.length,
              itemBuilder: (context, index) {
                final payment = payments[index];

                return Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      child: Icon(
                        payment.paymentType == 'client_payment'
                            ? Icons.person
                            : Icons.business,
                      ),
                    ),
                    title: Text(
                      '${_paymentTypeText(payment.paymentType)} ${payment.paymentKey.trim().isEmpty ? payment.syncId : payment.paymentKey}',
                    ),
                    subtitle: Text(
                      'الاسم: ${_referenceName(payment)}\n'
                      'المبلغ: ${payment.amount.toStringAsFixed(2)}\n'
                      'التاريخ: ${payment.paymentDate.split('T').first}'
                      '${payment.notes == null || payment.notes!.isEmpty ? '' : '\nملاحظات: ${payment.notes}'}',
                    ),
                    isThreeLine: true,
                    trailing: PopupMenuButton<String>(
                      onSelected: (value) {
                        if (value == 'edit') {
                          _showPaymentDialog(payment: payment);
                        } else if (value == 'delete') {
                          _deletePayment(payment);
                        }
                      },
                      itemBuilder: (context) => const [
                        PopupMenuItem(
                          value: 'edit',
                          child: ListTile(
                            leading: Icon(Icons.edit),
                            title: Text('تعديل'),
                          ),
                        ),
                        PopupMenuItem(
                          value: 'delete',
                          child: ListTile(
                            leading: Icon(Icons.delete),
                            title: Text('حذف'),
                          ),
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showPaymentDialog(),
        icon: const Icon(Icons.add),
        label: const Text('إضافة دفعة'),
      ),
    );
  }
}
