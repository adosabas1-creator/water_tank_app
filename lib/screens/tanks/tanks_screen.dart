import 'package:flutter/material.dart';
import '../../models/tank.dart';
import '../../services/tank_service.dart';

class TanksScreen extends StatefulWidget {
  const TanksScreen({super.key});

  @override
  State<TanksScreen> createState() => _TanksScreenState();
}

class _TanksScreenState extends State<TanksScreen> {
  final TankService _service = TankService();
  late Future<List<Tank>> _future;

  @override
  void initState() {
    super.initState();
    _future = _service.getAllTanks();
  }

  void _refresh() {
    setState(() {
      _future = _service.getAllTanks();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('الصهاريج'),
      ),
      body: FutureBuilder<List<Tank>>(
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
              child: Text('لا يوجد صهاريج'),
            );
          }

          final tanks = snapshot.data!;

          return ListView.builder(
            itemCount: tanks.length,
            itemBuilder: (context, index) {
              final tank = tanks[index];

              return ListTile(
                leading: const CircleAvatar(
                  child: Icon(Icons.local_shipping),
                ),
                title: Text('صهريج ${tank.tankNumber}'),
                subtitle: Text(
                  'السعة: ${tank.capacityUnits} وحدة'
                  '${tank.driverId != null ? ' - السائق رقم: ${tank.driverId}' : ''}',
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: () => _showTankDialog(tank),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete),
                      onPressed: () => _confirmDelete(tank),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showTankDialog(null),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showTankDialog(Tank? existing) {
    final tankNumberCtrl = TextEditingController(
      text: existing?.tankNumber ?? '',
    );

    final capacityCtrl = TextEditingController(
      text: existing?.capacityUnits.toString() ?? '',
    );

    final driverIdCtrl = TextEditingController(
      text: existing?.driverId?.toString() ?? '',
    );

    final notesCtrl = TextEditingController(
      text: existing?.notes ?? '',
    );

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(
            existing == null ? 'إضافة صهريج' : 'تعديل صهريج',
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: tankNumberCtrl,
                  decoration: const InputDecoration(
                    labelText: 'رقم الصهريج *',
                  ),
                ),
                TextField(
                  controller: capacityCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'السعة بالوحدات *',
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
                final tankNumber = tankNumberCtrl.text.trim();
                final capacity =
                    int.tryParse(capacityCtrl.text.trim());
                final driverIdText = driverIdCtrl.text.trim();
                final driverId =
                    driverIdText.isEmpty ? null : int.tryParse(driverIdText);

                if (tankNumber.isEmpty) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(
                      content: Text('يرجى إدخال رقم الصهريج'),
                    ),
                  );
                  return;
                }

                if (capacity == null || capacity <= 0) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(
                      content: Text('يرجى إدخال سعة صحيحة أكبر من صفر'),
                    ),
                  );
                  return;
                }

                if (driverIdText.isNotEmpty && driverId == null) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(
                      content: Text('رقم السائق غير صحيح'),
                    ),
                  );
                  return;
                }

                final now = DateTime.now().toIso8601String();

                final tank = Tank(
                  id: existing?.id,
                  tankNumber: tankNumber,
                  capacityUnits: capacity,
                  driverId: driverId,
                  notes: notesCtrl.text.trim().isEmpty
                      ? null
                      : notesCtrl.text.trim(),
                  createdAt: existing?.createdAt ?? now,
                  updatedAt: now,
                );

                try {
                  if (existing == null) {
                    await _service.addTank(tank);
                  } else {
                    await _service.updateTank(tank);
                  }

                  if (!mounted || !dialogContext.mounted) return;

                  Navigator.pop(dialogContext);
                  _refresh();

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        existing == null
                            ? 'تمت إضافة الصهريج بنجاح'
                            : 'تم تعديل الصهريج بنجاح',
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

  void _confirmDelete(Tank tank) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('تأكيد الحذف'),
          content: Text(
            'هل تريد حذف الصهريج "${tank.tankNumber}"؟',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  await _service.deleteTank(tank.id!);

                  if (!mounted || !dialogContext.mounted) return;

                  Navigator.pop(dialogContext);
                  _refresh();

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('تم حذف الصهريج بنجاح'),
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
