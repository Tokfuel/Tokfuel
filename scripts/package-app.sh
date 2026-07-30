#!/bin/bash

# SwiftPMの成果物からTokfuel.appを組み立てる共通処理。
# 呼び出し元はset -euo pipefailを設定し、必要なら事前に出力先を削除する。
package_tokfuel_app() {
  local build_dir="$1"
  local app_dir="$2"
  local project_dir="$3"
  local app_name="Tokfuel"

  mkdir -p "$app_dir/Contents/MacOS" "$app_dir/Contents/Resources"
  cp "$build_dir/$app_name" "$app_dir/Contents/MacOS/$app_name"
  cp "$project_dir/Info.plist" "$app_dir/Contents/Info.plist"
  cp -R "$build_dir/${app_name}_${app_name}.bundle" "$app_dir/Contents/Resources/"
  cp "$project_dir/assets/AppIcon.icns" "$app_dir/Contents/Resources/AppIcon.icns"
}
