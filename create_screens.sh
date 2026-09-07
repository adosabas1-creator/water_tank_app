#!/usr/bin/env bash

mkdir -p lib/screens/clients lib/screens/suppliers lib/screens/drivers lib/screens/tanks lib/screens/filling lib/screens/sales lib/screens/payments lib/screens/expenses lib/screens/salaries lib/screens/reports lib/screens/statements lib/screens/users lib/screens/logs

# العملاء
cat > lib/screens/clients/clients_screen.dart << 'EOF'
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/client.dart';
import '../../services/client_service.dart';
import '../../core/auth/user_provider.dart';
import '../../core/auth/permission_service.dart';
import '../../core/constants/permissions.dart';

class ClientsScreen extends StatefulWidget {
  const ClientsScreen({super.key});
  @override
  State<ClientsScreen> createState() => _ClientsScreenState();
}

class _ClientsScreenState extends State<ClientsScreen> {
  final ClientService _service = ClientService();
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
    final canAdd = PermissionService.hasPermission(user, PermissionKeys.clientsAdd);
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
              );
            },
          );
        },
      ),
      floatingActionButton: canAdd ? FloatingActionButton(
        onPressed: () => _showClientDialog(null),
        child: const Icon(Icons.add),
      ) : null,
    );
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
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'اسم العميل')),
            TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: 'الهاتف')),
            TextField(controller: addressCtrl, decoration: const InputDecoration(labelText: 'العنوان')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () async {
              final now = DateTime.now().toIso8601String();
              final client = Client(
                id: existing?.id,
                name: nameCtrl.text.trim(),
                phone: phoneCtrl.text.trim(),
                address: addressCtrl.text.trim(),
                createdAt: existing?.createdAt ?? now,
                updatedAt: now,
              );
              if (existing == null) await _service.addClient(client); else await _service.updateClient(client);
              if (context.mounted) Navigator.pop(context);
              _refresh();
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }
}
EOF

# الموردون (مبسطة)
cat > lib/screens/suppliers/suppliers_screen.dart << 'EOF'
import 'package:flutter/material.dart';
import '../../models/supplier.dart';
import '../../services/supplier_service.dart';

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
              return ListTile(title: Text(supplier.name), subtitle: Text(supplier.phone ?? ''));
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(onPressed: () {}, child: const Icon(Icons.add)),
    );
  }
}
EOF

# السائقون (مبسطة)
cat > lib/screens/drivers/drivers_screen.dart << 'EOF'
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
EOF

# الصهاريج (مبسطة)
cat > lib/screens/tanks/tanks_screen.dart << 'EOF'
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
EOF

# عمليات التعبئة (مبسطة)
cat > lib/screens/filling/filling_screen.dart << 'EOF'
import 'package:flutter/material.dart';
import '../../models/filling_operation.dart';
import '../../services/filling_operation_service.dart';

class FillingScreen extends StatefulWidget {
  const FillingScreen({super.key});
  @override
  State<FillingScreen> createState() => _FillingScreenState();
}

class _FillingScreenState extends State<FillingScreen> {
  final FillingOperationService _service = FillingOperationService();
  late Future<List<FillingOperation>> _future;
  @override
  void initState() { super.initState(); _future = _service.getAllOperations(); }
  void _refresh() => setState(() => _future = _service.getAllOperations());
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('عمليات التعبئة')),
      body: FutureBuilder<List<FillingOperation>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (!snapshot.hasData || snapshot.data!.isEmpty) return const Center(child: Text('لا توجد عمليات'));
          return ListView.builder(
            itemCount: snapshot.data!.length,
            itemBuilder: (context, index) {
              final op = snapshot.data![index];
              return ListTile(title: Text('عملية #${op.id}'), subtitle: Text('الوحدات: ${op.units}'));
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(onPressed: () {}, child: const Icon(Icons.add)),
    );
  }
}
EOF

# المبيعات (مبسطة)
cat > lib/screens/sales/sales_screen.dart << 'EOF'
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
EOF

# المدفوعات (مبسطة)
cat > lib/screens/payments/payments_screen.dart << 'EOF'
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
EOF

# المصروفات (مبسطة)
cat > lib/screens/expenses/expenses_screen.dart << 'EOF'
import 'package:flutter/material.dart';
import '../../models/expense.dart';
import '../../services/expense_service.dart';

class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({super.key});
  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  final ExpenseService _service = ExpenseService();
  late Future<List<Expense>> _future;
  @override
  void initState() { super.initState(); _future = _service.getAllExpenses(); }
  void _refresh() => setState(() => _future = _service.getAllExpenses());
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('المصروفات')),
      body: FutureBuilder<List<Expense>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (!snapshot.hasData || snapshot.data!.isEmpty) return const Center(child: Text('لا توجد مصروفات'));
          return ListView.builder(
            itemCount: snapshot.data!.length,
            itemBuilder: (context, index) {
              final expense = snapshot.data![index];
              return ListTile(title: Text(expense.expenseType), subtitle: Text('المبلغ: ${expense.amount}'));
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(onPressed: () {}, child: const Icon(Icons.add)),
    );
  }
}
EOF

# الرواتب (مبسطة)
cat > lib/screens/salaries/salaries_screen.dart << 'EOF'
import 'package:flutter/material.dart';
import '../../models/salary.dart';
import '../../services/salary_service.dart';

class SalariesScreen extends StatefulWidget {
  const SalariesScreen({super.key});
  @override
  State<SalariesScreen> createState() => _SalariesScreenState();
}

class _SalariesScreenState extends State<SalariesScreen> {
  final SalaryService _service = SalaryService();
  late Future<List<Salary>> _future;
  @override
  void initState() { super.initState(); _future = _service.getAllSalaries(); }
  void _refresh() => setState(() => _future = _service.getAllSalaries());
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الرواتب')),
      body: FutureBuilder<List<Salary>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (!snapshot.hasData || snapshot.data!.isEmpty) return const Center(child: Text('لا توجد رواتب'));
          return ListView.builder(
            itemCount: snapshot.data!.length,
            itemBuilder: (context, index) {
              final salary = snapshot.data![index];
              return ListTile(title: Text('موظف: ${salary.employeeId}'), subtitle: Text('الصافي: ${salary.netSalary}'));
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(onPressed: () {}, child: const Icon(Icons.add)),
    );
  }
}
EOF

# شاشات Placeholder
for screen in reports statements users logs; do
  case $screen in
    reports)
      title="التقارير"
      ;;
    statements)
      title="كشوف الحسابات"
      ;;
    users)
      title="المستخدمون"
      ;;
    logs)
      title="سجل العمليات"
      ;;
  esac
  cat > lib/screens/$screen/${screen}_screen.dart << EOF
import 'package:flutter/material.dart';

class ${screen^}Screen extends StatelessWidget {
  const ${screen^}Screen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('$title')),
      body: const Center(child: Text('$title ستظهر هنا')),
    );
  }
}
EOF
done

echo "تم إنشاء جميع الشاشات بنجاح!"
