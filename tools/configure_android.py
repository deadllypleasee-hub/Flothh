#!/usr/bin/env python3
"""Configure local Godot paths. Private keys stay outside the project."""
import os
import pathlib
import re
import subprocess
import sys

sdk = os.environ.get("ANDROID_SDK_ROOT", os.environ.get("ANDROID_HOME", ""))
java = os.environ.get("JAVA_HOME", "/usr/lib/jvm/java-21-openjdk-amd64")
if not sdk or not pathlib.Path(sdk, "build-tools", "36.0.0", "apksigner").is_file():
    sys.exit("Install Android SDK build-tools;36.0.0 and set ANDROID_SDK_ROOT")
data = pathlib.Path(os.environ.get("XDG_DATA_HOME", pathlib.Path.home() / ".local/share"))
config = pathlib.Path(os.environ.get("XDG_CONFIG_HOME", pathlib.Path.home() / ".config"))
key = pathlib.Path(os.environ.get("ANDROID_USER_HOME", data / "fortis-android")) / "debug.keystore"
key.parent.mkdir(parents=True, exist_ok=True)
if not key.exists():
    subprocess.run([str(pathlib.Path(java, "bin/keytool")), "-genkeypair", "-keystore", str(key),
                    "-storepass", "android", "-alias", "androiddebugkey", "-keypass", "android",
                    "-dname", "CN=Android Debug,O=FORTIS GAMES,C=XX", "-keyalg", "RSA",
                    "-keysize", "2048", "-validity", "10000"], check=True, stdout=subprocess.DEVNULL)
settings = config / "godot/editor_settings-4.6.tres"
settings.parent.mkdir(parents=True, exist_ok=True)
def quoted(value):
    import json
    return json.dumps(str(value))
content = settings.read_text(encoding="utf-8") if settings.exists() else '[gd_resource type="EditorSettings" format=3]\n\n[resource]\n'
properties = {"android_sdk_path": sdk, "java_sdk_path": java, "debug_keystore": key,
              "debug_keystore_user": "androiddebugkey", "debug_keystore_pass": "android"}
for prop, value in properties.items():
    name = "export/android/" + prop
    line = name + " = " + quoted(value)
    pattern = r"^" + re.escape(name) + r"\s*=.*$"
    if re.search(pattern, content, flags=re.M):
        content = re.sub(pattern, lambda _: line, content, flags=re.M)
    else:
        content = content.rstrip() + "\n" + line + "\n"
settings.write_text(content, encoding="utf-8")
print("Godot Android SDK and debug signing configured outside the repository.")
