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
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('كشوف الحسابات'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'العملاء'),
              Tab(text: 'الموردون'),
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
    return FutureBuilder(
      future: ClientService().getAllClients(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final clients = snapshot.data!;
        return ListView.builder(
          itemCount: clients.length,
          itemBuilder: (context, index) {
            final client = clients[index];
            return ListTile(
              title: Text(client.name),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ClientStatementScreen(clientId: client.id!))),
            );
          },
        );
      },
    );
  }

  Widget _buildSupplierList() {
    return FutureBuilder(
      future: SupplierService().getAllSuppliers(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final suppliers = snapshot.data!;
        return ListView.builder(
          itemCount: suppliers.length,
          itemBuilder: (context, index) {
            final supplier = suppliers[index];
            return ListTile(
              title: Text(supplier.name),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SupplierStatementScreen(supplierId: supplier.id!))),
            );
          },
        );
      },
    );
  }
}
