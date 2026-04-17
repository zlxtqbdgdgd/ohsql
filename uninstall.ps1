# OpenHarness-SQL Windows 卸载脚本
#
# 删除：%USERPROFILE%\.openharness-sql\{bin,versions,current,cache}
# 保留：settings.json / sessions / plans / reports / oops-bench —— 用户数据
#
# 如要完全移除所有状态：Remove-Item -Recurse -Force $env:USERPROFILE\.openharness-sql

$ErrorActionPreference = 'Stop'

$ConfigDir = Join-Path $env:USERPROFILE '.openharness-sql'

if (-not (Test-Path $ConfigDir)) {
    Write-Host "Nothing to uninstall ($ConfigDir not found)."
    exit 0
}

foreach ($sub in @('bin', 'versions', 'current', 'cache')) {
    $target = Join-Path $ConfigDir $sub
    if (Test-Path $target) {
        Write-Host "Remove-Item -Recurse -Force $target"
        Remove-Item -Recurse -Force -LiteralPath $target
    }
}

Write-Host ""
Write-Host "ohsql runtime removed." -ForegroundColor Green
Write-Host "   User data preserved: $ConfigDir\{settings.json,sessions,plans,reports,oops-bench}"
Write-Host "   To fully remove: Remove-Item -Recurse -Force $ConfigDir"
