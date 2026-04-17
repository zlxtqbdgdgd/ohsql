# ohsql — OpenHarness-SQL 发布通道

AI-powered CLI coding assistant with SQL database support (PostgreSQL / MySQL / SQLite)。
本仓只放终端用户需要的**安装脚本**和**Release 二进制包**；主仓是私仓，源码不在这里。

## 安装

### macOS (Apple Silicon)

```bash
curl -fsSL https://raw.githubusercontent.com/zlxtqbdgdgd/ohsql/main/install.sh | bash
```

### Windows (x64)

PowerShell 5.1+ 或 PowerShell 7+：

```powershell
irm https://raw.githubusercontent.com/zlxtqbdgdgd/ohsql/main/install.ps1 | iex
```

> 首次安装后打开新终端，运行 `ohsql --version` 验证。

## 前置要求

- **Node.js ≥ 18**
  - macOS: `brew install node`
  - Windows: `winget install --id OpenJS.NodeJS.LTS`
- **Windows 用户额外**：如需使用内置 Bash tool，安装 Git for Windows：
  - `winget install --id Git.Git`（装完重启终端）

## 安装位置

| 平台 | 位置 |
|---|---|
| macOS | `~/.openharness-sql/` |
| Windows | `%USERPROFILE%\.openharness-sql\` |

目录布局：

```
.openharness-sql/
├── bin/                    # ohsql / ohsql.cmd shim
├── current  ->  versions/<cur>
├── versions/<ver>/         # 多版本共存，回滚只改 symlink/junction
├── cache/downloads/        # auto-updater 下载缓存
├── settings.json           # 你的配置（升级 / 卸载都不动）
├── sessions/、plans/ …
```

## 升级

```bash
ohsql update                # 手动立即检查
```

启动时也会 24h 节流静默检查一次，发现新版后台下载，下次启动生效。要关闭：
`export OHSQL_DISABLE_AUTOUPDATE=1`（Windows 下 `$env:OHSQL_DISABLE_AUTOUPDATE = '1'`）。

## 卸载

```bash
# macOS
bash <(curl -fsSL https://raw.githubusercontent.com/zlxtqbdgdgd/ohsql/main/uninstall.sh)

# Windows
irm https://raw.githubusercontent.com/zlxtqbdgdgd/ohsql/main/uninstall.ps1 | iex
```

默认只删运行时（bin / versions / current / cache），**保留** `settings.json` 等用户数据。彻底清：

```bash
rm -rf ~/.openharness-sql                           # macOS
Remove-Item -Recurse -Force $env:USERPROFILE\.openharness-sql  # Windows
```

## 支持平台

| 平台 | 状态 |
|---|---|
| darwin-arm64 (Apple Silicon) | ✅ |
| win32-x64 (Intel/AMD Windows) | ✅ |
| darwin-x64 (Intel Mac) | 未排期 |
| win32-arm64 (Windows on ARM) | 未排期 |
| Linux | 无支持计划 |

## 问题反馈

Issues 提到本仓即可（源码私有，但 Issues 在此仓公开）。

## License

TBD.
