#!/usr/bin/env bash
set -e

# ==============================================================================
# AXIS Linux Desktop & Icon Installer
# ==============================================================================
# Registers AXIS with the Ubuntu / GNOME desktop environment so that:
# 1. It appears in the Applications menu / Dash ("Show Applications").
# 2. It displays the official AXIS high-resolution logo in the dock, app list,
#    and Alt+Tab task switcher.
# 3. Running instances match the launcher icon properly via StartupWMClass.
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MOBILE_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
ROOT_DIR="$(cd "${MOBILE_DIR}/.." && pwd)"

BUNDLE_DIR="${MOBILE_DIR}/build/linux/x64/release/bundle"
EXECUTABLE="${BUNDLE_DIR}/axis"
MASTER_LOGO_PNG="${ROOT_DIR}/Logo.png"
MASTER_LOGO_SVG="${ROOT_DIR}/axis_logo.svg"

APP_ID="com.axis.axis"
DESKTOP_DIR="${HOME}/.local/share/applications"
ICON_BASE_DIR="${HOME}/.local/share/icons/hicolor"

case "$1" in
  --uninstall)
    echo "==> Uninstalling AXIS desktop launcher..."
    rm -f "${DESKTOP_DIR}/${APP_ID}.desktop"
    rm -f "${ICON_BASE_DIR}/scalable/apps/${APP_ID}.svg"
    for s in 16 24 32 48 64 128 256 512; do
      rm -f "${ICON_BASE_DIR}/${s}x${s}/apps/${APP_ID}.png"
    done
    if command -v update-desktop-database >/dev/null 2>&1; then
      update-desktop-database "${DESKTOP_DIR}" 2>/dev/null || true
    fi
    if command -v gtk-update-icon-cache >/dev/null 2>&1; then
      gtk-update-icon-cache -f -t "${ICON_BASE_DIR}" 2>/dev/null || true
    fi
    echo "==> Uninstalled successfully."
    exit 0
    ;;
esac

echo "==> Setting up AXIS desktop launcher and application icons..."

# Ensure target directories exist
mkdir -p "${DESKTOP_DIR}"
mkdir -p "${ICON_BASE_DIR}"

# 1. Install standard hicolor icons
echo "==> Generating and installing icon sizes (16x16 to 512x512 + SVG)..."
python3 - <<EOF
import os
from PIL import Image

logo_path = "${MASTER_LOGO_PNG}"
svg_path = "${MASTER_LOGO_SVG}"
icon_base = "${ICON_BASE_DIR}"
app_id = "${APP_ID}"

sizes = [16, 24, 32, 48, 64, 128, 256, 512]
if os.path.exists(logo_path):
    img = Image.open(logo_path)
    for s in sizes:
        target_dir = os.path.join(icon_base, f"{s}x{s}/apps")
        os.makedirs(target_dir, exist_ok=True)
        resized = img.resize((s, s), Image.Resampling.LANCZOS)
        resized.save(os.path.join(target_dir, f"{app_id}.png"), "PNG")

if os.path.exists(svg_path):
    scalable_dir = os.path.join(icon_base, "scalable/apps")
    os.makedirs(scalable_dir, exist_ok=True)
    with open(svg_path, "r") as src, open(os.path.join(scalable_dir, f"{app_id}.svg"), "w") as dst:
        dst.write(src.read())
EOF

# 2. Generate and install desktop file
echo "==> Writing ${DESKTOP_DIR}/${APP_ID}.desktop..."
cat <<EOF > "${DESKTOP_DIR}/${APP_ID}.desktop"
[Desktop Entry]
Version=1.0
Type=Application
Name=Axis
GenericName=Productivity Cockpit
Comment=Next-generation personal productivity cockpit, task matrix, and habit tracker
Exec=${EXECUTABLE}
Icon=${APP_ID}
Terminal=false
Categories=Office;ProjectManagement;
Keywords=Task;Todo;Axis;Productivity;Habits;Calendar;Cockpit;
StartupWMClass=${APP_ID}
StartupNotify=true
EOF

chmod +x "${DESKTOP_DIR}/${APP_ID}.desktop"

# 3. Update desktop database and icon cache
echo "==> Refreshing system application database & icon cache..."
if command -v update-desktop-database >/dev/null 2>&1; then
  update-desktop-database "${DESKTOP_DIR}" 2>/dev/null || true
fi

if command -v gtk-update-icon-cache >/dev/null 2>&1; then
  gtk-update-icon-cache -f -t "${ICON_BASE_DIR}" 2>/dev/null || true
fi

echo "==> Done! AXIS is now available in your Ubuntu Applications menu with its official icon."
echo "    Launcher: ${DESKTOP_DIR}/${APP_ID}.desktop"
echo "    Binary:   ${EXECUTABLE}"

