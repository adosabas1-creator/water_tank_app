# التقرير النهائي للتدقيق الهندسي والأمني - تطبيق خزانات الماء (شركة البرعي)
**تاريخ التقرير:** 30 سبتمبر 2026

---

## 1. تحليل الأداء (Performance Analysis)
* **حالة القياس:** تعذر تشغيل `flutter run --profile` لقياس زمن الإقلاع الدقيق، وحجم قاعدة البيانات الفعلي، واستهلاك الذاكرة عبر DevTools نظرًا لأن بيئة العمل الحالية (Termux) هي بيئة سطر comandos خالية من واجهة رسومية (Headless) وتفتقر إلى محاكي جهاز أندرويد حقيقي أو خادم DevTools نشط.
* **التقدير الهندسي:** الإقلاع يعتمد على فتح قاعدة بيانات SQLite محلية وقراءة SharedPreferences وهو خفيف بطبيعته (أقل من ثانية)، واستهلاك الذاكرة منخفض ومنتظم.

---

## 2. فحص الأسرار (Secrets Scan)
* **الأمر المستخدم:**
  ```bash
  grep -rE "(api_key|secret|password|token)\s*[:=]" lib/
  ```
* **المخرجات الفعلية:**
  ```text
  lib/core/auth/auth_service.dart:      password: password,
  lib/core/auth/auth_service.dart:        password: password,
  lib/core/auth/auth_service.dart:            password: password,
  lib/core/auth/auth_service.dart:        password: password,
  lib/core/auth/auth_service.dart:          password: currentPassword,
  lib/core/auth/auth_service.dart:      password: password,
  lib/screens/users/users_screen.dart:              final password = passwordCtrl.text;
  lib/screens/users/users_screen.dart:                  password: password,
  lib/screens/users/users_screen.dart:                final password = passwordCtrl.text;
  ```
* **النتيجة:** لا توجد مفاتيح API سرية أو كلمات مرور صريحة (Hardcoded API Keys or Secrets) داخل الكود المصدري؛ الاستخدامات تقتصر على متغيرات دوال المصادقة وإدخال كلمات المرور للمستخدمين.

---

## 3. تغطية الاختبارات البديلة (Test Coverage Alternatives)
بسبب فشل تشغيل `flutter test` في بيئة Termux (بسبب نقص مكتبة `libvk_swiftshader.so` لمحرك اختبارات Flutter)، تُعتبر الحلول البديلة لضمان تشغيل الاختبارات واستخراج التغطية هي:
1. **GitHub Actions Workflow:** إنشاء مسار CI/CD على GitHub لتشغيل الاختبارات تلقائياً على كل Commit/PR في بيئة Ubuntu افتراضية متكاملة.
2. **Docker:** استخدام حاوية Docker تحتوي على بيئة Flutter SDK الرسمية والمتكاملة مع مكتبات العرض الرسومي headless.
3. **جهاز تطوير خارجي:** نقل المستودع لجهاز ويندوز/ماك/لينكس يحتوي على بيئة تطوير Flutter كاملة وتشغيل الأوامر هناك.

---

## 4. تقييم مخاطر التحديثات الرئيسية للتبعيات (Dependency Risks)
* **`connectivity_plus` (من الإصدار 6 إلى 7):**
  * *المخاطر:* قد تتغير واجهة الاستماع لحالة الاتصال (`onConnectivityChanged`) أو نوع المخرجات (من `ConnectivityResult` إلى قائمة `List<ConnectivityResult>`).
  * *ما قد ينكسر:* ملفات خدمة المزامنة `SyncService` والتحقق من الاتصال في `ConnectivityService`.
* **`file_picker` (من الإصدار 12 إلى 13):**
  * *المخاطر:* تحديثات في توقيع الدوال أو سلوك منصات سطح المكتب والهاتف عند اختيار ملفات النسخ الاحتياطي.
  * *ما قد ينكسر:* وظائف التصدير والاستيراد في `BackupService`.
* **`intl` (من الإصدار 0.18 إلى 0.20):**
  * *المخاطر:* تحديثات في تنسيق التواريخ، الأرقام، والعملات.
  * *ما قد ينكسر:* تقارير الطباعة بصيغة PDF وشاشات كشف حسابات العملاء والموردين.

---

## 5. مقترح مسار CI/CD لبناء APK موقّع (.github/workflows/build_apk.yml)
إليك قالب متكامل لـ GitHub Actions لبناء التطبيق تلقائياً:

```yaml
name: Build Release APK

on:
  push:
    branches: [ main ]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Set up Java
        uses: actions/setup-java@v3
        with:
          distribution: 'zulu'
          java-version: '17'

      - name: Set up Flutter
        uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.19.x'
          channel: 'stable'

      - name: Install Dependencies
        run: flutter pub get

      - name: Run Static Analysis
        run: flutter analyze

      - name: Build Release APK
        run: flutter build apk --release
```

---

## 6. دورة حياة الجلسة وإدارة الخمول (Session Lifecycle & Inactivity Timeout)
* **التوصية:** اعتماد فترة خمول مقترحة **15 دقيقة** (`15 minutes`) لإبطال الجلسة تلقائياً وتسجيل خروج المستخدم.
* **كيفية التنفيذ:**
  1. إنشاء `Timer` في مستوى التطبيق (App Lifecycle أو عبر `WidgetsBindingObserver`) لإعادة ضبط العداد عند كل تفاعل للمستخدم (`PointerEvent` / Tap / Scroll).
  2. عند انتهاء الـ 15 دقيقة دون تفاعل، يتم استدعاء دالة تسجيل الخروج (`AuthService.signOut()` أو مسح الجلسة) وإعادة توجيه المستخدم لشاشة تسجيل الدخول مع رسالة تنبيه بانتهاء الجلسة حرصاً على الأمان المالي وسرية حسابات العملاء.
