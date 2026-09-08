import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/expense.dart';
import '../../services/expense_service.dart';
import '../../core/auth/user_provider.dart';

class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({super.key});

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  final ExpenseService _service = ExpenseService();

  late Future<List<Expense>> _future;

  @override
  void initState() {
    super.initState();
    _future = _service.getAllExpenses();
  }

  void _refresh() {
    setState(() {
      _future = _service.getAllExpenses();
    });
  }

  Future<void> _showExpenseDialog({Expense? expense}) async {
    final formKey = GlobalKey<FormState>();

    final typeController = TextEditingController(
      text: expense?.expenseType ?? '',
    );

    final amountController = TextEditingController(
      text: expense?.amount.toString() ?? '',
    );

    final notesController = TextEditingController(
      text: expense?.notes ?? '',
    );

    DateTime selectedDate = expense != null
        ? DateTime.tryParse(expense.expenseDate) ?? DateTime.now()
        : DateTime.now();

    bool saving = false;

    final userProvider = context.read<UserProvider>();

    int? createdBy;

    try {
      final dynamic currentUser = userProvider.currentUser;
      createdBy = currentUser?.id as int?;
    } catch (_) {
      createdBy = null;
    }

    createdBy ??= expense?.createdBy ?? 0;

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
                final amount =
                    double.parse(amountController.text.trim());

                final now = DateTime.now().toIso8601String();

                if (expense == null) {
                  final newExpense = Expense(
                    expenseType: typeController.text.trim(),
                    amount: amount,
                    expenseDate: selectedDate.toIso8601String(),
                    notes: notesController.text.trim().isEmpty
                        ? null
                        : notesController.text.trim(),
                    createdBy: createdBy!,
                    createdAt: now,
                    updatedAt: now,
                    isDeleted: false,
                    isSynced: false,
                  );

                  await _service.addExpense(newExpense);
                } else {
                  final updatedExpense = Expense(
                    id: expense.id,
                    expenseType: typeController.text.trim(),
                    amount: amount,
                    expenseDate: selectedDate.toIso8601String(),
                    notes: notesController.text.trim().isEmpty
                        ? null
                        : notesController.text.trim(),
                    createdBy: expense.createdBy,
                    createdAt: expense.createdAt,
                    updatedAt: now,
                    isDeleted: expense.isDeleted,
                    isSynced: false,
                  );

                  await _service.updateExpense(updatedExpense);
                }

                if (!dialogContext.mounted) return;

                Navigator.of(dialogContext).pop();

                if (!mounted) return;

                _refresh();

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      expense == null
                          ? 'تمت إضافة المصروف بنجاح'
                          : 'تم تعديل المصروف بنجاح',
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
                expense == null ? 'إضافة مصروف' : 'تعديل المصروف',
              ),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: typeController,
                        enabled: !saving,
                        decoration: const InputDecoration(
                          labelText: 'نوع المصروف',
                          hintText: 'مثال: وقود، صيانة، رواتب',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null ||
                              value.trim().isEmpty) {
                            return 'أدخل نوع المصروف';
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
                            labelText: 'تاريخ المصروف',
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
                          expense == null ? 'إضافة' : 'حفظ',
                        ),
                ),
              ],
            );
          },
        );
      },
    );

    typeController.dispose();
    amountController.dispose();
    notesController.dispose();
  }

  Future<void> _deleteExpense(Expense expense) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('حذف المصروف'),
          content: Text(
            'هل أنت متأكد من حذف المصروف "${expense.expenseType}"؟',
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
      await _service.deleteExpense(expense.id!);

      if (!mounted) return;

      _refresh();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم حذف المصروف بنجاح'),
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
        title: const Text('المصروفات'),
        actions: [
          IconButton(
            onPressed: _refresh,
            tooltip: 'تحديث',
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: FutureBuilder<List<Expense>>(
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
                      'حدث خطأ أثناء تحميل المصروفات\n${snapshot.error}',
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

          final expenses = snapshot.data ?? [];

          if (expenses.isEmpty) {
            return const Center(
              child: Text('لا توجد مصروفات'),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              _refresh();
              await _future;
            },
            child: ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: expenses.length,
              itemBuilder: (context, index) {
                final expense = expenses[index];

                return Card(
                  child: ListTile(
                    leading: const CircleAvatar(
                      child: Icon(Icons.money_off),
                    ),
                    title: Text(expense.expenseType),
                    subtitle: Text(
                      'المبلغ: ${expense.amount.toStringAsFixed(2)}\n'
                      'التاريخ: ${expense.expenseDate.split('T').first}'
                      '${expense.notes == null || expense.notes!.isEmpty ? '' : '\nملاحظات: ${expense.notes}'}',
                    ),
                    isThreeLine: true,
                    trailing: PopupMenuButton<String>(
                      onSelected: (value) {
                        if (value == 'edit') {
                          _showExpenseDialog(expense: expense);
                        } else if (value == 'delete') {
                          _deleteExpense(expense);
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
        onPressed: () => _showExpenseDialog(),
        icon: const Icon(Icons.add),
        label: const Text('إضافة مصروف'),
      ),
    );
  }
}
