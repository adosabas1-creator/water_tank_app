class Salary {
  final int? id;
  final int employeeId;
  final String month;
  final double baseSalary;
  final double advances;
  final double deductions;
  final double netSalary;
  final String? paymentDate;
  final String? notes;
  final int createdBy;
  final String createdAt;
  final String updatedAt;
  final bool isDeleted;
  final bool isSynced;

  Salary({
    this.id,
    required this.employeeId,
    required this.month,
    required this.baseSalary,
    this.advances = 0,
    this.deductions = 0,
    required this.netSalary,
    this.paymentDate,
    this.notes,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    this.isDeleted = false,
    this.isSynced = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'employee_id': employeeId,
      'month': month,
      'base_salary': baseSalary,
      'advances': advances,
      'deductions': deductions,
      'net_salary': netSalary,
      'payment_date': paymentDate,
      'notes': notes,
      'created_by': createdBy,
      'created_at': createdAt,
      'updated_at': updatedAt,
      'is_deleted': isDeleted ? 1 : 0,
      'is_synced': isSynced ? 1 : 0,
    };
  }

  factory Salary.fromMap(Map<String, dynamic> map) {
    return Salary(
      id: map['id'],
      employeeId: map['employee_id'],
      month: map['month'],
      baseSalary: map['base_salary'],
      advances: map['advances'],
      deductions: map['deductions'],
      netSalary: map['net_salary'],
      paymentDate: map['payment_date'],
      notes: map['notes'],
      createdBy: map['created_by'],
      createdAt: map['created_at'],
      updatedAt: map['updated_at'],
      isDeleted: map['is_deleted'] == 1,
      isSynced: map['is_synced'] == 1,
    );
  }
}
