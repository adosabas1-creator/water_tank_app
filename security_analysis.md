# تقرير الفحص الأمني الشامل - تطبيق خزانات الماء (شركة البرعي)

## 1. تفاصيل خوارزمية PBKDF2 وتخزين البيانات
* **الخوارزمية (Hash Algorithm):** HMAC-SHA256 (`crypto2.Hmac.sha256()`)
* **عدد التكرارات (Iterations):** `100,000`
* **طول الملح (Salt Length):** `16` بايت
* **طول المفتاح (Bits):** `256` بت
* **مكان تخزين كلمات المرور:** قاعدة بيانات **SQLite** المحلية (`users` جدول).
* **مكان تخزين الجلسات:** **SharedPreferences** (لا يوجد استخدام لـ `FlutterSecureStorage`).
* **تشفير النسخ الاحتياطية (`BackupService`):** **غير مشفرة** (يتم نسخ ملف قاعدة بيانات SQLite خام `.db` مباشرة).

---

## 2. جدول تقييم الأمان (النقطة | الحالة | المخاطرة)

| النقطة الأمنية | الحالة (التنفيذ الحالي) | المخاطرة والتقييم |
| :--- | :--- | :--- |
| **خوارزمية PBKDF2** | HMAC-SHA256, 100,000 تكرار, 16 بايت Salt, 256 بت | **منخفضة (آمنة):** ممتازة لمقاومة الهجمات وتحصين كلمات المرور. |
| **تخزين البيانات الحساسة** | كلمات المرور في SQLite، وتفاصيل الجلسة في **SharedPreferences** (بدون SecureStorage). | **متوسطة:** عرضة للاستخراج في حال حصول شخص على صلاحية Root في الجهاز. |
| **تشفير النسخ الاحتياطية** | النسخ الاحتياطية عبارة عن نسخ خام (`.db`) بدون أي تشفير. | **عالية:** كشف كامل لبيانات الشركة والمعاملات المالية إن وقع ملف النسخة الاحتياطية في يد شخص غير مصرح له. |
| **قواعد الفايرسبورغ (Firestore Rules)** | مدخلات `login_directory` تتيح قراءة عامة (`GET`)، والتحقق من التحديثات يعتمد على `updated_at` جهة العميل. | **متوسطة:** إمكانية كشف أسماء المستخدمين عبر `login_directory`، واحتمالية تلاعب العملاء بالتطبيقات العادية في التواقيت الزمنية. |

---

## 3. محتوى ملف `firestore.rules` كاملاً
```javascript
rules_version = '2';

service cloud.firestore {
  match /databases/{database}/documents {

    function signedIn() {
      return request.auth != null;
    }

    function userDirectoryPath() {
      return /databases/$(database)/documents/businesses/alborai_water_tank/user_directory/$(request.auth.uid);
    }

    function userExists() {
      return signedIn() && exists(userDirectoryPath());
    }

    function userDoc() {
      return get(userDirectoryPath());
    }

    function isAdmin() {
      return userExists() &&
        (
          userDoc().data.role == 'admin' ||
          userDoc().data.role == 'deputy_manager'
        );
    }

    function isManagement() {
      return userExists() &&
        (userDoc().data.role == 'admin' ||
         userDoc().data.role == 'deputy_manager');
    }

    function hasPermission(permission) {
      return userExists() &&
        (
          userDoc().data.role == 'admin' ||
          userDoc().data.role == 'deputy_manager' ||
          userDoc().data.get('permissions', {}).get(permission, false) == true
        );
    }

    match /businesses/alborai_water_tank/login_directory/{username} {
      allow get: if true;
      allow list: if false;

      allow create: if isAdmin() ||
        (
          signedIn() &&
          request.resource.data.get('username', '') == username &&
          request.resource.data.get('firebase_uid', '') == request.auth.uid &&
          request.resource.data.get('firebase_email', '') ==
            request.auth.token.email
        );

      allow update: if isAdmin() ||
        (
          signedIn() &&
          resource.data.get('firebase_uid', '') == request.auth.uid &&
          request.resource.data.get('firebase_uid', '') == request.auth.uid &&
          request.resource.data.get('username', '') == username &&
          request.resource.data.get('firebase_email', '') ==
            request.auth.token.email
        );

      allow delete: if isAdmin() ||
        (
          signedIn() &&
          resource.data.get('firebase_uid', '') == request.auth.uid
        );
    }

    match /businesses/alborai_water_tank/user_directory/{userId} {
      allow get: if signedIn() &&
        (userId == request.auth.uid || isAdmin());

      allow list: if isAdmin();

      allow create, update, delete: if isAdmin();
    }

    match /businesses/alborai_water_tank/clients/{document} {
      allow read: if
        hasPermission('clients_view') ||
        hasPermission('sales_view') ||
        hasPermission('client_statements_view');

      allow create: if hasPermission('clients_add');
      allow update: if hasPermission('clients_edit') &&
        request.resource.data.get('updated_at', '') >= resource.data.get('updated_at', '');
      allow delete: if hasPermission('clients_delete');
    }

    match /businesses/alborai_water_tank/suppliers/{document} {
      allow read: if
        hasPermission('suppliers_view') ||
        hasPermission('sales_view') ||
        hasPermission('supplier_statements_view') ||
        hasPermission('profits_view');

      allow create: if hasPermission('suppliers_add');
      allow update: if hasPermission('suppliers_edit') &&
        request.resource.data.get('updated_at', '') >= resource.data.get('updated_at', '');
      allow delete: if hasPermission('suppliers_delete');
    }

    match /businesses/alborai_water_tank/drivers/{document} {
      allow read: if hasPermission('drivers_view');

      allow create: if hasPermission('drivers_add');
      allow update: if hasPermission('drivers_edit') &&
        request.resource.data.get('updated_at', '') >= resource.data.get('updated_at', '');
      allow delete: if hasPermission('drivers_delete');
    }

    match /businesses/alborai_water_tank/sales/{document} {
      allow read: if
        hasPermission('sales_view') ||
        hasPermission('profits_view');

      allow create: if hasPermission('sales_add');
      allow update: if hasPermission('sales_edit') &&
        request.resource.data.get('updated_at', '') >= resource.data.get('updated_at', '');
      allow delete: if hasPermission('sales_delete');
    }

    match /businesses/alborai_water_tank/expenses/{document} {
      allow read: if
        hasPermission('profits_view') || isManagement();

      allow write: if isManagement();
    }

    match /businesses/alborai_water_tank/salaries/{document} {
      allow read, write: if isManagement();
    }

    match /businesses/alborai_water_tank/payments/{document} {
      allow read: if
        hasPermission('client_statements_view') ||
        hasPermission('supplier_statements_view');

      allow write: if isManagement();
    }

    match /businesses/alborai_water_tank/account_transactions/{document} {
      allow read: if
        hasPermission('client_statements_view') ||
        hasPermission('supplier_statements_view');

      allow write: if isManagement();
    }

    match /businesses/alborai_water_tank/tanks/{document} {
      allow read, write: if isManagement();
    }

    match /businesses/alborai_water_tank/filling_operations/{document} {
      allow read, write: if isManagement();
    }

    match /businesses/alborai_water_tank/purchase_invoices/{document} {
      allow read: if
        hasPermission('profits_view') || isManagement();

      allow write: if isManagement();
    }

    match /businesses/alborai_water_tank/purchase_items/{document} {
      allow read: if
        hasPermission('profits_view') || isManagement();

      allow write: if isManagement();
    }

    match /businesses/alborai_water_tank/inventory_layers/{document} {
      allow read: if
        hasPermission('profits_view') || isManagement();

      allow write: if isManagement();
    }

    match /businesses/alborai_water_tank/sale_inventory_allocations/{document} {
      allow read: if
        hasPermission('profits_view') || isManagement();

      allow write: if isManagement();
    }

    match /{document=**} {
      allow read, write: if false;
    }
  }
}
```
