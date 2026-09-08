class PermissionKeys {
  static const String clientsView = 'clients_view';
  static const String clientsAdd = 'clients_add';
  static const String clientsEdit = 'clients_edit';
  static const String clientsDelete = 'clients_delete';

  static const String salesView = 'sales_view';
  static const String salesAdd = 'sales_add';
  static const String salesEdit = 'sales_edit';
  static const String salesDelete = 'sales_delete';

  static const String suppliersView = 'suppliers_view';
  static const String suppliersAdd = 'suppliers_add';
  static const String suppliersEdit = 'suppliers_edit';
  static const String suppliersDelete = 'suppliers_delete';

  static const String driversView = 'drivers_view';
  static const String driversAdd = 'drivers_add';
  static const String driversEdit = 'drivers_edit';
  static const String driversDelete = 'drivers_delete';

  static const String clientStatementsView = 'client_statements_view';
  static const String supplierStatementsView = 'supplier_statements_view';

  static const String profitsView = 'profits_view';
  static const String pricesEdit = 'prices_edit';

  static const String usersManage = 'users_manage';
  static const String permissionsManage = 'permissions_manage';
}

class DefaultPermissions {
  static Map<String, bool> admin() {
    return {
      PermissionKeys.clientsView: true,
      PermissionKeys.clientsAdd: true,
      PermissionKeys.clientsEdit: true,
      PermissionKeys.clientsDelete: true,

      PermissionKeys.salesView: true,
      PermissionKeys.salesAdd: true,
      PermissionKeys.salesEdit: true,
      PermissionKeys.salesDelete: true,

      PermissionKeys.suppliersView: true,
      PermissionKeys.suppliersAdd: true,
      PermissionKeys.suppliersEdit: true,
      PermissionKeys.suppliersDelete: true,

      PermissionKeys.driversView: true,
      PermissionKeys.driversAdd: true,
      PermissionKeys.driversEdit: true,
      PermissionKeys.driversDelete: true,

      PermissionKeys.clientStatementsView: true,
      PermissionKeys.supplierStatementsView: true,

      PermissionKeys.profitsView: true,
      PermissionKeys.pricesEdit: true,

      PermissionKeys.usersManage: true,
      PermissionKeys.permissionsManage: true,
    };
  }

  static Map<String, bool> deputyManager() {
    return {
      PermissionKeys.clientsView: true,
      PermissionKeys.clientsAdd: true,
      PermissionKeys.clientsEdit: true,
      PermissionKeys.clientsDelete: true,

      PermissionKeys.salesView: true,
      PermissionKeys.salesAdd: true,
      PermissionKeys.salesEdit: true,
      PermissionKeys.salesDelete: true,

      PermissionKeys.suppliersView: true,
      PermissionKeys.suppliersAdd: true,
      PermissionKeys.suppliersEdit: true,
      PermissionKeys.suppliersDelete: true,

      PermissionKeys.driversView: true,
      PermissionKeys.driversAdd: true,
      PermissionKeys.driversEdit: true,
      PermissionKeys.driversDelete: true,

      PermissionKeys.clientStatementsView: true,
      PermissionKeys.supplierStatementsView: true,

      PermissionKeys.profitsView: true,
      PermissionKeys.pricesEdit: true,

      PermissionKeys.usersManage: false,
      PermissionKeys.permissionsManage: false,
    };
  }

  static Map<String, bool> driver() {
    return {
      PermissionKeys.clientsView: true,
      PermissionKeys.clientsAdd: true,
      PermissionKeys.clientsEdit: true,
      PermissionKeys.clientsDelete: false,

      PermissionKeys.salesView: true,
      PermissionKeys.salesAdd: true,
      PermissionKeys.salesEdit: false,
      PermissionKeys.salesDelete: false,

      PermissionKeys.suppliersView: true,
      PermissionKeys.suppliersAdd: false,
      PermissionKeys.suppliersEdit: false,
      PermissionKeys.suppliersDelete: false,

      PermissionKeys.driversView: true,
      PermissionKeys.driversAdd: false,
      PermissionKeys.driversEdit: false,
      PermissionKeys.driversDelete: false,

      PermissionKeys.clientStatementsView: true,
      PermissionKeys.supplierStatementsView: false,

      PermissionKeys.profitsView: false,
      PermissionKeys.pricesEdit: false,

      PermissionKeys.usersManage: false,
      PermissionKeys.permissionsManage: false,
    };
  }
}
