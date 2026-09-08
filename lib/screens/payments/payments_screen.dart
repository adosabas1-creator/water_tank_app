import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/payment.dart';
import '../../services/payment_service.dart';
import '../../core/auth/user_provider.dart';

class PaymentsScreen extends StatefulWidget {
  const PaymentsScreen({super.key});

  @override
  State<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends State<PaymentsScreen> {
  final PaymentService _service = PaymentService();

  late Future<List<Payment>> _future;

  @override
  void initState() {
    super.initState();
    _future = _service.getAllPayments();
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

  Future<void> _showPaymentDialog({Payment? payment}) async {
    final formKey = GlobalKey<FormState>();

    final referenceController = TextEditingController(
      text: payment?.referenceId.toString() ?? '',
    );

    final amountController = TextEditingController(
      text: payment?.amount.toString() ?? '',
    );

    final notesController = TextEditingController(
      text: payment?.notes ?? '',
    );

    String paymentType = payment?.paymentType ?? 'client_payment';

    DateTime selectedDate = payment != null
        ? DateTime.tryParse(payment.paymentDate) ?? DateTime.now()
        : DateTime.now();

    bool saving = false;

    final userProvider = context.read<UserProvider>();

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
                final referenceId =
                    int.parse(referenceController.text.trim());

                final amount =
                    double.parse(amountController.text.trim());

                final now = DateTime.now().toIso8601String();

                if (payment == null) {
                  final newPayment = Payment(
                    paymentType: paymentType,
                    referenceId: referenceId,
                    amount: amount,
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
                    id: payment.id,
                    paymentType: paymentType,
                    referenceId: referenceId,
                    amount: amount,
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
                        onChanged: saving
                            ? null
                            : (value) {
                                if (value == null) return;

                                setDialogState(() {
                                  paymentType = value;
                                });
                              },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: referenceController,
                        keyboardType: TextInputType.number,
                        enabled: !saving,
                        decoration: const InputDecoration(
                          labelText: 'رقم العميل / المورد',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          final number =
                              int.tryParse(value?.trim() ?? '');

                          if (number == null || number <= 0) {
                            return 'أدخل رقمًا صحيحًا';
                          }

                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: amountController,
                        keyboardType:
                            const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        enabled: !saving,
                        decoration: const InputDecoration(
                          labelText: 'المبلغ',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          final amount =
                              double.tryParse(value?.trim() ?? '');

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
                  onPressed: saving
                      ? null
                      : () => Navigator.of(dialogContext).pop(),
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

    referenceController.dispose();
    amountController.dispose();
    notesController.dispose();
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
                      '${_paymentTypeText(payment.paymentType)} #${payment.id}',
                    ),
                    subtitle: Text(
                      'المرجع: ${payment.referenceId}\n'
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
