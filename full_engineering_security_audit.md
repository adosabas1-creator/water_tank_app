# التقرير الشامل للتدقيق الهندسي والأمني - تطبيق خزانات الماء (شركة البرعي)
**تاريخ التقرير:** 30 سبتمبر 2026

---

### 1. ملخص تنفيذي (Executive Summary)
يُظهر المشروع هيكلية برمجية منظمة ونظيفة بناءً على تحليل `flutter analyze` مع غياب الأخطاء والتحذيرات (0 Errors, 0 Warnings). ومع ذلك، أظهر التدقيق العميق وجود عدة ثغرات ومخاطر أمنية متوسطة وعالية تتعلق بتخزين الجلسات في ذاكرة غير مشفرة (`SharedPreferences`)، وعدم تشفير ملفات النسخ الاحتياطي لقاعدة البيانات SQLite، واعتماد آلية مزامنة تعتمد على توقيت العميل (Last-Write-Wins) دون حماية ضد تلاعب بالساعات، فضلاً عن إتاحة قراءة عامة غير مصادقة لجدول `login_directory` في قواعد Firestore.

---

### 2. جدول الأخطاء الحرجة (Critical Bugs)
*لا توجد أخطاء حرجة تؤدي إلى تعطل كامل مفاجئ (Crash) في المسار الطبيعي للاستخدام اليومي.*

---

### 3. جدول الأخطاء العالية (High)
| الملف / السطر | الوصف | الأثر | التصحيح المقترح |
| :--- | :--- | :--- | :--- |
| `lib/services/backup_service.dart` (السطر 38 و 171) | النسخ الاحتياطية (اليدوية والتلقائية) تُنشأ بنسخ ملف SQLite خام (`.db`) دون تشفير. | كشف كامل لبيانات العملاء، المعاملات المالية، والمشتريات إذا وقع ملف النسخة الاحتياطية في يد شخص غير مصرح له. | تطبيق تشفير AES على محتوى ملف قاعدة البيانات قبل حفظه واستخدام مفتاح مشتق لتفكيكه عند الاستعادة. |
| `firestore.rules` (السطر 60) | السماح بقراءة عامة بدون مصادقة على مسار `login_directory/{username}` (`allow get: if true;`). | تمكين أي شخص من استطلاع أسماء المستخدمين المسجلين ومعرفاتهم في النظام دون تسجيل دخول. | تقييد القراءة لتكون مصادقة فقط أو تتطلب شروط تحقق أدق. |

---

### 4. جدول الأخطاء المتوسطة (Medium)
| الملف / السطر | الوصف | الأثر | التصحيح المقترح |
| :--- | :--- | :--- | :--- |
| `lib/core/auth/user_provider.dart` (السطر 31 و 115) | تخزين حالة الجلسة وبيانات المستخدم النشط في `SharedPreferences`. | بيانات الجلسة مخزنة بصيغة نصية واضحة (Plaintext) ويمكن الوصول إليها في أجهزة الـ Root. | استبدال `SharedPreferences` بمكتبة التخزين الآمن `flutter_secure_storage`. |
| `lib/core/network/sync_service.dart` (السطر 359 و 566) | الاعتماد على الطابع الزمني `updated_at` القادم من أجهزة العملاء لحل التعارضات (Last-Write-Wins). | عرضة للتلاعب في حال قام أحد المستخدمين بتغيير وقت وساعة جهازه المحلي يدوياً. | الاعتماد على توقيت الخادم (`FieldValue.serverTimestamp()`) في Firestore بدلاً من توقيت العميل المحلي. |
| `firestore.rules` (السطر 116, 131, 144, 158) | شروط التحديث تعتمد على مقارنة `request.resource.data.updated_at >= resource.data.updated_at`. | احتمالية حدوث سباق بيانات (Race Conditions) أو تجاوز للمقارنة في حال تلاعب العميل بالتاريخ. | إضافة التحقق من صحة صيغة وتاريخ الوعاء الزمني داخل قواعد الفايرسبورغ. |

---

### 5. جدول الأخطاء المنخفضة (Low)
| الملف / السطر | الوصف | الأثر | التصحيح المقترح |
| :--- | :--- | :--- | :--- |
| `lib/core/auth/auth_service.dart` (السطر 1370) | وجود دالة `_hashPassword` القديمة (`sha256`) بجانب نظام PBKDF2 الحديث. | عدم وضوح أو احتمالية استخدام دالة الهاش الأضعف بالخطأ في بعض المسارات القديمة. | إزالة دالة الهاش القديمة بالكامل والاعتماد حصرياً على PBKDF2-V2. |

---

### 6. قائمة كاملة بملاحظات `flutter analyze` (Infos)
1. `lib/core/auth/auth_service.dart:1412:13` - Use 'const' with the constructor (`prefer_const_constructors`).
2. `lib/services/backup_encryption_service.dart:112:13` - Use 'const' with the constructor (`prefer_const_constructors`).
3. `test/backup_encryption_test.dart:4:8` - Unused import: 'package:flutter/widgets.dart' (`unused_import`).
4. `test/backup_encryption_test.dart:7:8` - Can't use a relative path to import a library in 'lib' (`avoid_relative_lib_imports`).
5. `test/pbkdf2_test.dart:30:5` - Don't invoke 'print' in production code (`avoid_print`).
6. `test/pbkdf2_test.dart:31:5` - Don't invoke 'print' in production code (`avoid_print`).
7. `test/pbkdf2_test.dart:32:5` - Don't invoke 'print' in production code (`avoid_print`).
8. `tool/argon2_probe.dart:33:3` - Don't invoke 'print' in production code (`avoid_print`).
9. `tool/argon2_probe.dart:34:3` - Don't invoke 'print' in production code (`avoid_print`).
10. `tool/argon2_probe.dart:35:3` - Don't invoke 'print' in production code (`avoid_print`).
11. `tool/argon2_probe.dart:36:3` - Don't invoke 'print' in production code (`avoid_print`).
12. `tool/argon2_probe.dart:37:3` - Don't invoke 'print' in production code (`avoid_print`).
13. `tool/argon2_probe.dart:38:3` - Don't invoke 'print' in production code (`avoid_print`).
14. `tool/argon2_probe.dart:44:3` - Don't invoke 'print' in production code (`avoid_print`).
15. `tool/check_sales_sync.dart:11:3` - Don't invoke 'print' in production code (`avoid_print`).
16. `tool/check_sales_sync.dart:24:3` - Don't invoke 'print' in production code (`avoid_print`).
17. `tool/check_sales_sync.dart:27:5` - Don't invoke 'print' in production code (`avoid_print`).

---

### 7. تغطية الاختبارات (Test Coverage)
* **الموجود:** اختبارات أساسية لتشفير PBKDF2 وبعض اختبارات الوحدات (`test/pbkdf2_test.dart`, `test/backup_encryption_test.dart`, `test/widget_test.dart`).
* **الناقص:** تغطية اختبارات التكامل (Integration Tests) لخدمات المزامنة (`SyncService`) والمعاملات المالية المعقدة في `SaleService` و `DatabaseHelper`, واختبارات سيناريوهات انقطاع الاتصال.

---

### 8. فحص التبعيات (Dependency Check)
* حزم مثل `cloud_firestore`, `firebase_auth`, `connectivity_plus`, `sqflite` تملك تحديثات متوفرة (Upgradable/Resolvable), ورغم عدم وجود ثغرات حرجة معلنة في الإصدارات المستخدمة حالياً, يُنصح بإجراء تحديث دوري للحزم لضمان الحصول على الإصلاحات الأمنية.

---

### 9. فحص قواعد Firestore (`firestore.rules`)
* **نقاط القوة:** التحقق من الأدوار (`isAdmin`, `isManagement`, `hasPermission`) مفصل وجيد, مع وجود قاعدة رفض عامة في النهاية.
* **نقاط الضعف:**
  1. السماح بالقراءة المفتوحة لـ `login_directory/{username}` (`allow get: if true;`).
  2. الاعتماد على مقارنة حقول الوقت المقدمة من العميل في تحديثات السجلات.

---

### 10. قائمة مهام إصلاح مرتبة حسب الأولوية
1. **عالي جداً:** تعديل `BackupService` لتشفير ملفات النسخ الاحتياطي لقاعدة البيانات.
2. **عالي:** تعديل قواعد `firestore.rules` لإغلاق القراءة المفتوحة غير المصادقة لـ `login_directory`.
3. **متوسط:** نقل تخزين الجلسات والتوكنات من `SharedPreferences` إلى `FlutterSecureStorage`.
4. **متوسط:** تحسين آلية حل التعارضات في `SyncService` بالاعتماد على توقيت الخادم بدلاً من توقيت العميل.
5. **منخفض:** تنظيف ملفات الاختبار والأدوات من استيراد المسارات النسبية وتحذيرات `print`.

---

### 11. أهم 5 أخطاء يجب إصلاحها فوراً
1. **عدم تشفير النسخ الاحتياطية لقاعدة البيانات المحلية** (`BackupService`).
2. **القراءة العامة المفتوحة بدون مصادقة** لجدول `login_directory` في الفايرسبورغ.
3. **تخزين حالة الجلسة وبيانات المستخدم في `SharedPreferences`** بدلاً من التخزين المشفر الآمن.
4. **الاعتماد على ساعة العميل المحلي** في تسوية تعارضات المزامنة (`SyncService`).
5. **وجود دوال تشفير قديمة غير مستخدمة** قد تؤدي التباساً برمجياً (`_hashPassword` بشفرة SHA256 البسيطة).
