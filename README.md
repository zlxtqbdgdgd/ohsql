# ohsql

`ohsql` 是一款面向 SQL 与鲲鹏环境的 AI 命令行助手，覆盖数据库连接 / Schema 探查 / SQL 执行，到通用工程协作（文件读写、Bash、规划、Skill / Plugin / MCP 扩展）。典型场景包括 MongoDB 在鲲鹏 920 上的调优。

这份 README 只回答四件事：怎么安装、装到哪、`settings.json` 怎么写、装好怎么用。其它深度功能（plugin marketplace、skill 自动修复、`/config` 等模态）进入 REPL 后用 `/help` 自查，本文不展开。

## 安装

### macOS (Apple Silicon)

```bash
curl -fsSL https://raw.githubusercontent.com/zlxtqbdgdgd/ohsql/main/install.sh | bash
```

> 当前仅支持 Apple Silicon（`darwin-arm64`）。Intel Mac 暂不支持。

### Windows (x64)

```powershell
irm https://raw.githubusercontent.com/zlxtqbdgdgd/ohsql/main/install.ps1 | iex
```

安装完成后**重新打开终端**，执行：

```bash
ohsql --version
```

输出版本号即安装成功。直接 `ohsql` 进入交互式 REPL。

### 安装前要求

- **Node.js 20+**
  - macOS：`brew install node`
  - Windows：`winget install --id OpenJS.NodeJS.LTS`
- **Windows 使用 Bash tool 还需要 Git for Windows**
  - `winget install --id Git.Git`

## 安装后文件在哪

`ohsql` 默认安装到：

- macOS：`~/.ohsql/`
- Windows：`%USERPROFILE%\.ohsql\`

典型目录结构：

```text
.ohsql/
├── bin/                    # ohsql / ohsql.cmd 启动 shim
├── current                 # 指向当前启用版本（symlink / junction）
├── versions/<ver>/         # 已安装版本，可保留多份用于回滚
├── cache/downloads/        # 安装与升级下载缓存
├── settings.json           # 你的配置文件（手动创建）
├── sessions/               # 会话记录（用于 --resume）
├── plans/                  # plan mode 写出的计划文件
├── plugins/                # 已安装 plugin marketplace + cache
├── skills/                 # 用户自定义 skill
└── reports/                # 工具/技能生成的报告
```

> 如果你之前用过旧版本 `~/.openharness-sql/`，首次启动会自动迁移到 `~/.ohsql/`，原目录可在确认无误后删除。

## 配置 `settings.json`

`ohsql` 不会替你生成完整的 API 配置——你需要**手动创建** `settings.json`：

- macOS：`~/.ohsql/settings.json`
- Windows：`%USERPROFILE%\.ohsql\settings.json`

下面三种最小可用模板任选其一。

### 1. Anthropic API（Claude 直连）

```json
{
  "active_profile": "claude-api",
  "profiles": {
    "claude-api": {
      "api_format": "anthropic",
      "auth_source": "anthropic_api_key",
      "default_model": "claude-sonnet-4-6",
      "base_url": null,
      "api_key": "sk-ant-..."
    }
  }
}
```

### 2. OpenAI 兼容协议

```json
{
  "active_profile": "openai-compatible",
  "profiles": {
    "openai-compatible": {
      "api_format": "openai",
      "auth_source": "openai_api_key",
      "default_model": "gpt-5.4",
      "base_url": null,
      "api_key": "sk-proj-..."
    }
  }
}
```

### 3. 走代理 / 自建网关 / 私有部署

把 `base_url` 填上即可：

```json
{
  "active_profile": "openai-compatible",
  "profiles": {
    "openai-compatible": {
      "api_format": "openai",
      "auth_source": "openai_api_key",
      "default_model": "gpt-5.4",
      "base_url": "https://your-proxy.example.com/v1",
      "api_key": "your-key"
    }
  }
}
```

### 关键字段

| 字段 | 含义 |
|---|---|
| `active_profile` | 当前默认使用哪个 profile（多 provider 时切这一个字段即可） |
| `profiles` | 所有 provider 配置都放这里，可以同时存多份 |
| `api_format` | 接口协议：`anthropic` / `openai` / `codex` |
| `auth_source` | 认证方式标记 |
| `default_model` | 默认模型名 |
| `base_url` | `null` 走 SDK 默认 endpoint；填 URL 走代理 / 私有网关 |
| `api_key` | 你的 API Key |

### 环境变量会覆盖文件配置

- `ANTHROPIC_API_KEY`
- `OPENHARNESS_MODEL`
- `OPENHARNESS_VERBOSE`

如果改了 `settings.json` 但运行时没生效，先检查这几个环境变量。

## 数据库怎么配

数据库连接**不写在 `settings.json` 里**。`settings.json` 管模型 / 权限 / 偏好；数据库连接在运行时通过自然语言传入，可以直接给连接串，也可以从环境变量读取：

```text
Connect to my database at $DATABASE_URL
```

SQL 默认**只读**。需要执行写操作时由模型显式申请并经你确认。

## 常用命令

进入 REPL 后，所有进阶能力都是斜杠命令：

| 命令 | 用途 |
|---|---|
| `/help` | 列出全部斜杠命令 |
| `/config` | 配置面板：版本 / cwd / provider / 模型 / 权限模式 / MCP / hook / plugin / skill 计数 |
| `/skills` | Skill 管理（包含 skill-doctor 状态、版本历史、启用/停用） |
| `/plugin` | 安装 / 升级 / 启用 / 停用 plugin（CC 兼容协议） |
| `/mcp` | 管理 Model Context Protocol 服务器 |
| `/plan` | 进入 plan-only 模式，仅生成计划不改文件 |
| `/compact` | 手动压缩上下文 |
| `/clear` | 清空当前会话 |
| `/exit` | 退出 |

CLI 选项（`ohsql --help`）：

```
Options:
  -V, --version         输出版本号
  -m, --model <model>   指定模型
  --resume <sessionId>  恢复历史会话
  --mcp <config>        MCP 配置
  --verbose             启用详细输出

Commands:
  update                检查并安装最新版本
```

> `ohsql` 是 REPL-first 工具，没有 `-p` 非交互模式；`update` 是唯一保留的子命令，给安装脚本和自动更新调用。

## Plugin marketplace

`ohsql` 完整复刻 [Claude Code 的 plugin 协议](https://code.claude.com/docs/en/plugins)，同一份 plugin 仓在 `ohsql` 和 stock CC 上都能跑。官方 marketplace：[zlxtqbdgdgd/ohsql-plugin](https://github.com/zlxtqbdgdgd/ohsql-plugin)。

进 REPL 后：

```
> /plugin marketplace add zlxtqbdgdgd/ohsql-plugin
> /plugin install perf-kp-sql
```

详细命令清单和占位符语法见 marketplace 仓 README。

## 更新

显式触发更新：

```bash
ohsql update
```

后台机制：启动时做一次 24 小时节流的轻量检查（只 fetch 最新版本号，不下载），发现新版本只是写到本地节流文件——**不会自动安装**，需要你显式跑 `ohsql update` 才装。这样不会在你打开 ohsql 时偷偷下载几百兆 tarball。

`ohsql update` 内部直接调用 install 脚本（macOS 走 `install.sh`、Windows 走 `install.ps1`），所以走的是你**首装能跑通的同一条网络路径**——会自动用系统代理 / 系统证书 store。如果首装能成功，update 就一定能成功。

要完全关闭启动时的检查：

```bash
# macOS / Linux
export OHSQL_DISABLE_AUTOUPDATE=1
```

```powershell
# Windows
$env:OHSQL_DISABLE_AUTOUPDATE = '1'
```

## 卸载

### macOS

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/zlxtqbdgdgd/ohsql/main/uninstall.sh)
```

### Windows

```powershell
irm https://raw.githubusercontent.com/zlxtqbdgdgd/ohsql/main/uninstall.ps1 | iex
```

默认只删除运行时（`bin/` `current` `versions/` `cache/`），**保留 `settings.json` 等用户数据**。彻底删除：

```bash
rm -rf ~/.ohsql                                 # macOS
Remove-Item -Recurse -Force $env:USERPROFILE\.ohsql   # Windows
```

## 常见问题

**1. 提示找不到配置文件**

默认位置 `~/.ohsql/settings.json`（Windows：`%USERPROFILE%\.ohsql\settings.json`）。文件不存在就自己创建。

**2. 改了 `settings.json` 但模型没切**

先检查是否设置了 `OPENHARNESS_MODEL` 或 `ANTHROPIC_API_KEY` 这类环境变量——它们会覆盖文件配置。

**3. 想换模型但不想改一堆字段**

通常只需改当前 profile 的 `default_model`。

**4. 多 provider 来回切**

在 `profiles` 下同时放多份配置，然后切换顶层 `active_profile` 字段即可，不用每次重写整个文件。

**5. `ohsql --version` 报错或找不到命令**

确认安装脚本最后那段 PATH 提示有没有照做（macOS 通常需要把 `~/.ohsql/bin` 加进 `~/.zshrc` 后重开终端）。

## 当前支持平台

- macOS Apple Silicon（`darwin-arm64`）
- Windows x64（`win32-x64`）

暂不支持：Intel Mac、Windows on ARM、Linux。
