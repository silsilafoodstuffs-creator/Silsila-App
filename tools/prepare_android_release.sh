#!/usr/bin/env bash
set -euo pipefail

: "${ANDROID_KEYSTORE_BASE64:?Missing ANDROID_KEYSTORE_BASE64 secret}"
: "${ANDROID_KEYSTORE_PASSWORD:?Missing ANDROID_KEYSTORE_PASSWORD secret}"

ICON="assets/images/silsila_icon_App.png"
test -s "$ICON"
python3 - "$ICON" <<'PY'
import struct, sys
from pathlib import Path
p = Path(sys.argv[1])
data = p.read_bytes()
if data[:8] != b"\x89PNG\r\n\x1a\n":
    raise SystemExit("Silsila launcher source is not a valid PNG")
width, height = struct.unpack(">II", data[16:24])
if width < 192 or height < 192:
    raise SystemExit(f"Silsila launcher source is too small: {width}x{height}")
print(f"Verified Silsila launcher source: {width}x{height}")
PY

# Always regenerate Android launcher resources from the branded Silsila artwork.
dart run flutter_launcher_icons
for density in mdpi hdpi xhdpi xxhdpi xxxhdpi; do
  icon="android/app/src/main/res/mipmap-${density}/ic_launcher.png"
  test -s "$icon"
done

echo "$ANDROID_KEYSTORE_BASE64" | base64 --decode > android/app/silsila-upload-key.jks
test -s android/app/silsila-upload-key.jks
cat > android/key.properties <<EOF
storePassword=$ANDROID_KEYSTORE_PASSWORD
keyPassword=$ANDROID_KEYSTORE_PASSWORD
keyAlias=silsila
storeFile=silsila-upload-key.jks
EOF

python3 - <<'PY'
from pathlib import Path
import re

p = Path("android/app/build.gradle.kts")
if not p.exists():
    raise SystemExit("Android Gradle Kotlin file not found")
s = p.read_text()

imports = "import java.util.Properties\nimport java.io.FileInputStream\n"
if "import java.util.Properties" not in s:
    s = imports + s

ndk = '    ndkVersion = "27.0.12077973"'
s, count = re.subn(r'(?m)^[ \t]*ndkVersion[ \t]*=[^\r\n]*', ndk, s)
if count == 0:
    if "android {" not in s:
        raise SystemExit("Android configuration block not found")
    s = s.replace("android {", "android {\n" + ndk, 1)

props = """val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

"""
if "val keystoreProperties = Properties()" not in s:
    s = s.replace("android {", props + "android {", 1)

signing = """    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties["keyAlias"] as String
            keyPassword = keystoreProperties["keyPassword"] as String
            storeFile = file(keystoreProperties["storeFile"] as String)
            storePassword = keystoreProperties["storePassword"] as String
        }
    }

"""
if 'create("release")' not in s:
    marker = "    buildTypes {"
    if marker not in s:
        raise SystemExit("Build types block not found")
    s = s.replace(marker, signing + marker, 1)

# Never permit the release variant to silently inherit Flutter's debug key.
pattern = r'(buildTypes\s*\{\s*release\s*\{.*?signingConfig\s*=\s*signingConfigs\.getByName\("debug"\))'
s, changed = re.subn(pattern, r'\1', s, count=1, flags=re.S)
if changed:
    s = s.replace('signingConfig = signingConfigs.getByName("debug")',
                  'signingConfig = signingConfigs.getByName("release")', 1)
elif 'signingConfig = signingConfigs.getByName("release")' not in s:
    pattern = r'(buildTypes\s*\{\s*release\s*\{)'
    s, changed = re.subn(pattern, r'\1\n            signingConfig = signingConfigs.getByName("release")', s, count=1, flags=re.S)
    if not changed:
        raise SystemExit("Could not bind release build type to permanent signing key")

p.write_text(s)
print("Release signing and Android NDK configuration verified")
PY

# Fail early if the release signing configuration was not actually generated.
grep -q 'create("release")' android/app/build.gradle.kts
grep -q 'signingConfig = signingConfigs.getByName("release")' android/app/build.gradle.kts
