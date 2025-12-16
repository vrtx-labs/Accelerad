# Rtrace Regression Test Script - Windows
param(
    [string]$BinDir = "build\bin\Release",
    [string]$LibDir = "build\lib"
)

Write-Host "=== Rtrace Regression Test ===" -ForegroundColor Cyan

# Set up paths
$ProjectRoot = $PSScriptRoot
$BinPath = Join-Path $ProjectRoot $BinDir
$LibPath = Join-Path $ProjectRoot $LibDir

# Check executables
$RtraceExe = Join-Path $BinPath "rtrace.exe"
$RcalcExe = Join-Path $BinPath "rcalc.exe"

if (!(Test-Path $RtraceExe)) {
    Write-Error "rtrace.exe not found at: $RtraceExe"
    exit 1
}

if (!(Test-Path $RcalcExe)) {
    Write-Error "rcalc.exe not found at: $RcalcExe"
    exit 1
}

Write-Host "Found executables:" -ForegroundColor Green
Write-Host "  rtrace: $RtraceExe"
Write-Host "  rcalc:  $RcalcExe"

# Set environment
$env:PATH = "$BinPath;$env:PATH"
$env:RAYPATH = "regression_test\lib_base;$LibPath;."

Write-Host "Environment set:" -ForegroundColor Green
Write-Host "  PATH: $BinPath;..." -ForegroundColor Gray
Write-Host "  RAYPATH: $env:RAYPATH" -ForegroundColor Gray

# Create output directory
New-Item -ItemType Directory -Path "test_output" -Force | Out-Null

# Run test
Write-Host "Running regression test..." -ForegroundColor Yellow

$SceneFile = "regression_test\scene\8629.oct"
$PointsFile = "regression_test\scene\8629_points.inp"
$OutputFile = "test_output\8629_result.out"

if (!(Test-Path $SceneFile)) {
    Write-Error "Scene file not found: $SceneFile"
    exit 1
}

if (!(Test-Path $PointsFile)) {
    Write-Error "Points file not found: $PointsFile"
    exit 1
}

# Execute the regression test pipeline
Get-Content $PointsFile | 
    & $RtraceExe -n 1 -w -I -h -u -ds 0.1 -ab 8 -av 0 0 0 -ad 4096 -as 2048 -aa 0.2 -ar 21 -lr 128 $SceneFile |
    & $RcalcExe -e '$1=179.*(0.265*$1+0.67*$2+0.065*$3)' |
    Out-File -FilePath $OutputFile -Encoding ASCII

if (!(Test-Path $OutputFile)) {
    Write-Error "Output file not created: $OutputFile"
    exit 1
}

Write-Host "Test executed successfully!" -ForegroundColor Green

# Compare results
$TargetFile = "regression_test\8629_target.out"
Write-Host "Comparing with target file..." -ForegroundColor Yellow

if (!(Test-Path $TargetFile)) {
    Write-Error "Target file not found: $TargetFile"
    exit 1
}

$TargetContent = Get-Content $TargetFile
$ResultContent = Get-Content $OutputFile

if ($TargetContent.Count -ne $ResultContent.Count) {
    Write-Error "Line count mismatch: target=$($TargetContent.Count), result=$($ResultContent.Count)"
    exit 1
}

$Tolerance = 0.001
$MaxDiff = 0.0
$Failed = 0

for ($i = 0; $i -lt $TargetContent.Count; $i++) {
    $Target = [double]$TargetContent[$i].Trim()
    $Result = [double]$ResultContent[$i].Trim()
    
    $Diff = [Math]::Abs($Target - $Result)
    $RelDiff = $Diff / [Math]::Max([Math]::Abs($Target), 1e-10)
    
    $MaxDiff = [Math]::Max($MaxDiff, $RelDiff)
    
    if ($RelDiff -gt $Tolerance) {
        Write-Warning "Line $($i+1): target=$Target, result=$Result, rel_diff=$RelDiff"
        $Failed++
    }
}

if ($Failed -gt 0) {
    Write-Error "Test FAILED: $Failed lines exceeded tolerance $Tolerance"
    exit 1
}

Write-Host "SUCCESS: All $($TargetContent.Count) values within tolerance $Tolerance" -ForegroundColor Green
Write-Host "Maximum relative difference: $MaxDiff"
Write-Host "First few comparisons:"
for ($i = 0; $i -lt [Math]::Min(5, $TargetContent.Count); $i++) {
    Write-Host "  Line $($i+1): $($TargetContent[$i]) vs $($ResultContent[$i])"
}

Write-Host "`n=== REGRESSION TEST PASSED ===" -ForegroundColor Green