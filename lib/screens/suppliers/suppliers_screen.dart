import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/supplier.dart';
import '../../models/operation_log.dart';
import '../../services/supplier_service.dart';
import '../../services/operation_log_service.dart';
import '../../core/network/communication_service.dart';
import '../../core/auth/user_provider.dart';
import '../../core/auth/permission_service.dart';
import '../../core/constants/permissions.dart';

class SuppliersScreen extends StatefulWidget {
  const SuppliersScreen({super.key});

  @override
  State<SuppliersScreen> createState() => _SuppliersScreenState();
}

class _SuppliersScreenState extends State<SuppliersScreen> {
  final SupplierService _service = SupplierService();
  final OperationLogService _logService = OperationLogService();

  late Future<List<Supplier>> _future;

  @override
  void initState() {
    super.initState();
    _future = _service.getAllSuppliers();
  }

  void _refresh() {
    setState(() {
      _future = _service.getAllSuppliers();
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserProvider>().currentUser;

    final canAdd = PermissionService.hasPermission(
      user,
      PermissionKeys.suppliersAdd,
    );

    final canEdit = PermissionService.hasPermission(
      user,
      PermissionKeys.suppliersEdit,
    );

    final canDelete = PermissionService.hasPermission(
      user,
      PermissionKeys.suppliersDelete,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('الموردون'),
      ),
      body: FutureBuilder<List<Supplier>>(
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
              child: Text('لا يوجد موردون'),
            );
          }

          final suppliers = snapshot.data!;

          return ListView.builder(
            itemCount: suppliers.length,
            itemBuilder: (context, index) {
              final supplier = suppliers[index];

              return ListTile(
                title: Text(supplier.name),
                subtitle: Text(
                  [
                    if (supplier.phone?.isNotEmpty == true)
                      supplier.phone!,
                    if (supplier.location?.isNotEmpty == true)
                      supplier.location!,
                  ].join(' - '),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.call),
                      onPressed: () {
                        CommunicationService.callPhone(
                          supplier.phone ?? '',
                        );
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.chat),
                      onPressed: () {
                        CommunicationService.openWhatsApp(
                          supplier.phone ?? '',
                          'مرحباً ${supplier.name}',
                        );
                      },
                    ),
                    if (canEdit)
                      IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: () => _showSupplierDialog(supplier),
                      ),
                    if (canDelete)
                      IconButton(
                        icon: const Icon(Icons.delete),
                        onPressed: () => _confirmDelete(supplier),
                      ),
                  ],
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: canAdd
          ? FloatingActionButton(
              onPressed: () => _showSupplierDialog(null),
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  void _showSupplierDialog(Supplier? existing) {
    final numberCtrl = TextEditingController(
      text: existing?.supplierNumber ?? '',
    );
    final nameCtrl = TextEditingController(
      text: existing?.name ?? '',
    );
    final phoneCtrl = TextEditingController(
      text: existing?.phone ?? '',
    );
    final locationCtrl = TextEditingController(
      text: existing?.location ?? '',
    );
    final notesCtrl = TextEditingController(
      text: existing?.notes ?? '',
    );

    String status = existing?.status ?? 'active';

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(
                existing == null ? 'إضافة مورد' : 'تعديل مورد',
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: numberCtrl,
                      decoration: const InputDecoration(
                        labelText: 'رقم المورد',
                      ),
                    ),
                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'اسم المورد *',
                      ),
                    ),
                    TextField(
                      controller: phoneCtrl,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'الهاتف',
                      ),
                    ),
                    TextField(
                      controller: locationCtrl,
                      decoration: const InputDecoration(
                        labelText: 'الموقع',
                      ),
                    ),
                    DropdownButtonFormField<String>(
                      initialValue: status,
                      decoration: const InputDecoration(
                        labelText: 'الحالة',
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'active',
                          child: Text('نشط'),
                        ),
                        DropdownMenuItem(
                          value: 'inactive',
                          child: Text('غير نشط'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() {
                            status = value;
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
                    final user = context.read<UserProvider>().currentUser;
                    final name = nameCtrl.text.trim();

                    if (name.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('يرجى إدخال اسم المورد'),
                        ),
                      );
                      return;
                    }

                    final now = DateTime.now().toIso8601String();

                    final supplier = Supplier(
                      id: existing?.id,
                      supplierNumber: numberCtrl.text.trim().isEmpty
                          ? null
                          : numberCtrl.text.trim(),
                      name: name,
                      phone: phoneCtrl.text.trim().isEmpty
                          ? null
                          : phoneCtrl.text.trim(),
                      location: locationCtrl.text.trim().isEmpty
                          ? null
                          : locationCtrl.text.trim(),
                      status: status,
                      notes: notesCtrl.text.trim().isEmpty
                          ? null
                          : notesCtrl.text.trim(),
                      createdAt: existing?.createdAt ?? now,
                      updatedAt: now,
                    );

                    try {

                      if (existing == null) {
                        final id = await _service.addSupplier(supplier);

                        if (user != null) {
                          await _logService.addLog(
                            OperationLog(
                              userId: user.id!,
                              action: 'create',
                              tableName: 'suppliers',
                              recordId: id,
                              details: 'إضافة مورد: ${supplier.name}',
                              timestamp: now,
                            ),
                          );
                        }
                      } else {
                        await _service.updateSupplier(supplier);

                        if (user != null) {
                          await _logService.addLog(
                            OperationLog(
                              userId: user.id!,
                              action: 'update',
                              tableName: 'suppliers',
                              recordId: supplier.id!,
                              details: 'تعديل مورد: ${supplier.name}',
                              timestamp: now,
                            ),
                          );
                        }
                      }

                      if (!mounted || !dialogContext.mounted) return;

                      Navigator.pop(dialogContext);
                      _refresh();

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            existing == null
                                ? 'تمت إضافة المورد بنجاح'
                                : 'تم تعديل المورد بنجاح',
                          ),
                        ),
                      );
                    } catch (e) {
                      if (!mounted) return;

                      ScaffoldMessenger.of(context).showSnackBar(
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
      },
    );
  }

  void _confirmDelete(Supplier supplier) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('تأكيد الحذف'),
          content: Text(
            'هل تريد حذف المورد "${supplier.name}"؟',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () async {
                final user = context.read<UserProvider>().currentUser;

                try {
                  await _service.deleteSupplier(supplier.id!);

                  if (!mounted || !dialogContext.mounted) return;

                  if (user != null) {
                    await _logService.addLog(
                      OperationLog(
                        userId: user.id!,
                        action: 'delete',
                        tableName: 'suppliers',
                        recordId: supplier.id!,
                        details: 'حذف مورد: ${supplier.name}',
                        timestamp: DateTime.now().toIso8601String(),
                      ),
                    );
                  }

                  if (!dialogContext.mounted) return;

                  Navigator.pop(dialogContext);
                  _refresh();
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
