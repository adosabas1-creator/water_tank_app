# بناء التطبيق (GitHub Actions فقط)

لا تبنِ APK على Termux. البناء يتم عبر GitHub Actions بعد `git push`.

## خطوات البناء

1. `git push origin main`
2. GitHub → Actions → **Build Release APK**
3. بعد النجاح حمّل Artifacts: `release-apk` و `debug-symbols`

## الأسرار المطلوبة

| Secret | الوصف |
|--------|--------|
| `ANDROID_KEYSTORE_BASE64` | keystore بعد base64 |
| `ANDROID_KEYSTORE_PASSWORD` | كلمة مرور الـ store |
| `ANDROID_KEY_ALIAS` | اسم الـ alias |
| `ANDROID_KEY_PASSWORD` | كلمة مرور الـ key |
| `GOOGLE_SERVICES_JSON` | محتوى `google-services.json` كاملاً (نص JSON خام) |

استعادة نسخة سابقة: `git checkout v1.0-pre-fixes`
