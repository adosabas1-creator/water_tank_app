# بناء التطبيق (GitHub Actions فقط)

لا تبنِ APK على Termux. البناء يتم عبر GitHub Actions بعد git push.

1. git push origin main
2. GitHub → Actions → Build Release APK
3. بعد النجاح حمّل Artifacts: release-apk و debug-symbols

الأسرار المستخدمة:
- ANDROID_KEYSTORE_BASE64
- ANDROID_KEYSTORE_PASSWORD
- ANDROID_KEY_ALIAS
- ANDROID_KEY_PASSWORD

استعادة النسخة السابقة:
git checkout v1.0-pre-fixes
