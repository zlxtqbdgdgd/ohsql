#!/usr/bin/env bash
#
# OpenHarness-SQL 安装脚本 · macOS
#
#   curl -fsSL https://raw.githubusercontent.com/zlxtqbdgdgd/ohsql/main/install.sh | bash
#
# 流程：
#   1. 检测平台 = darwin-arm64 | darwin-x64（其他平台暂不支持）
#   2. 检查 Node.js >= 18
#   3. 拿最新 release tag（或 OHSQL_VERSION 覆写）
#   4. 下载 tarball + SHA256SUMS，sha256 校验
#   5. 解压到 ~/.ohsql/versions/<ver>/
#   6. 原子切换 ~/.ohsql/current 符号链接
#   7. 写入 ~/.ohsql/bin/ohsql shim
#   8. 检测 PATH，必要时提示加 export

set -euo pipefail

REPO="zlxtqbdgdgd/ohsql"
CONFIG_DIR="$HOME/.ohsql"
VERSIONS_DIR="$CONFIG_DIR/versions"
BIN_DIR="$CONFIG_DIR/bin"
CURRENT_LINK="$CONFIG_DIR/current"
CACHE_DIR="$CONFIG_DIR/cache/downloads"

info()  { printf "\033[1;36m==>\033[0m %s\n" "$*"; }
warn()  { printf "\033[1;33m!!\033[0m %s\n" "$*" >&2; }
die()   { printf "\033[1;31mxx\033[0m %s\n" "$*" >&2; exit 1; }

# 1. 平台检测（目前仅 Apple Silicon；Intel Mac / Linux / Windows 后续版本）
UNAME_S=$(uname -s)
UNAME_M=$(uname -m)
case "$UNAME_S-$UNAME_M" in
  Darwin-arm64) PLAT="darwin-arm64" ;;
  *) die "Unsupported platform: $UNAME_S-$UNAME_M (目前仅支持 darwin-arm64 / Apple Silicon)" ;;
esac
info "Platform: $PLAT"

# 2. Node.js 检查
if ! command -v node >/dev/null 2>&1; then
  die "Node.js not found. Install via 'brew install node' or https://nodejs.org (need >= 18)."
fi
NODE_MAJOR=$(node -p "process.versions.node.split('.')[0]")
if [ "$NODE_MAJOR" -lt 18 ]; then
  die "Node.js $(node -v) is too old. Need >= 18."
fi
info "Node.js $(node -v) ✓"

# 3. 目标版本
if [ -n "${OHSQL_VERSION:-}" ]; then
  VERSION="${OHSQL_VERSION#v}"
  info "Using pinned version: v$VERSION"
else
  info "Fetching latest release tag from GitHub"
  TAG=$(curl -fsSL "https://api.github.com/repos/$REPO/releases/latest" \
    | sed -n 's/.*"tag_name": *"\(v[^"]*\)".*/\1/p' | head -n1)
  [ -z "$TAG" ] && die "Could not resolve latest release tag (GitHub API unreachable?)."
  VERSION="${TAG#v}"
  info "Latest: v$VERSION"
fi

# 4. 下载 + 校验
TARBALL="openharness-sql-${VERSION}-${PLAT}.tar.gz"
TARBALL_URL="https://github.com/$REPO/releases/download/v${VERSION}/${TARBALL}"
SUMS_URL="https://github.com/$REPO/releases/download/v${VERSION}/SHA256SUMS"

mkdir -p "$CACHE_DIR"
TARBALL_PATH="$CACHE_DIR/$TARBALL"
SUMS_PATH="$CACHE_DIR/SHA256SUMS-$VERSION"

info "Downloading $TARBALL"
curl -fsSL "$TARBALL_URL" -o "$TARBALL_PATH"
curl -fsSL "$SUMS_URL" -o "$SUMS_PATH"

info "Verifying sha256"
EXPECTED=$(grep " $TARBALL\$" "$SUMS_PATH" | awk '{print $1}')
[ -z "$EXPECTED" ] && die "SHA256SUMS missing entry for $TARBALL"
ACTUAL=$(shasum -a 256 "$TARBALL_PATH" | awk '{print $1}')
[ "$EXPECTED" != "$ACTUAL" ] && die "sha256 mismatch: expected $EXPECTED, got $ACTUAL"

# 5. 解压到 versions/<ver>/
DEST="$VERSIONS_DIR/$VERSION"
mkdir -p "$DEST"
info "Extracting to $DEST"
tar -xzf "$TARBALL_PATH" -C "$DEST"

# 6. 原子切换 current
TMP_LINK="$CURRENT_LINK.tmp-$$"
rm -f "$TMP_LINK"
ln -s "$DEST" "$TMP_LINK"
mv -f "$TMP_LINK" "$CURRENT_LINK"

# 7. 写 shim
mkdir -p "$BIN_DIR"
SHIM="$BIN_DIR/ohsql"
cat > "$SHIM" <<'SHIM_EOF'
#!/usr/bin/env bash
exec node "$HOME/.ohsql/current/dist/cli.js" "$@"
SHIM_EOF
chmod +x "$SHIM"

# 8. PATH 检测
case ":$PATH:" in
  *":$BIN_DIR:"*)
    ;;
  *)
    warn "$BIN_DIR 不在 PATH 中。把这行加到 ~/.zshrc 或 ~/.bashrc 后重开 shell："
    printf '    export PATH="%s:$PATH"\n' "$BIN_DIR"
    ;;
esac

info "Installed ohsql v$VERSION → $DEST"
info "Run: ohsql"
