# Android: установка и сборка

## Локальная тестовая сборка

`build/fortis-debug.apk` — ARM64 APK, версия 0.1.1, versionCode 2, package ID `com.fortisgames.deepwaters`, minSdk 24, targetSdk 36. Движок: Godot 4.6.3 Standard, Compatibility / OpenGL ES 3.0. Ориентация — горизонтальная. Интернет, микрофон, аккаунт и сервер игре не нужны; манифест запрашивает только `android.permission.VIBRATE`.

На телефоне: скопировать APK, открыть через файловый менеджер, разрешить этому приложению установку неизвестных приложений и установить. Либо включить отладку по USB:

```bash
adb devices
adb install -r build/fortis-debug.apk
```

При `INSTALL_FAILED_UPDATE_INCOMPATIBLE` установлен пакет с другой подписью. Сначала сохраните нужные пользовательские данные; затем удалите прежнее приложение и установите новое. Удаление приложения удаляет `user://`.

Debug-ключ в исходниках отсутствует. Локальная утилита создаёт временный стандартный Android debug-ключ вне проекта. Следующая машина/CI создаст свой ключ, поэтому такие APK не гарантируют возможность обновлять друг друга поверх установки.

## Инструменты

- Godot **4.6.3 Standard** Linux x86_64 и export templates **4.6.3.stable**.
- JDK 17+; локальная сборка выполнена с OpenJDK 21.
- Android command-line tools, `platform-tools`, `platforms;android-36`, `build-tools;36.0.0`.
- Достаточно non-Gradle APK export. NDK, Gradle и Android source template для этих presets не требуются.

```bash
sdkmanager 'platform-tools' 'platforms;android-36' 'build-tools;36.0.0'
sdkmanager --licenses
```

Получите архив движка и `Godot_v4.6.3-stable_export_templates.tpz` из официального релиза Godot. Поместите `android_debug.apk`, `android_release.apk`, `version.txt` из каталога `templates/` в стандартный каталог Godot `export_templates/4.6.3.stable/`. Точный способ установки есть в workflow.

Укажите путь SDK в `ANDROID_SDK_ROOT` или `ANDROID_HOME`, JDK — в `JAVA_HOME`, затем:

```bash
python3 tools/configure_android.py
mkdir -p build
godot --headless --path . --editor --quit > build/import.log 2>&1
python3 tools/check_log.py build/import.log
godot --headless --path . --fixed-fps 30 --script res://tests/run_tests.gd > build/tests.log 2>&1
python3 tools/check_log.py build/tests.log
godot --headless --path . --fixed-fps 30 --script res://tests/scenario_test.gd > build/acceptance.log 2>&1
python3 tools/check_log.py build/acceptance.log
godot --headless --path . --fixed-fps 30 --script res://tests/navigation_test.gd > build/navigation.log 2>&1
python3 tools/check_log.py build/navigation.log
godot --headless --path . --export-debug 'Android Debug' build/fortis-debug.apk > build/export.log 2>&1
python3 tools/check_log.py build/export.log
```

Для пути с пробелами используйте кавычки. `configure_android.py` настраивает Android-пути в пользовательских EditorSettings Godot, сохраняя остальные настройки. Закройте редактор перед запуском утилиты, чтобы он не перезаписал файл настроек.

Проверка подписи и целостности:

```bash
"$ANDROID_HOME/build-tools/36.0.0/apksigner" verify --verbose build/fortis-debug.apk
sha256sum build/fortis-debug.apk
```

В ограниченной Linux-среде задайте отдельные доступные для записи `XDG_DATA_HOME`, `XDG_CONFIG_HOME`, `XDG_CACHE_HOME` перед всеми командами Godot и утилитой настройки. Это переносит сохранения, шаблоны и настройки в выделенный каталог, не меняя домашний каталог пользователя.

## GitHub Actions

1. Создать или выбрать GitHub-репозиторий и отправить исходники проекта.
2. `.github/workflows/android.yml` выполняется на push, pull request и вручную.
3. Дождаться зелёного запуска **Android debug APK**.
4. Открыть его страницу → **Artifacts → fortis-android-debug-N**. В ZIP будут APK, SHA256SUMS и логи.

Workflow использует `set -euo pipefail`, отдельно проверяет ошибки в логах Godot и итоговые строки тестов: редактор иногда возвращает код 0 даже при ошибках скриптов. Выполняется проверка подписи APK. Страница сборок проекта: https://github.com/deadllypleasee-hub/Flothh/actions/workflows/android.yml. Фактический статус CI проверяйте по конкретному запуску.

## Подписанный release APK

Настройте GitHub Environment `release` и секреты:

| Secret | Значение |
|---|---|
| ANDROID_KEYSTORE_BASE64 | Base64 содержимого вашего release keystore |
| ANDROID_KEY_ALIAS | Alias ключа |
| ANDROID_KEY_PASSWORD | Пароль хранилища/ключа; для этого preset используйте одинаковый пароль |

Резервную копию release keystore и пароля храните вне GitHub и проекта. Не используйте debug-ключ. `.github/workflows/release.yml` читает секреты через поддерживаемые Godot переменные `GODOT_ANDROID_KEYSTORE_RELEASE_PATH`, `GODOT_ANDROID_KEYSTORE_RELEASE_USER`, `GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD`, удаляет временный ключ и выдаёт подписанный APK candidate. Публикацию он не делает.

Перед каждым обновлением увеличьте `version/code` в обоих presets и обновите `version/name` и `config/version`. Для AAB понадобится отдельный Gradle preset, Android source template и его проверка: текущие workflows выпускают APK.
