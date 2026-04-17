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

# 2. Node.js >= 18
$node = Get-Command node -ErrorAction SilentlyContinue
if (-not $node) {
    Die "Node.js not found. Install via 'winget install --id OpenJS.NodeJS.LTS' or https://nodejs.org (need >= 18)."
}
$nodeVer = (& node -p "process.versions.node").Trim()
$nodeMajor = [int](($nodeVer -split '\.')[0])
if ($nodeMajor -lt 18) {
    Die "Node.js $nodeVer is too old. Need >= 18."
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

# 7. 写 shim
[void](New-Item -ItemType Directory -Force -Path $BinDir)
$ShimPath = Join-Path $BinDir 'ohsql.cmd'
Set-Content -LiteralPath $ShimPath -Encoding ASCII -Value @'
@echo off
node "%USERPROFILE%\.ohsql\current\dist\cli.js" %*
'@

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
