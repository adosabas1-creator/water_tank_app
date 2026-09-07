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
  void initState() { super.initState(); _future = _service.getAllTanks(); }
  void _refresh() => setState(() => _future = _service.getAllTanks());
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الصهاريج')),
      body: FutureBuilder<List<Tank>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (!snapshot.hasData || snapshot.data!.isEmpty) return const Center(child: Text('لا يوجد صهاريج'));
          return ListView.builder(
            itemCount: snapshot.data!.length,
            itemBuilder: (context, index) {
              final tank = snapshot.data![index];
              return ListTile(title: Text(tank.tankNumber), subtitle: Text('السعة: ${tank.capacityUnits}'));
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(onPressed: () {}, child: const Icon(Icons.add)),
    );
  }
}
