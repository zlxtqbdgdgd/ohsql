#!/usr/bin/env bash
#
# OpenHarness-SQL 卸载脚本 · macOS
#
# 删除：~/.openharness-sql/{bin,versions,current,cache}
# 保留：~/.openharness-sql/{settings.json,sessions,plans,reports,oops-bench}
#       —— 这些是用户数据，需要用户自己决定是否清
#
# 如要完全移除所有状态，手动：rm -rf ~/.openharness-sql

set -euo pipefail

CONFIG_DIR="$HOME/.openharness-sql"

if [ ! -d "$CONFIG_DIR" ]; then
  echo "Nothing to uninstall ($CONFIG_DIR not found)."
  exit 0
fi

for sub in bin versions current cache; do
  target="$CONFIG_DIR/$sub"
  if [ -e "$target" ] || [ -L "$target" ]; then
    echo "rm -rf $target"
    rm -rf "$target"
  fi
done

echo ""
echo "✅ ohsql runtime removed."
echo "   User data preserved: $CONFIG_DIR/{settings.json,sessions,plans,reports,oops-bench}"
echo "   To fully remove: rm -rf $CONFIG_DIR"
