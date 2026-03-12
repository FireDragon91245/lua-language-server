param(
    [string]$Platform
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$repoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $repoRoot

$originalPath = [Environment]::GetEnvironmentVariable('PATH', 'Process')
if (-not $originalPath) {
    throw 'PATH is empty for the current process.'
}

$cleanEntries = $originalPath -split ';' | Where-Object {
    $_ -and $_.Trim() -and $_ -notmatch '(?i)\\msys64\\|\\mingw32\\|\\mingw64\\|\\ucrt64\\|\\clang32\\|\\clang64\\'
} | Select-Object -Unique

$cleanPath = $cleanEntries -join ';'
if (-not $cleanPath) {
    throw 'Filtered PATH is empty after removing MSYS entries.'
}

$env:PATH = $cleanPath
$env:MSYS2_PATH_TYPE = 'inherit'
$env:MSYS_NO_PATHCONV = '1'
$env:MSYS2_ARG_CONV_EXCL = '*'

Write-Host 'Using cleaned PATH for build.'

$generatedPaths = @(
    (Join-Path $repoRoot 'build'),
    (Join-Path $repoRoot '3rd\luamake\build')
)

foreach ($generatedPath in $generatedPaths) {
    if (Test-Path $generatedPath) {
        Write-Host "Removing stale generated build state: $generatedPath"
        Remove-Item -Recurse -Force $generatedPath
    }
}

$command = 'call make.bat'
if ($Platform) {
    $command += " $Platform"
}

& cmd.exe /d /c "cd /d `"$repoRoot`" && $command"
exit $LASTEXITCODE