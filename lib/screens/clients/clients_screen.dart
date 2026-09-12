import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:provider/provider.dart';
import '../../models/client.dart';
import '../../models/operation_log.dart';
import '../../services/client_service.dart';
import '../../services/operation_log_service.dart';
import '../../services/contact_picker_service.dart';
import '../../core/network/communication_service.dart';
import '../../core/auth/user_provider.dart';
import '../../core/auth/permission_service.dart';
import '../../core/constants/permissions.dart';
import '../statements/client_statement_screen.dart';

class ClientsScreen extends StatefulWidget {
  const ClientsScreen({super.key});
  @override
  State<ClientsScreen> createState() => _ClientsScreenState();
}

class _ClientsScreenState extends State<ClientsScreen> {
  final ClientService _service = ClientService();
  final OperationLogService _logService = OperationLogService();
  late Future<List<Client>> _future;

  @override
  void initState() {
    super.initState();
    _future = _service.getAllClients();
  }

  void _refresh() {
    setState(() => _future = _service.getAllClients());
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserProvider>().currentUser;
    final canAdd =
        PermissionService.hasPermission(user, PermissionKeys.clientsAdd);
    final canEdit =
        PermissionService.hasPermission(user, PermissionKeys.clientsEdit);
    final canDelete =
        PermissionService.hasPermission(user, PermissionKeys.clientsDelete);
    return Scaffold(
      appBar: AppBar(title: const Text('العملاء')),
      body: FutureBuilder<List<Client>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('لا يوجد عملاء'));
          }
          return ListView.builder(
            itemCount: snapshot.data!.length,
            itemBuilder: (context, index) {
              final client = snapshot.data![index];
              return ListTile(
                title: Text(client.name),
                subtitle: Text(client.phone ?? ''),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                        icon: const Icon(Icons.call),
                        onPressed: () =>
                            CommunicationService.callPhone(client.phone ?? '')),
                    IconButton(
                        icon: const Icon(Icons.chat),
                        onPressed: () => CommunicationService.openWhatsApp(
                            client.phone ?? '', 'مرحباً ${client.name}')),
                    if (canEdit)
                      IconButton(
                          icon: const Icon(Icons.edit),
                          onPressed: () => _showClientDialog(client)),
                    if (canDelete)
                      IconButton(
                          icon: const Icon(Icons.delete),
                          onPressed: () => _confirmDelete(client)),
                  ],
                ),
                onTap: () => _showStatement(client),
              );
            },
          );
        },
      ),
      floatingActionButton: canAdd
          ? FloatingActionButton(
              onPressed: () => _showClientDialog(null),
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  Future<void> _pickClientContact(
    TextEditingController nameCtrl,
    TextEditingController phoneCtrl,
    BuildContext dialogContext,
  ) async {
    try {
      final contact = await ContactPickerService.pickContact();

      if (!mounted || !dialogContext.mounted) return;

      if (contact == null) {
        ScaffoldMessenger.of(dialogContext).showSnackBar(
          const SnackBar(
            content: Text('لم يتم اختيار جهة اتصال'),
          ),
        );
        return;
      }

      final name = contact.displayName?.trim() ?? '';
      final phone =
          contact.phones.isNotEmpty ? contact.phones.first.number.trim() : '';

      if (name.isNotEmpty) {
        nameCtrl.text = name;
      }

      if (phone.isNotEmpty) {
        phoneCtrl.text = phone;
      }

      if (name.isEmpty && phone.isEmpty) {
        ScaffoldMessenger.of(dialogContext).showSnackBar(
          const SnackBar(
            content: Text('جهة الاتصال المختارة لا تحتوي على اسم أو رقم هاتف'),
          ),
        );
      }
    } catch (e) {
      if (!mounted || !dialogContext.mounted) return;

      ScaffoldMessenger.of(dialogContext).showSnackBar(
        SnackBar(
          content: Text('تعذر فتح جهات الاتصال: $e'),
        ),
      );
    }
  }

  void _showClientDialog(Client? existing) {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final phoneCtrl = TextEditingController(text: existing?.phone ?? '');
    final addressCtrl = TextEditingController(text: existing?.address ?? '');
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(existing == null ? 'إضافة عميل' : 'تعديل عميل'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'اسم العميل')),
            TextField(
                controller: phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'الهاتف')),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _pickClientContact(
                  nameCtrl,
                  phoneCtrl,
                  context,
                ),
                icon: const Icon(Icons.contacts),
                label: const Text('اختيار من جهات الاتصال'),
              ),
            ),
            TextField(
                controller: addressCtrl,
                decoration: const InputDecoration(labelText: 'العنوان')),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () async {
              final now = DateTime.now().toIso8601String();
              if (!mounted) return;
              final dialogContext = context;
              if (!dialogContext.mounted) return;
              final user = dialogContext.read<UserProvider>().currentUser;
              final client = Client(
                id: existing?.id,
                syncId: existing?.syncId ?? const Uuid().v4(),
                name: nameCtrl.text.trim(),
                phone: phoneCtrl.text.trim(),
                address: addressCtrl.text.trim(),
                createdAt: existing?.createdAt ?? now,
                updatedAt: now,
              );

              if (existing == null) {
                final id = await _service.addClient(client);
                if (user != null) {
                  await _logService.addLog(OperationLog(
                    userId: user.id!,
                    action: 'create',
                    tableName: 'clients',
                    recordId: id,
                    details: 'إضافة عميل: ${client.name}',
                    timestamp: now,
                  ));
                }
              } else {
                await _service.updateClient(client);
                if (user != null) {
                  await _logService.addLog(OperationLog(
                    userId: user.id!,
                    action: 'update',
                    tableName: 'clients',
                    recordId: client.id!,
                    details: 'تعديل عميل: ${client.name}',
                    timestamp: now,
                  ));
                }
              }

              if (!mounted) return;
              Navigator.pop(this.context);
              _refresh();
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(Client client) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تأكيد الحذف'),
        content: Text('هل تريد حذف ${client.name}؟'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () async {
              if (!mounted) return;
              final dialogContext = context;
              if (!dialogContext.mounted) return;
              final user = dialogContext.read<UserProvider>().currentUser;
              await _service.deleteClient(client.id!);

              if (user != null) {
                await _logService.addLog(OperationLog(
                  userId: user.id!,
                  action: 'delete',
                  tableName: 'clients',
                  recordId: client.id!,
                  details: 'حذف عميل: ${client.name}',
                  timestamp: DateTime.now().toIso8601String(),
                ));
              }

              if (!mounted) return;
              Navigator.pop(this.context);
              _refresh();
            },
            child: const Text('حذف'),
          ),
        ],
      ),
    );
  }

  void _showStatement(Client client) {
    Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => ClientStatementScreen(clientId: client.id!)));
  }
}
