import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/salary.dart';
import '../../services/salary_service.dart';
import '../../core/auth/user_provider.dart';

class SalariesScreen extends StatefulWidget {
  const SalariesScreen({super.key});

  @override
  State<SalariesScreen> createState() => _SalariesScreenState();
}

class _SalariesScreenState extends State<SalariesScreen> {
  final SalaryService _service = SalaryService();
  late Future<List<Salary>> _future;

  @override
  void initState() {
    super.initState();
    _future = _service.getAllSalaries();
  }

  void _refresh() {
    setState(() {
      _future = _service.getAllSalaries();
    });
  }

  Future<void> _showSalaryDialog({Salary? salary}) async {
    final formKey = GlobalKey<FormState>();

    final employeeController = TextEditingController(
      text: salary?.employeeId.toString() ?? '',
    );
    final monthController = TextEditingController(
      text: salary?.month ?? '',
    );
    final baseController = TextEditingController(
      text: salary?.baseSalary.toString() ?? '',
    );
    final advancesController = TextEditingController(
      text: salary?.advances.toString() ?? '0',
    );
    final deductionsController = TextEditingController(
      text: salary?.deductions.toString() ?? '0',
    );
    final paymentDateController = TextEditingController(
      text: salary?.paymentDate?.split('T').first ?? '',
    );
    final notesController = TextEditingController(
      text: salary?.notes ?? '',
    );

    bool saving = false;

    final userProvider = context.read<UserProvider>();
    int? createdBy;

    try {
      final dynamic currentUser = userProvider.currentUser;
      createdBy = currentUser?.id as int?;
    } catch (_) {
      createdBy = null;
    }

    createdBy ??= salary?.createdBy ?? 0;

    double calculateNet() {
      final base = double.tryParse(baseController.text.trim()) ?? 0;
      final advances =
          double.tryParse(advancesController.text.trim()) ?? 0;
      final deductions =
          double.tryParse(deductionsController.text.trim()) ?? 0;
      return base - advances - deductions;
    }

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> pickDate() async {
              final initialDate =
                  DateTime.tryParse(paymentDateController.text) ??
                      DateTime.now();

              final picked = await showDatePicker(
                context: context,
                initialDate: initialDate,
                firstDate: DateTime(2020),
                lastDate: DateTime(2100),
              );

              if (picked != null) {
                setDialogState(() {
                  paymentDateController.text =
                      '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
                });
              }
            }

            Future<void> save() async {
              if (!formKey.currentState!.validate()) return;

              final employeeId =
                  int.tryParse(employeeController.text.trim());
              final baseSalary =
                  double.tryParse(baseController.text.trim());
              final advances =
                  double.tryParse(advancesController.text.trim()) ?? 0;
              final deductions =
                  double.tryParse(deductionsController.text.trim()) ?? 0;

              if (employeeId == null || baseSalary == null) return;

              setDialogState(() {
                saving = true;
              });

              try {
                final now = DateTime.now().toIso8601String();
                final paymentDate =
                    paymentDateController.text.trim().isEmpty
                        ? null
                        : paymentDateController.text.trim();

                final notes =
                    notesController.text.trim().isEmpty
                        ? null
                        : notesController.text.trim();

                final netSalary =
                    baseSalary - advances - deductions;

                if (salary == null) {
                  await _service.addSalary(
                    Salary(
                      employeeId: employeeId,
                      month: monthController.text.trim(),
                      baseSalary: baseSalary,
                      advances: advances,
                      deductions: deductions,
                      netSalary: netSalary,
                      paymentDate: paymentDate,
                      notes: notes,
                      createdBy: createdBy!,
                      createdAt: now,
                      updatedAt: now,
                    ),
                  );
                } else {
                  await _service.updateSalary(
                    Salary(
                      id: salary.id,
                      employeeId: employeeId,
                      month: monthController.text.trim(),
                      baseSalary: baseSalary,
                      advances: advances,
                      deductions: deductions,
                      netSalary: netSalary,
                      paymentDate: paymentDate,
                      notes: notes,
                      createdBy: salary.createdBy,
                      createdAt: salary.createdAt,
                      updatedAt: now,
                      isDeleted: salary.isDeleted,
                      isSynced: false,
                    ),
                  );
                }

                if (!dialogContext.mounted) return;
                Navigator.of(dialogContext).pop();

                if (!mounted) return;

                _refresh();

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      salary == null
                          ? 'تمت إضافة الراتب بنجاح'
                          : 'تم تعديل الراتب بنجاح',
                    ),
                  ),
                );
              } catch (e) {
                if (!dialogContext.mounted) return;

                setDialogState(() {
                  saving = false;
                });

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('حدث خطأ: $e'),
                  ),
                );
              }
            }

            return AlertDialog(
              title: Text(
                salary == null ? 'إضافة راتب' : 'تعديل الراتب',
              ),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: employeeController,
                        enabled: !saving,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'رقم الموظف',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          final id =
                              int.tryParse(value?.trim() ?? '');
                          if (id == null || id <= 0) {
                            return 'أدخل رقم موظف صحيح';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: monthController,
                        enabled: !saving,
                        decoration: const InputDecoration(
                          labelText: 'الشهر',
                          hintText: 'مثال: 2026-09',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null ||
                              value.trim().isEmpty) {
                            return 'أدخل الشهر';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: baseController,
                        enabled: !saving,
                        keyboardType:
                            const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'الراتب الأساسي',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          final amount =
                              double.tryParse(value?.trim() ?? '');
                          if (amount == null || amount < 0) {
                            return 'أدخل راتبًا صحيحًا';
                          }
                          return null;
                        },
                        onChanged: (_) => setDialogState(() {}),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: advancesController,
                        enabled: !saving,
                        keyboardType:
                            const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'السلف',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          final amount =
                              double.tryParse(value?.trim() ?? '');
                          if (amount == null || amount < 0) {
                            return 'أدخل قيمة صحيحة';
                          }
                          return null;
                        },
                        onChanged: (_) => setDialogState(() {}),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: deductionsController,
                        enabled: !saving,
                        keyboardType:
                            const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'الخصومات',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          final amount =
                              double.tryParse(value?.trim() ?? '');
                          if (amount == null || amount < 0) {
                            return 'أدخل قيمة صحيحة';
                          }
                          return null;
                        },
                        onChanged: (_) => setDialogState(() {}),
                      ),
                      const SizedBox(height: 12),
                      InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'صافي الراتب',
                          border: OutlineInputBorder(),
                        ),
                        child: Text(
                          calculateNet().toStringAsFixed(2),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: paymentDateController,
                        readOnly: true,
                        enabled: !saving,
                        onTap: pickDate,
                        decoration: const InputDecoration(
                          labelText: 'تاريخ الدفع',
                          border: OutlineInputBorder(),
                          suffixIcon: Icon(Icons.calendar_month),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: notesController,
                        enabled: !saving,
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
                          salary == null ? 'إضافة' : 'حفظ',
                        ),
                ),
              ],
            );
          },
        );
      },
    );

    employeeController.dispose();
    monthController.dispose();
    baseController.dispose();
    advancesController.dispose();
    deductionsController.dispose();
    paymentDateController.dispose();
    notesController.dispose();
  }

  Future<void> _deleteSalary(Salary salary) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('حذف الراتب'),
          content: Text(
            'هل أنت متأكد من حذف راتب الموظف رقم ${salary.employeeId} لشهر ${salary.month}؟',
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
      await _service.deleteSalary(salary.id!);

      if (!mounted) return;

      _refresh();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم حذف الراتب بنجاح'),
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
        title: const Text('الرواتب'),
        actions: [
          IconButton(
            onPressed: _refresh,
            tooltip: 'تحديث',
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: FutureBuilder<List<Salary>>(
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
                    const Icon(Icons.error_outline, size: 48),
                    const SizedBox(height: 12),
                    Text(
                      'حدث خطأ أثناء تحميل الرواتب\n${snapshot.error}',
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

          final salaries = snapshot.data ?? [];

          if (salaries.isEmpty) {
            return const Center(
              child: Text('لا توجد رواتب'),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              _refresh();
              await _future;
            },
            child: ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: salaries.length,
              itemBuilder: (context, index) {
                final salary = salaries[index];

                return Card(
                  child: ListTile(
                    leading: const CircleAvatar(
                      child: Icon(Icons.payments),
                    ),
                    title: Text(
                      'الموظف: ${salary.employeeId}',
                    ),
                    subtitle: Text(
                      'الشهر: ${salary.month}\n'
                      'الأساسي: ${salary.baseSalary.toStringAsFixed(2)}\n'
                      'السلف: ${salary.advances.toStringAsFixed(2)} | '
                      'الخصومات: ${salary.deductions.toStringAsFixed(2)}\n'
                      'الصافي: ${salary.netSalary.toStringAsFixed(2)}'
                      '${salary.paymentDate == null ? '' : '\nتاريخ الدفع: ${salary.paymentDate!.split('T').first}'}'
                      '${salary.notes == null || salary.notes!.isEmpty ? '' : '\nملاحظات: ${salary.notes}'}',
                    ),
                    isThreeLine: true,
                    trailing: PopupMenuButton<String>(
                      onSelected: (value) {
                        if (value == 'edit') {
                          _showSalaryDialog(salary: salary);
                        } else if (value == 'delete') {
                          _deleteSalary(salary);
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
        onPressed: () => _showSalaryDialog(),
        icon: const Icon(Icons.add),
        label: const Text('إضافة راتب'),
      ),
    );
  }
}
