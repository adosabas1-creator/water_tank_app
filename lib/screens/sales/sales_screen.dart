import 'package:flutter/material.dart';
import '../../models/sale.dart';
import '../../services/sale_service.dart';

class SalesScreen extends StatefulWidget {
  const SalesScreen({super.key});
  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> {
  final SaleService _service = SaleService();
  late Future<List<Sale>> _future;
  @override
  void initState() { super.initState(); _future = _service.getAllSales(); }
  void _refresh() => setState(() => _future = _service.getAllSales());
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('المبيعات')),
      body: FutureBuilder<List<Sale>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (!snapshot.hasData || snapshot.data!.isEmpty) return const Center(child: Text('لا توجد مبيعات'));
          return ListView.builder(
            itemCount: snapshot.data!.length,
            itemBuilder: (context, index) {
              final sale = snapshot.data![index];
              return ListTile(title: Text('بيع #${sale.id}'), subtitle: Text('الإجمالي: ${sale.totalAmount}'));
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(onPressed: () {}, child: const Icon(Icons.add)),
    );
  }
}
