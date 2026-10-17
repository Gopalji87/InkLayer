#!/bin/bash
# Double-click this file to build InkLayer.dmg
cd "$(dirname "$0")"
if ! xcode-select -p >/dev/null 2>&1; then
  echo "Apple Command Line Tools install ho rahe hain. Popup mein 'Install' dabaiye,"
  echo "install khatam hone ke baad is file ko dobara double-click kijiye."
  xcode-select --install
  read -n 1 -s -r -p "Press any key to close..."
  exit 1
fi
chmod +x build_app.sh
./build_app.sh && open build
echo
read -n 1 -s -r -p "Done! Press any key to close..."
