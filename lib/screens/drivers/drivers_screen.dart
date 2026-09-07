import 'package:flutter/material.dart';
import '../../models/driver.dart';
import '../../services/driver_service.dart';

class DriversScreen extends StatefulWidget {
  const DriversScreen({super.key});
  @override
  State<DriversScreen> createState() => _DriversScreenState();
}

class _DriversScreenState extends State<DriversScreen> {
  final DriverService _service = DriverService();
  late Future<List<Driver>> _future;
  @override
  void initState() { super.initState(); _future = _service.getAllDrivers(); }
  void _refresh() => setState(() => _future = _service.getAllDrivers());
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('السائقون')),
      body: FutureBuilder<List<Driver>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (!snapshot.hasData || snapshot.data!.isEmpty) return const Center(child: Text('لا يوجد سائقون'));
          return ListView.builder(
            itemCount: snapshot.data!.length,
            itemBuilder: (context, index) {
              final driver = snapshot.data![index];
              return ListTile(title: Text(driver.name), subtitle: Text(driver.phone ?? ''));
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(onPressed: () {}, child: const Icon(Icons.add)),
    );
  }
}
