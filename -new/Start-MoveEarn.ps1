$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot
$env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' + [Environment]::GetEnvironmentVariable('Path', 'User') + ';' + $env:Path
try {
    Write-Host 'Move & Earn: checking Node.js...'
    $nodeReady = $false
    if (Get-Command node.exe -ErrorAction SilentlyContinue) {
        $nodeVersion = (& node.exe --version | Select-Object -Last 1).Trim()
        $nodeMajor = [int]($nodeVersion.TrimStart('v').Split('.')[0])
        $nodeReady = $nodeMajor -ge 22
    }
    if (-not $nodeReady) {
        if (-not (Get-Command winget.exe -ErrorAction SilentlyContinue)) {
            Start-Process 'https://nodejs.org/en/download'
            throw 'Install Node.js LTS using the Windows installer, then run START.cmd again.'
        }
        Write-Host 'Installing Node.js LTS. Accept the Windows installer prompt if shown.'
        & winget.exe install --id OpenJS.NodeJS.LTS --exact --source winget --accept-package-agreements --accept-source-agreements
        if ($LASTEXITCODE -ne 0) { throw 'Node.js installation failed. Install Node.js LTS from nodejs.org, then retry.' }
        $env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' + [Environment]::GetEnvironmentVariable('Path', 'User')
        if (-not (Get-Command node.exe -ErrorAction SilentlyContinue)) { throw 'Close this window and run START.cmd again to load Node.js.' }
    }
    if (-not (Get-Command npm.cmd -ErrorAction SilentlyContinue)) { throw 'npm is missing. Reinstall Node.js LTS, then retry.' }
    if (-not (Test-Path '.env.local')) { throw '.env.local is missing. Restore your Supabase configuration before starting.' }
    $projectSettings = Get-Content 'package.json' -Raw | ConvertFrom-Json
    $packageManager = $projectSettings.packageManager
    if ($packageManager -notmatch '^pnpm@[0-9]+\.[0-9]+\.[0-9]+$') { throw 'Invalid packageManager in package.json.' }
    Write-Host 'Installing project dependencies. Internet is required; the first run can take several minutes.'
    & npm.cmd exec --yes "--package=$packageManager" -- pnpm install --frozen-lockfile --node-linker=hoisted
    if ($LASTEXITCODE -ne 0) { throw 'Dependency installation failed. Check the error above and your internet connection.' }
    Write-Host 'Starting website at http://localhost:3000. Keep this window open.'
    Write-Host 'If port 3000 is busy, use the Local URL printed by Next.js below.'
    & (Join-Path $PSScriptRoot 'node_modules\.bin\next.cmd') dev
    if ($LASTEXITCODE -ne 0) { throw 'The web server stopped with an error. See the message above.' }
} catch {
    Write-Host $_.Exception.Message -ForegroundColor Red
    exit 1
}
