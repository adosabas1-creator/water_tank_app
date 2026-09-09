import 'package:uuid/uuid.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/filling_operation.dart';
import '../../services/filling_operation_service.dart';
import '../../core/auth/user_provider.dart';

class FillingScreen extends StatefulWidget {
  const FillingScreen({super.key});

  @override
  State<FillingScreen> createState() => _FillingScreenState();
}

class _FillingScreenState extends State<FillingScreen> {
  final FillingOperationService _service = FillingOperationService();
  late Future<List<FillingOperation>> _future;

  @override
  void initState() {
    super.initState();
    _future = _service.getAllOperations();
  }

  void _refresh() {
    setState(() {
      _future = _service.getAllOperations();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('عمليات التعبئة'),
      ),
      body: FutureBuilder<List<FillingOperation>>(
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
              child: Text('لا توجد عمليات تعبئة'),
            );
          }

          final operations = snapshot.data!;

          return ListView.builder(
            itemCount: operations.length,
            itemBuilder: (context, index) {
              final operation = operations[index];

              return Card(
                margin: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                child: ListTile(
                  leading: const CircleAvatar(
                    child: Icon(Icons.local_gas_station),
                  ),
                  title: Text(
                    operation.operationNumber?.isNotEmpty == true
                        ? 'عملية ${operation.operationNumber}'
                        : 'عملية تعبئة #${operation.id}',
                  ),
                  subtitle: Text(
                    'الصهريج: ${operation.tankId} | '
                    'المورد: ${operation.supplierId}\n'
                    'الوحدات: ${operation.units} | '
                    'سعر الشراء: ${operation.purchasePrice.toStringAsFixed(2)} ريال\n'
                    'التاريخ: ${operation.operationDate}',
                  ),
                  isThreeLine: true,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: () => _showOperationDialog(operation),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete),
                        onPressed: () => _confirmDelete(operation),
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
        onPressed: () => _showOperationDialog(null),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showOperationDialog(FillingOperation? existing) {
    final operationNumberCtrl = TextEditingController(
      text: existing?.operationNumber ?? '',
    );

    final tankIdCtrl = TextEditingController(
      text: existing?.tankId.toString() ?? '',
    );

    final supplierIdCtrl = TextEditingController(
      text: existing?.supplierId.toString() ?? '',
    );

    final unitsCtrl = TextEditingController(
      text: existing?.units.toString() ?? '',
    );

    final purchasePriceCtrl = TextEditingController(
      text: existing?.purchasePrice.toString() ?? '',
    );

    final operationDateCtrl = TextEditingController(
      text: existing?.operationDate ??
          DateTime.now().toIso8601String().split('T').first,
    );

    final employeeIdCtrl = TextEditingController(
      text: existing?.employeeId?.toString() ?? '',
    );

    final notesCtrl = TextEditingController(
      text: existing?.notes ?? '',
    );

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(
            existing == null ? 'إضافة عملية تعبئة' : 'تعديل عملية تعبئة',
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: operationNumberCtrl,
                  decoration: const InputDecoration(
                    labelText: 'رقم العملية',
                    hintText: 'اختياري',
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
                  controller: supplierIdCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'رقم المورد *',
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
                  controller: purchasePriceCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'سعر الشراء *',
                  ),
                ),
                TextField(
                  controller: operationDateCtrl,
                  decoration: const InputDecoration(
                    labelText: 'تاريخ العملية *',
                    hintText: 'YYYY-MM-DD',
                  ),
                ),
                TextField(
                  controller: employeeIdCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'رقم الموظف',
                    hintText: 'اختياري',
                  ),
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
                final tankId = int.tryParse(
                  tankIdCtrl.text.trim(),
                );

                final supplierId = int.tryParse(
                  supplierIdCtrl.text.trim(),
                );

                final units = int.tryParse(
                  unitsCtrl.text.trim(),
                );

                final purchasePrice = double.tryParse(
                  purchasePriceCtrl.text.trim(),
                );

                final employeeText = employeeIdCtrl.text.trim();

                final employeeId =
                    employeeText.isEmpty ? null : int.tryParse(employeeText);

                final operationDate = operationDateCtrl.text.trim();

                if (tankId == null || tankId <= 0) {
                  _showDialogError(
                    dialogContext,
                    'يرجى إدخال رقم صهريج صحيح',
                  );
                  return;
                }

                if (supplierId == null || supplierId <= 0) {
                  _showDialogError(
                    dialogContext,
                    'يرجى إدخال رقم مورد صحيح',
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

                if (purchasePrice == null || purchasePrice < 0) {
                  _showDialogError(
                    dialogContext,
                    'يرجى إدخال سعر شراء صحيح',
                  );
                  return;
                }

                if (operationDate.isEmpty) {
                  _showDialogError(
                    dialogContext,
                    'يرجى إدخال تاريخ العملية',
                  );
                  return;
                }

                if (employeeText.isNotEmpty && employeeId == null) {
                  _showDialogError(
                    dialogContext,
                    'رقم الموظف غير صحيح',
                  );
                  return;
                }

                final user = context.read<UserProvider>().currentUser;

                if (user?.id == null) {
                  _showDialogError(
                    dialogContext,
                    'لا يوجد مستخدم مسجل لإنشاء العملية',
                  );
                  return;
                }

                final now = DateTime.now().toIso8601String();

                final operation = FillingOperation(
                  id: existing?.id,
                  syncId: existing?.syncId ?? const Uuid().v4(),
                  operationNumber: operationNumberCtrl.text.trim().isEmpty
                      ? null
                      : operationNumberCtrl.text.trim(),
                  tankId: tankId,
                  supplierId: supplierId,
                  units: units,
                  purchasePrice: purchasePrice,
                  operationDate: operationDate,
                  employeeId: employeeId,
                  notes: notesCtrl.text.trim().isEmpty
                      ? null
                      : notesCtrl.text.trim(),
                  createdBy: existing?.createdBy ?? user!.id!,
                  createdAt: existing?.createdAt ?? now,
                  updatedAt: now,
                );

                try {
                  if (existing == null) {
                    await _service.addOperation(operation);
                  } else {
                    await _service.updateOperation(operation);
                  }

                  if (!mounted || !dialogContext.mounted) return;

                  Navigator.pop(dialogContext);
                  _refresh();

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        existing == null
                            ? 'تمت إضافة عملية التعبئة بنجاح'
                            : 'تم تعديل عملية التعبئة بنجاح',
                      ),
                    ),
                  );
                } catch (e) {
                  if (!dialogContext.mounted) return;

                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    SnackBar(
                      content: Text('حدث خطأ أثناء الحفظ: $e'),
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

  void _confirmDelete(FillingOperation operation) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('تأكيد الحذف'),
          content: Text(
            'هل تريد حذف عملية التعبئة '
            '"${operation.operationNumber ?? operation.id}"؟',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  await _service.deleteOperation(operation.id!);

                  if (!mounted || !dialogContext.mounted) return;

                  Navigator.pop(dialogContext);
                  _refresh();

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'تم حذف عملية التعبئة بنجاح',
                      ),
                    ),
                  );
                } catch (e) {
                  if (!dialogContext.mounted) return;

                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    SnackBar(
                      content: Text('حدث خطأ أثناء الحذف: $e'),
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
