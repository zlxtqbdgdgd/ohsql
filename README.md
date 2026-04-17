# ohsql

`ohsql` 是一款面向泛 SQL 场景与鲲鹏环境的 AI 命令行工具。例如 MongoDB 在鲲鹏 920 上的调优场景。

如果你是第一次安装 `ohsql`，这份 README 只回答三件事：
- 怎么安装
- 安装后文件在哪
- `settings.json` 应该怎么写

## 安装

### macOS (Apple Silicon)

```bash
curl -fsSL https://raw.githubusercontent.com/zlxtqbdgdgd/ohsql/main/install.sh | bash
```

### Windows (x64)

```powershell
irm https://raw.githubusercontent.com/zlxtqbdgdgd/ohsql/main/install.ps1 | iex
```

安装完成后，重新打开终端，先执行：

```bash
ohsql --version
```

如果能输出版本号，说明安装成功。

## 安装前要求

- Node.js 18+
  - macOS: `brew install node`
  - Windows: `winget install --id OpenJS.NodeJS.LTS`
- Windows 如果要使用 Bash tool，还需要 Git for Windows
  - `winget install --id Git.Git`

## 安装后文件在哪

`ohsql` 默认安装到：

- macOS: `~/.ohsql/`
- Windows: `%USERPROFILE%\.ohsql\`

典型目录结构：

```text
.ohsql/
├── bin/                    # ohsql / ohsql.cmd 启动入口
├── current                 # 当前启用版本链接
├── versions/<ver>/         # 已安装版本
├── cache/downloads/        # 更新下载缓存
├── settings.json           # 你的配置文件
├── sessions/               # 会话记录
├── plans/                  # plan mode 文件
└── reports/                # 工具或技能生成的报告
```

## 第一步先做什么

大多数用户安装完以后，第一个真正会卡住的问题就是：**`settings.json` 应该怎么写？**

先创建：

- macOS: `~/.ohsql/settings.json`
- Windows: `%USERPROFILE%\.ohsql\settings.json`

如果这个文件不存在，`ohsql` 会创建配置目录，但不会自动替你补完整的 API 配置。

## 最小可用配置

### 1. 使用 Anthropic API

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

### 2. 使用 OpenAI API

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

### 3. 使用代理或兼容网关

如果你不是直连官方接口，而是走代理、网关或兼容服务，只需要把 `base_url` 填上：

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

## `settings.json` 里最重要的字段

- `active_profile`：当前默认使用哪个 profile
- `profiles`：所有模型配置都放这里
- `api_format`：接口协议类型，例如 `anthropic` 或 `openai`
- `auth_source`：认证方式标记
- `default_model`：默认模型名
- `base_url`：留空或 `null` 表示走默认地址；填 URL 表示走代理或私有网关
- `api_key`：你的 API Key

## 环境变量会覆盖文件配置

如果你设置了下面这些环境变量，它们会覆盖 `settings.json` 的部分内容：

- `ANTHROPIC_API_KEY`
- `OPENHARNESS_MODEL`
- `OPENHARNESS_VERBOSE`

所以如果你已经改了 `settings.json`，结果运行时没生效，先检查环境变量。

## 第一次运行

配置好 `settings.json` 之后，直接启动：

```bash
ohsql
```

也可以先用一条非交互命令验证：

```bash
ohsql -p "hello"
```

## 数据库怎么配

数据库连接不放在 `settings.json` 里。

`settings.json` 管的是模型、权限、偏好设置；数据库连接是在运行时传入的。你可以直接给连接串，也可以让它从环境变量里读取。

例如：

```text
Connect to my database at $DATABASE_URL
```

默认 SQL 执行是只读的；写操作需要显式允许。

## 常见问题

### 1. 找不到配置文件

默认位置就是：

- macOS: `~/.ohsql/settings.json`
- Windows: `%USERPROFILE%\.ohsql\settings.json`

没有就自己创建。

### 2. 我之前用过旧版本目录

旧目录 `~/.openharness-sql/` 会迁移到 `~/.ohsql/`。

### 3. 我只想换模型，不想改一堆字段

通常只需要改当前 profile 的 `default_model`。

### 4. 我有多个 provider

可以在 `profiles` 里同时放多个，然后切换 `active_profile`。

## 更新

```bash
ohsql update
```

启动时也会做 24 小时节流的自动检查。要关闭自动更新：

```bash
export OHSQL_DISABLE_AUTOUPDATE=1
```

Windows:

```powershell
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

默认只删除运行时文件，保留 `settings.json` 和其他用户数据。

如果要彻底删除：

```bash
rm -rf ~/.ohsql
```

Windows:

```powershell
Remove-Item -Recurse -Force $env:USERPROFILE\.ohsql
```

## 当前支持平台

- macOS Apple Silicon
- Windows x64
