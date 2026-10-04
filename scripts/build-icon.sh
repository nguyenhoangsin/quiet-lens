#!/bin/zsh
set -euo pipefail
script_directory=${0:A:h}
project_directory=${script_directory:h}
iconset="$project_directory/.build/AppIcon.iconset"
mkdir -p "$iconset"
for size in 16 32 128 256 512; do
    sips -z "$size" "$size" "$project_directory/Support/AppIcon.png" --out "$iconset/icon_${size}x${size}.png" >/dev/null
    double_size=$((size * 2))
    sips -z "$double_size" "$double_size" "$project_directory/Support/AppIcon.png" --out "$iconset/icon_${size}x${size}@2x.png" >/dev/null
done
# PNG-backed ICNS records preserve the generated alpha at every resolution.
# Packing locally also works where iconutil's system service is unavailable.
python3 - "$iconset" "$project_directory/Support/AppIcon.icns" <<'PY'
import pathlib, struct, sys
root = pathlib.Path(sys.argv[1])
records = [
    (b'icp4', 'icon_16x16.png'), (b'icp5', 'icon_32x32.png'),
    (b'icp6', 'icon_32x32@2x.png'), (b'ic07', 'icon_128x128.png'),
    (b'ic08', 'icon_256x256.png'), (b'ic09', 'icon_512x512.png'),
    (b'ic10', 'icon_512x512@2x.png'), (b'ic11', 'icon_16x16@2x.png'),
    (b'ic12', 'icon_32x32@2x.png'), (b'ic13', 'icon_128x128@2x.png'),
    (b'ic14', 'icon_256x256@2x.png'),
]
parts = []
for kind, name in records:
    data = (root / name).read_bytes()
    parts.append(kind + struct.pack('>I', len(data) + 8) + data)
body = b''.join(parts)
pathlib.Path(sys.argv[2]).write_bytes(b'icns' + struct.pack('>I', len(body) + 8) + body)
PY
