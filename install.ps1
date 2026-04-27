# OpenHarness-SQL Windows 安装脚本 (win32-x64)
#
#   irm https://raw.githubusercontent.com/zlxtqbdgdgd/ohsql/main/install.ps1 | iex
#
# 流程：
#   1. 平台 & Node 检测
#   2. 从 GitHub API 拿最新 tag（可被 $env:OHSQL_VERSION 覆写）
#   3. 下载 tarball + SHA256SUMS 到 %TEMP%\ohsql-cache\，校验
#   4. tar.exe -xzf 到 %USERPROFILE%\.ohsql\versions\<ver>\
#   5. 用 directory junction 原子切 current（不需要 admin）
#   6. 写 shim %USERPROFILE%\.ohsql\bin\ohsql.cmd
#   7. 若 bin 目录不在 User PATH，用 setx 模式加上

$ErrorActionPreference = 'Stop'

# Windows PowerShell 5.x 默认 SecurityProtocol 是 SSL3/TLS 1.0，但 GitHub.com 已经
# 只接受 TLS 1.2+。表现就是首条 Invoke-WebRequest 抛
#   "请求被中止: 未能创建 SSL/TLS 安全通道"
# 强制把 TLS 1.2 OR 进当前协议集合（保留可能存在的更高版本，比如 TLS 1.3）。
try {
    [Net.ServicePointManager]::SecurityProtocol =
        [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
} catch {
    # PS 7+ 默认就是 TLS 1.2/1.3，这里失败也不致命，IWR 自己会再 negotiate
}

$Repo         = 'zlxtqbdgdgd/ohsql'
$Platform     = 'win32-x64'
$ConfigDir    = Join-Path $env:USERPROFILE '.ohsql'
$VersionsDir  = Join-Path $ConfigDir 'versions'
$BinDir       = Join-Path $ConfigDir 'bin'
$CurrentLink  = Join-Path $ConfigDir 'current'
$CacheDir     = Join-Path $ConfigDir 'cache\downloads'

function Info  { param($msg) Write-Host "==> $msg" -ForegroundColor Cyan }
function Warn  { param($msg) Write-Host "!! $msg" -ForegroundColor Yellow }
function Die   { param($msg) Write-Host "xx $msg" -ForegroundColor Red; exit 1 }

# 1. 平台 & 架构
if ($env:OS -ne 'Windows_NT') {
    Die "This script is for Windows only. Use install.sh on macOS."
}
if ($env:PROCESSOR_ARCHITECTURE -ne 'AMD64') {
    Die "Unsupported architecture: $env:PROCESSOR_ARCHITECTURE (only AMD64/x64 supported; arm64 后续版本)"
}
Info "Platform: $Platform"

# 2. Node.js >= 20
$node = Get-Command node -ErrorAction SilentlyContinue
if (-not $node) {
    Die "Node.js not found. Install via 'winget install --id OpenJS.NodeJS.LTS' or https://nodejs.org (need >= 20)."
}
$nodeVer = (& node -p "process.versions.node").Trim()
$nodeMajor = [int](($nodeVer -split '\.')[0])
if ($nodeMajor -lt 20) {
    Die "Node.js $nodeVer is too old. Need >= 20."
}
Info "Node.js v$nodeVer OK"

# Git Bash 检测（非致命——只有 BashTool 需要）
$gitBash = $null
try {
    $gitBashPath = & where.exe bash 2>$null |
        Where-Object { $_ -notmatch '\\System32\\bash\.exe$' } |
        Select-Object -First 1
    if ($gitBashPath -and (Test-Path $gitBashPath)) { $gitBash = $gitBashPath }
} catch { }
if (-not $gitBash) {
    foreach ($p in @("$env:ProgramFiles\Git\bin\bash.exe", "${env:ProgramFiles(x86)}\Git\bin\bash.exe")) {
        if ($p -and (Test-Path $p)) { $gitBash = $p; break }
    }
}
if ($gitBash) {
    Info "Git Bash found: $gitBash"
} else {
    Warn "Git Bash not found. Install later if you want to use the Bash tool:"
    Warn "  winget install --id Git.Git"
}

# 3. 目标版本
if ($env:OHSQL_VERSION) {
    $Version = $env:OHSQL_VERSION -replace '^v', ''
    Info "Using pinned version: v$Version"
} else {
    Info "Fetching latest release tag from GitHub"
    try {
        $release = Invoke-RestMethod -Uri "https://api.github.com/repos/$Repo/releases/latest" -UseBasicParsing
    } catch {
        Die "Could not resolve latest release tag: $($_.Exception.Message)"
    }
    $Version = $release.tag_name -replace '^v', ''
    Info "Latest: v$Version"
}

# 4. 下载 + 校验
$Tarball       = "openharness-sql-$Version-$Platform.tar.gz"
$TarballUrl    = "https://github.com/$Repo/releases/download/v$Version/$Tarball"
$SumsUrl       = "https://github.com/$Repo/releases/download/v$Version/SHA256SUMS"
[void](New-Item -ItemType Directory -Force -Path $CacheDir)
$TarballPath = Join-Path $CacheDir $Tarball
$SumsPath    = Join-Path $CacheDir "SHA256SUMS-$Version"

Info "Downloading $Tarball"
Invoke-WebRequest -Uri $TarballUrl -OutFile $TarballPath -UseBasicParsing
Invoke-WebRequest -Uri $SumsUrl    -OutFile $SumsPath    -UseBasicParsing

Info "Verifying sha256"
$expected = $null
foreach ($line in Get-Content $SumsPath) {
    $parts = $line -split '\s+', 2
    if ($parts.Count -ge 2 -and ($parts[1] -replace '^\*', '') -eq $Tarball) {
        $expected = $parts[0]; break
    }
}
if (-not $expected) { Die "SHA256SUMS missing entry for $Tarball" }
$actual = (Get-FileHash -Algorithm SHA256 $TarballPath).Hash.ToLower()
if ($expected.ToLower() -ne $actual) {
    Die "sha256 mismatch: expected $expected, got $actual"
}

# 5. 解压到 versions/<ver>/
$Dest = Join-Path $VersionsDir $Version
[void](New-Item -ItemType Directory -Force -Path $Dest)
Info "Extracting to $Dest"
# Windows 10 1803+ 自带 tar.exe 支持 gzip
$tarResult = & tar.exe -xzf $TarballPath -C $Dest 2>&1
if ($LASTEXITCODE -ne 0) {
    Die "tar extract failed: $tarResult"
}

# 5.5 native module ABI 对齐
# tarball 里的 better-sqlite3 prebuild 是 GitHub Actions runner 编的（Node 22 →
# NODE_MODULE_VERSION 127）。用户本地 Node 大概率不是 22（Node 24 → 137 直接 dlopen 失败）。
# better-sqlite3 把每个 Node major 的 prebuild 都发到了上游 Release，按当前 Node 的
# NODE_MODULE_VERSION 拼 URL 直接拉 prebuild tarball 解压覆盖即可。
#
# 不用 prebuild-install：它内部走 Node 自带的 simple-get/https，**不读系统代理 +
# 不读系统证书 store**，企业网下必超时。Invoke-WebRequest 走 WinHTTP 默认吃系统配置——
# 主 tarball 既然能下，prebuild tarball 也一定能下。
$BsqDir = Join-Path $Dest 'node_modules\better-sqlite3'
$BsqPkgJson = Join-Path $BsqDir 'package.json'
if (Test-Path $BsqPkgJson) {
    $bsqVer = (Get-Content -Raw -LiteralPath $BsqPkgJson | ConvertFrom-Json).version
    $nmv    = (& node -p "process.versions.modules").Trim()
    $prebuildName = "better-sqlite3-v$bsqVer-node-v$nmv-$Platform.tar.gz"
    $prebuildUrl  = "https://github.com/WiseLibs/better-sqlite3/releases/download/v$bsqVer/$prebuildName"
    $prebuildPath = Join-Path $CacheDir $prebuildName
    Info "Refreshing better-sqlite3 prebuild (NODE_MODULE_VERSION $nmv) for Node v$nodeVer"
    try {
        Invoke-WebRequest -Uri $prebuildUrl -OutFile $prebuildPath -UseBasicParsing
        $extractResult = & tar.exe -xzf $prebuildPath -C $BsqDir 2>&1
        if ($LASTEXITCODE -ne 0) {
            Warn "tar extract failed for $prebuildName : $extractResult"
            Warn "  ohsql may crash with NODE_MODULE_VERSION mismatch."
        }
    } catch {
        Warn "Could not download $prebuildName : $($_.Exception.Message)"
        Warn "  ohsql may crash with NODE_MODULE_VERSION mismatch."
        Warn "  Manual fix: 把"
        Warn "    $prebuildUrl"
        Warn "  下下来后跑 tar.exe -xzf <tarball> -C `"$BsqDir`""
    }
} else {
    Warn "better-sqlite3 missing in tarball; native module ABI not refreshed."
}

# 6. 原子切 current（directory junction —— 不要 admin）
$TmpLink = "$CurrentLink.tmp-$PID"
if (Test-Path $TmpLink) { Remove-Item $TmpLink -Recurse -Force }
$mkResult = & cmd.exe /c mklink /J "`"$TmpLink`"" "`"$Dest`"" 2>&1
if ($LASTEXITCODE -ne 0) {
    Die "mklink /J failed: $mkResult"
}
# 原子替换（Move-Item -Force 在 Windows 上对 junction 可用）
if (Test-Path $CurrentLink) { Remove-Item $CurrentLink -Recurse -Force }
Move-Item -Force -LiteralPath $TmpLink -Destination $CurrentLink

# 7. 写 shim —— 两份
#   (a) ohsql.cmd —— PowerShell / cmd.exe 走这个，靠 PATHEXT 自动追加 .cmd
#   (b) ohsql      —— Git Bash 走这个，POSIX 查找不读 PATHEXT，必须有无扩展名同名文件
#                     bash 通过 shebang 找到 sh 解释器；文件需 LF 换行，否则
#                     `\r` 会被 shebang parser 当成路径一部分爆 "bad interpreter"
[void](New-Item -ItemType Directory -Force -Path $BinDir)
$CmdShimPath = Join-Path $BinDir 'ohsql.cmd'
Set-Content -LiteralPath $CmdShimPath -Encoding ASCII -Value @'
@echo off
node "%USERPROFILE%\.ohsql\current\dist\cli.js" %*
'@

$BashShimPath = Join-Path $BinDir 'ohsql'
$bashShim = "#!/usr/bin/env bash`nexec node `"`$HOME/.ohsql/current/dist/cli.js`" `"`$@`"`n"
# WriteAllText + UTF8 (无 BOM) 才能拿到纯 LF；Set-Content 会按 PS 默认在 Win 上写 CRLF
[System.IO.File]::WriteAllText($BashShimPath, $bashShim, (New-Object System.Text.UTF8Encoding $false))

# 8. 加入 User PATH（如果还没在）
$userPath = [Environment]::GetEnvironmentVariable('PATH', 'User')
if ($null -eq $userPath) { $userPath = '' }
$pathEntries = $userPath -split ';' | Where-Object { $_ }
if ($pathEntries -notcontains $BinDir) {
    Info "Adding $BinDir to User PATH"
    $newPath = if ($userPath) { "$userPath;$BinDir" } else { $BinDir }
    [Environment]::SetEnvironmentVariable('PATH', $newPath, 'User')
    Warn "PATH updated. Open a new PowerShell / Terminal window for it to take effect."
}

Info "Installed ohsql v$Version -> $Dest"
Info "Run: ohsql"
