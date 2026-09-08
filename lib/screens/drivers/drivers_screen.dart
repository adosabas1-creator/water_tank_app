import 'package:flutter/material.dart';
import '../../models/driver.dart';
import '../../services/driver_service.dart';
import '../../core/network/communication_service.dart';

class DriversScreen extends StatefulWidget {
  const DriversScreen({super.key});

  @override
  State<DriversScreen> createState() => _DriversScreenState();
}

class _DriversScreenState extends State<DriversScreen> {
  final DriverService _service = DriverService();
  late Future<List<Driver>> _future;

  @override
  void initState() {
    super.initState();
    _future = _service.getAllDrivers();
  }

  void _refresh() {
    setState(() {
      _future = _service.getAllDrivers();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('السائقون'),
      ),
      body: FutureBuilder<List<Driver>>(
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
              child: Text('لا يوجد سائقون'),
            );
          }

          final drivers = snapshot.data!;

          return ListView.builder(
            itemCount: drivers.length,
            itemBuilder: (context, index) {
              final driver = drivers[index];

              return ListTile(
                title: Text(driver.name),
                subtitle: Text(
                  [
                    if (driver.phone?.isNotEmpty == true)
                      driver.phone!,
                    if (driver.licenseNumber?.isNotEmpty == true)
                      'رخصة: ${driver.licenseNumber}',
                  ].join(' - '),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (driver.phone?.isNotEmpty == true)
                      IconButton(
                        icon: const Icon(Icons.call),
                        onPressed: () {
                          CommunicationService.callPhone(
                            driver.phone!,
                          );
                        },
                      ),
                    if (driver.phone?.isNotEmpty == true)
                      IconButton(
                        icon: const Icon(Icons.chat),
                        onPressed: () {
                          CommunicationService.openWhatsApp(
                            driver.phone!,
                            'مرحباً ${driver.name}',
                          );
                        },
                      ),
                    IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: () => _showDriverDialog(driver),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete),
                      onPressed: () => _confirmDelete(driver),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showDriverDialog(null),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showDriverDialog(Driver? existing) {
    final nameCtrl = TextEditingController(
      text: existing?.name ?? '',
    );
    final phoneCtrl = TextEditingController(
      text: existing?.phone ?? '',
    );
    final licenseCtrl = TextEditingController(
      text: existing?.licenseNumber ?? '',
    );
    final notesCtrl = TextEditingController(
      text: existing?.notes ?? '',
    );

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(
            existing == null ? 'إضافة سائق' : 'تعديل سائق',
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'اسم السائق *',
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
                  controller: licenseCtrl,
                  decoration: const InputDecoration(
                    labelText: 'رقم الرخصة',
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
                final name = nameCtrl.text.trim();

                if (name.isEmpty) {
                  if (!dialogContext.mounted) return;

                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(
                      content: Text('يرجى إدخال اسم السائق'),
                    ),
                  );
                  return;
                }

                final now = DateTime.now().toIso8601String();

                final driver = Driver(
                  id: existing?.id,
                  name: name,
                  phone: phoneCtrl.text.trim().isEmpty
                      ? null
                      : phoneCtrl.text.trim(),
                  licenseNumber: licenseCtrl.text.trim().isEmpty
                      ? null
                      : licenseCtrl.text.trim(),
                  notes: notesCtrl.text.trim().isEmpty
                      ? null
                      : notesCtrl.text.trim(),
                  createdAt: existing?.createdAt ?? now,
                  updatedAt: now,
                );

                try {
                  if (existing == null) {
                    await _service.addDriver(driver);
                  } else {
                    await _service.updateDriver(driver);
                  }

                  if (!mounted || !dialogContext.mounted) return;

                  Navigator.pop(dialogContext);
                  _refresh();

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        existing == null
                            ? 'تمت إضافة السائق بنجاح'
                            : 'تم تعديل السائق بنجاح',
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

  void _confirmDelete(Driver driver) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('تأكيد الحذف'),
          content: Text(
            'هل تريد حذف السائق "${driver.name}"؟',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  await _service.deleteDriver(driver.id!);

                  if (!mounted || !dialogContext.mounted) return;

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
