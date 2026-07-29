#!/bin/bash
# Tokfuel.app バンドルの組み立て（build.sh / release.sh / package_mas.sh 共通）。
# バンドルに入れるものの一覧をここ 1 箇所に集約する。追加リソースが増えたら
# このファイルだけを直せば全配布経路（開発・zip 配布・App Store）に反映される。
#
# 使い方: source scripts/lib/assemble_app.sh → assemble_app <build_dir> <app_dir>
#   build_dir … swift build の成果物ディレクトリ
#   app_dir   … 生成する Tokfuel.app のパス
# 呼び出し側で APP_NAME と PROJECT_DIR を定義しておくこと。
assemble_app() {
  local build_dir="$1" app_dir="$2"

  mkdir -p "$app_dir/Contents/MacOS" "$app_dir/Contents/Resources"
  cp "$build_dir/$APP_NAME" "$app_dir/Contents/MacOS/$APP_NAME"
  cp "$PROJECT_DIR/Info.plist" "$app_dir/Contents/Info.plist"
  # SwiftPM のリソースバンドル（retok スクリプト・locales）を同梱する
  cp -R "$build_dir/${APP_NAME}_${APP_NAME}.bundle" "$app_dir/Contents/Resources/"
  cp "$PROJECT_DIR/assets/AppIcon.icns" "$app_dir/Contents/Resources/AppIcon.icns"
}
