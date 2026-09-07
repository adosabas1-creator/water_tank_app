import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/supplier.dart';
import '../../services/supplier_service.dart';
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
  late Future<List<Supplier>> _future;

  @override
  void initState() {
    super.initState();
    _future = _service.getAllSuppliers();
  }

  void _refresh() => setState(() => _future = _service.getAllSuppliers());

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserProvider>().currentUser;
    final canAdd = PermissionService.hasPermission(user, PermissionKeys.suppliersAdd);
    final canEdit = PermissionService.hasPermission(user, PermissionKeys.suppliersEdit);
    final canDelete = PermissionService.hasPermission(user, PermissionKeys.suppliersDelete);
    return Scaffold(
      appBar: AppBar(title: const Text('الموردون')),
      body: FutureBuilder<List<Supplier>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (!snapshot.hasData || snapshot.data!.isEmpty) return const Center(child: Text('لا يوجد موردون'));
          return ListView.builder(
            itemCount: snapshot.data!.length,
            itemBuilder: (context, index) {
              final supplier = snapshot.data![index];
              return ListTile(
                title: Text(supplier.name),
                subtitle: Text(supplier.phone ?? ''),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(icon: const Icon(Icons.call), onPressed: () => CommunicationService.callPhone(supplier.phone ?? '')),
                    IconButton(icon: const Icon(Icons.chat), onPressed: () => CommunicationService.openWhatsApp(supplier.phone ?? '', 'مرحباً ${supplier.name}')),
                    if (canEdit) IconButton(icon: const Icon(Icons.edit), onPressed: () {}),
                    if (canDelete) IconButton(icon: const Icon(Icons.delete), onPressed: () {}),
                  ],
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: canAdd ? FloatingActionButton(onPressed: () {}, child: const Icon(Icons.add)) : null,
    );
  }
}
