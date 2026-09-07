import 'package:flutter/material.dart';
import '../../models/payment.dart';
import '../../services/payment_service.dart';

class PaymentsScreen extends StatefulWidget {
  const PaymentsScreen({super.key});
  @override
  State<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends State<PaymentsScreen> {
  final PaymentService _service = PaymentService();
  late Future<List<Payment>> _future;
  @override
  void initState() { super.initState(); _future = _service.getAllPayments(); }
  void _refresh() => setState(() => _future = _service.getAllPayments());
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('المدفوعات')),
      body: FutureBuilder<List<Payment>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (!snapshot.hasData || snapshot.data!.isEmpty) return const Center(child: Text('لا توجد مدفوعات'));
          return ListView.builder(
            itemCount: snapshot.data!.length,
            itemBuilder: (context, index) {
              final payment = snapshot.data![index];
              return ListTile(title: Text('دفعة #${payment.id}'), subtitle: Text('المبلغ: ${payment.amount}'));
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(onPressed: () {}, child: const Icon(Icons.add)),
    );
  }
}
