import 'package:flutter/material.dart';

import 'client_statement_screen.dart';
import 'supplier_statement_screen.dart';
import '../../services/client_service.dart';
import '../../services/supplier_service.dart';

class StatementsScreen extends StatefulWidget {
  const StatementsScreen({super.key});

  @override
  State<StatementsScreen> createState() => _StatementsScreenState();
}

class _StatementsScreenState extends State<StatementsScreen> {
  final ClientService _clientService = ClientService();
  final SupplierService _supplierService = SupplierService();

  Future<List<dynamic>> _loadClients() async {
    return _clientService.getAllClients();
  }

  Future<List<dynamic>> _loadSuppliers() async {
    return _supplierService.getAllSuppliers();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('كشوف الحسابات'),
          actions: [
            IconButton(
              onPressed: () {
                setState(() {});
              },
              tooltip: 'تحديث',
              icon: const Icon(Icons.refresh),
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(
                icon: Icon(Icons.people),
                text: 'العملاء',
              ),
              Tab(
                icon: Icon(Icons.business),
                text: 'الموردون',
              ),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildClientList(),
            _buildSupplierList(),
          ],
        ),
      ),
    );
  }

  Widget _buildClientList() {
    return FutureBuilder<List<dynamic>>(
      future: _loadClients(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        if (snapshot.hasError) {
          return _buildError(
            'حدث خطأ أثناء تحميل العملاء',
          );
        }

        final clients = snapshot.data ?? [];

        if (clients.isEmpty) {
          return _buildEmpty(
            icon: Icons.people_outline,
            message: 'لا يوجد عملاء',
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            if (mounted) {
              setState(() {});
            }
          },
          child: ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: clients.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final client = clients[index];

              return ListTile(
                leading: const CircleAvatar(
                  child: Icon(Icons.person),
                ),
                title: Text(
                  client.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: client.phone != null &&
                        client.phone.toString().trim().isNotEmpty
                    ? Text(client.phone.toString())
                    : null,
                trailing: const Icon(
                  Icons.arrow_forward_ios,
                  size: 18,
                ),
                onTap: () {
                  if (client.id == null) return;

                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ClientStatementScreen(
                        clientId: client.id!,
                      ),
                    ),
                  );
                },
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildSupplierList() {
    return FutureBuilder<List<dynamic>>(
      future: _loadSuppliers(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        if (snapshot.hasError) {
          return _buildError(
            'حدث خطأ أثناء تحميل الموردين',
          );
        }

        final suppliers = snapshot.data ?? [];

        if (suppliers.isEmpty) {
          return _buildEmpty(
            icon: Icons.business_outlined,
            message: 'لا يوجد موردون',
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            if (mounted) {
              setState(() {});
            }
          },
          child: ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: suppliers.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final supplier = suppliers[index];

              return ListTile(
                leading: const CircleAvatar(
                  child: Icon(Icons.business),
                ),
                title: Text(
                  supplier.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: supplier.phone != null &&
                        supplier.phone.toString().trim().isNotEmpty
                    ? Text(supplier.phone.toString())
                    : null,
                trailing: const Icon(
                  Icons.arrow_forward_ios,
                  size: 18,
                ),
                onTap: () {
                  if (supplier.id == null) return;

                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SupplierStatementScreen(
                        supplierId: supplier.id!,
                      ),
                    ),
                  );
                },
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildError(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline,
              size: 48,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () {
                setState(() {});
              },
              icon: const Icon(Icons.refresh),
              label: const Text('إعادة المحاولة'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty({
    required IconData icon,
    required String message,
  }) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 64,
          ),
          const SizedBox(height: 12),
          Text(
            message,
            style: const TextStyle(
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}
