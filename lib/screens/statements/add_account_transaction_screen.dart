import 'package:flutter/material.dart';

import 'package:provider/provider.dart';

import '../../core/auth/user_provider.dart';
import '../../models/account_transaction.dart';
import '../../services/account_transaction_service.dart';

class AddAccountTransactionScreen extends StatefulWidget {
  final String accountType;
  final int referenceId;
  final String accountName;

  const AddAccountTransactionScreen({
    super.key,
    required this.accountType,
    required this.referenceId,
    required this.accountName,
  });

  @override
  State<AddAccountTransactionScreen> createState() =>
      _AddAccountTransactionScreenState();
}

class _AddAccountTransactionScreenState
    extends State<AddAccountTransactionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();

  final AccountTransactionService _accountService =
      AccountTransactionService();
  String _transactionType = 'opening_balance';
  DateTime _selectedDate = DateTime.now();
  bool _isSaving = false;

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (date != null && mounted) {
      setState(() {
        _selectedDate = date;
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final amount = double.tryParse(
      _amountController.text.trim(),
    );

    if (amount == null || amount <= 0) {
      return;
    }

    final user = context.read<UserProvider>().currentUser;

    if (user == null || user.id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تعذر تحديد المستخدم الحالي'),
        ),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final now = DateTime.now().toIso8601String();

      final transaction = AccountTransaction(
        accountType: widget.accountType,
        referenceId: widget.referenceId,
        amount: amount,
        transactionType: _transactionType,
        transactionDate: _selectedDate.toIso8601String(),
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
        createdBy: user.id!,
        createdAt: now,
        updatedAt: now,
        syncId:
            'account_${DateTime.now().microsecondsSinceEpoch}',
      );

      await _accountService.addTransaction(transaction);

      if (!mounted) return;

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('حدث خطأ أثناء حفظ الحركة:\n$e'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  String _transactionTypeLabel(String value) {
    switch (value) {
      case 'opening_balance':
        return 'رصيد افتتاحي';
      case 'debt':
        return 'دين / مستحق جديد';
      case 'adjustment':
        return 'تسوية';
      default:
        return value;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSupplier = widget.accountType == 'supplier';

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'إضافة حركة - ${widget.accountName}',
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  isSupplier
                      ? 'المبلغ الموجب يزيد المبلغ المستحق للمورد.'
                      : 'المبلغ الموجب يزيد المبلغ المستحق على العميل.',
                  style: const TextStyle(
                    fontSize: 15,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _transactionType,
              decoration: const InputDecoration(
                labelText: 'نوع الحركة',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(
                  value: 'opening_balance',
                  child: Text('رصيد افتتاحي'),
                ),
                DropdownMenuItem(
                  value: 'debt',
                  child: Text('دين / مستحق جديد'),
                ),
                DropdownMenuItem(
                  value: 'adjustment',
                  child: Text('تسوية'),
                ),
              ],
              onChanged: _isSaving
                  ? null
                  : (value) {
                      if (value == null) return;
                      setState(() {
                        _transactionType = value;
                      });
                    },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _amountController,
              enabled: !_isSaving,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'المبلغ',
                suffixText: 'ريال',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                final amount = double.tryParse(
                  value?.trim() ?? '',
                );

                if (amount == null || amount <= 0) {
                  return 'أدخل مبلغًا صحيحًا أكبر من صفر';
                }

                return null;
              },
            ),
            const SizedBox(height: 16),
            InkWell(
              onTap: _isSaving ? null : _selectDate,
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'تاريخ الحركة',
                  border: OutlineInputBorder(),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${_selectedDate.year}/${_selectedDate.month.toString().padLeft(2, '0')}/${_selectedDate.day.toString().padLeft(2, '0')}',
                    ),
                    const Icon(Icons.calendar_month),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _notesController,
              enabled: !_isSaving,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'ملاحظات',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _isSaving ? null : _save,
              icon: _isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.save),
              label: Text(
                _isSaving
                    ? 'جاري الحفظ...'
                    : 'حفظ حركة الحساب',
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'نوع الحركة: ${_transactionTypeLabel(_transactionType)}',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
