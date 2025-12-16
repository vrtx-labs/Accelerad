# rpict Regression Test Script
param(
    [string]$BinDir = "build\bin\Release",
    [string]$LibDir = "build\lib",
    [string]$VdsOctreeFile = "regression_test\scene\out.oct"
)

Write-Host "=== rpict Regression Test ===" -ForegroundColor Cyan

$BinPath = Join-Path $PSScriptRoot $BinDir
$LibPath = Join-Path $PSScriptRoot $LibDir
$RpictExe = Join-Path $BinPath "rpict.exe"
$AcceleradRpictExe = Join-Path $BinPath "accelerad_rpict.exe"
$RpictRadExe = Join-Path $BinPath "rpict_rad.exe"

if (!(Test-Path $RpictExe)) {
    Write-Error "rpict.exe not found"
    exit 1
}

if (!(Test-Path $AcceleradRpictExe)) {
    Write-Error "accelerad_rpict.exe not found"
    exit 1
}

if (!(Test-Path $RpictRadExe)) {
    Write-Error "rpict_rad.exe not found"
    exit 1
}

Write-Host "Found rpict: $RpictExe" -ForegroundColor Green
Write-Host "Found accelerad_rpict: $AcceleradRpictExe" -ForegroundColor Green
Write-Host "Found rpict_rad: $RpictRadExe" -ForegroundColor Green

$env:PATH = "$BinPath;$env:PATH"
$env:RAYPATH = "$LibPath;."

Write-Host "Environment set:" -ForegroundColor Green
Write-Host "  PATH: $BinPath;..." -ForegroundColor Gray
Write-Host "  RAYPATH: $env:RAYPATH" -ForegroundColor Gray

New-Item -ItemType Directory -Path "test_output" -Force | Out-Null

$Executables = @(
    @{Name="rpict"; Path=$RpictExe},
    @{Name="accelerad_rpict"; Path=$AcceleradRpictExe},
    @{Name="rpict_rad"; Path=$RpictRadExe}
)

$FailedTests = @()

foreach ($Exe in $Executables) {
    Write-Host "`n========================================" -ForegroundColor Magenta
    Write-Host "Testing with: $($Exe.Name)" -ForegroundColor Magenta
    Write-Host "========================================" -ForegroundColor Magenta
    
    # Test 1: Basic 8629 scene
    Write-Host "`n=== Test 1: 8629 scene ===" -ForegroundColor Cyan
    $SceneFile = "regression_test\scene\8629.oct"
    $OutputFile = "test_output\8629_rpict_$($Exe.Name).hdr"
    
    Write-Host "Rendering with $($Exe.Name)..." -ForegroundColor Yellow
    $start = Get-Date
    $process = Start-Process -FilePath $Exe.Path -ArgumentList "-vtv","-vp","0","0","5","-vd","0","0","-1","-vu","0","1","0","-vh","60","-vv","60","-x","512","-y","512","-ab","2","-aa","0.15","-ar","128","-ad","512",$SceneFile -RedirectStandardOutput $OutputFile -NoNewWindow -Wait -PassThru
    $elapsed = ((Get-Date) - $start).TotalSeconds
    
    if (!(Test-Path $OutputFile)) {
        Write-Host "FAIL: Output file not created for $($Exe.Name)" -ForegroundColor Red
        $FailedTests += "$($Exe.Name): Test 1 - Output file not created"
        continue
    }
    
    $size = (Get-Item $OutputFile).Length
    $roundedTime = [math]::Round($elapsed, 2)
    Write-Host "Render completed in $roundedTime seconds" -ForegroundColor Green
    Write-Host "Output: $OutputFile" -ForegroundColor Green
    Write-Host "Size: $size bytes" -ForegroundColor Green
    
    if ($size -lt 1000) {
        Write-Host "FAIL: Output too small for $($Exe.Name)" -ForegroundColor Red
        $FailedTests += "$($Exe.Name): Test 1 - Output too small ($size bytes)"
    }
    
    # Test 2: VDS-4361 with view file
    Write-Host "`n=== Test 2: VDS-4361 with view file ===" -ForegroundColor Cyan
    $SceneDir = "regression_test\scene"
    $ViewFile = "vds-4361.vp"
    $OctFile = "out.oct"
    $OutputFile2 = Join-Path $PSScriptRoot "test_output\vds-4361_rpict_$($Exe.Name).hdr"
    
    if (!(Test-Path (Join-Path $SceneDir $ViewFile))) {
        Write-Error "View file not found: $SceneDir\$ViewFile"
        exit 1
    }
    
    if (!(Test-Path (Join-Path $SceneDir $OctFile))) {
        Write-Error "Octree file not found: $SceneDir\$OctFile"
        exit 1
    }
    
    Write-Host "Rendering with $($Exe.Name) using view file..." -ForegroundColor Yellow
    $start = Get-Date
    # Run from scene directory to resolve relative paths in octree
    $process = Start-Process -FilePath $Exe.Path -ArgumentList "-vf",$ViewFile,"-x","1280","-y","720","-vh","90","-vv","58.75",$OctFile -RedirectStandardOutput $OutputFile2 -WorkingDirectory (Join-Path $PSScriptRoot $SceneDir) -NoNewWindow -Wait -PassThru
    $elapsed = ((Get-Date) - $start).TotalSeconds
    
    if (!(Test-Path $OutputFile2)) {
        Write-Host "FAIL: Output file not created for $($Exe.Name)" -ForegroundColor Red
        $FailedTests += "$($Exe.Name): Test 2 - Output file not created"
        continue
    }
    
    $size = (Get-Item $OutputFile2).Length
    $roundedTime = [math]::Round($elapsed, 2)
    Write-Host "Render completed in $roundedTime seconds" -ForegroundColor Green
    Write-Host "Output: $OutputFile2" -ForegroundColor Green
    Write-Host "Size: $size bytes" -ForegroundColor Green
    
    if ($size -lt 1000) {
        Write-Host "FAIL: Output too small for $($Exe.Name)" -ForegroundColor Red
        $FailedTests += "$($Exe.Name): Test 2 - Output too small ($size bytes)"
    }
    
    # Test 3: VDS-4361 with advanced parameters
    Write-Host "`n=== Test 3: VDS-4361 with advanced parameters ===" -ForegroundColor Cyan
    $OutputFile3 = Join-Path $PSScriptRoot "test_output\vds-4361_rpict_advanced_$($Exe.Name).hdr"
    
    Write-Host "Rendering with $($Exe.Name) using advanced parameters..." -ForegroundColor Yellow
    $start = Get-Date
    # Run from scene directory to resolve relative paths in octree
    $process = Start-Process -FilePath $Exe.Path -ArgumentList "-vf",$ViewFile,"-x","1280","-y","720","-vh","90","-vv","58.75","-av","1","1","1","-ab","3","-aa","0.25","-ar","256","-ad","256","-as","256","-dc","1","-dt","0","-ds","0","-dj","0","-ss","8.0",$OctFile -RedirectStandardOutput $OutputFile3 -WorkingDirectory (Join-Path $PSScriptRoot $SceneDir) -NoNewWindow -Wait -PassThru
    $elapsed = ((Get-Date) - $start).TotalSeconds
    
    if (!(Test-Path $OutputFile3)) {
        Write-Host "FAIL: Output file not created for $($Exe.Name)" -ForegroundColor Red
        $FailedTests += "$($Exe.Name): Test 3 - Output file not created"
        continue
    }
    
    $size = (Get-Item $OutputFile3).Length
    $roundedTime = [math]::Round($elapsed, 2)
    Write-Host "Render completed in $roundedTime seconds" -ForegroundColor Green
    Write-Host "Output: $OutputFile3" -ForegroundColor Green
    Write-Host "Size: $size bytes" -ForegroundColor Green
    
    if ($size -lt 1000) {
        Write-Host "FAIL: Output too small for $($Exe.Name)" -ForegroundColor Red
        $FailedTests += "$($Exe.Name): Test 3 - Output too small ($size bytes)"
    }
    
    # Test 4: VDS-4361 with irradiance mode
    Write-Host "`n=== Test 4: VDS-4361 with irradiance mode (-i) ===" -ForegroundColor Cyan
    $OutputFile4 = Join-Path $PSScriptRoot "test_output\vds-4361_rpict_irad_$($Exe.Name).hdr"
    
    Write-Host "Rendering with $($Exe.Name) using irradiance mode..." -ForegroundColor Yellow
    $start = Get-Date
    # Run from scene directory to resolve relative paths in octree
    $process = Start-Process -FilePath $Exe.Path -ArgumentList "-vf",$ViewFile,"-x","1280","-y","720","-vh","90","-vv","58.75","-av","1","1","1","-ab","3","-aa","0.25","-ar","256","-ad","512","-as","256","-ss","8.0","-i",$OctFile -RedirectStandardOutput $OutputFile4 -WorkingDirectory (Join-Path $PSScriptRoot $SceneDir) -NoNewWindow -Wait -PassThru
    $elapsed = ((Get-Date) - $start).TotalSeconds
    
    if (!(Test-Path $OutputFile4)) {
        Write-Host "FAIL: Output file not created for $($Exe.Name)" -ForegroundColor Red
        $FailedTests += "$($Exe.Name): Test 4 - Output file not created"
        continue
    }
    
    $size = (Get-Item $OutputFile4).Length
    $roundedTime = [math]::Round($elapsed, 2)
    Write-Host "Render completed in $roundedTime seconds" -ForegroundColor Green
    Write-Host "Output: $OutputFile4" -ForegroundColor Green
    Write-Host "Size: $size bytes" -ForegroundColor Green
    
    if ($size -lt 1000) {
        Write-Host "FAIL: Output too small for $($Exe.Name)" -ForegroundColor Red
        $FailedTests += "$($Exe.Name): Test 4 - Output too small ($size bytes)"
    }
}

# Convert HDR images to viewable PNG format
Write-Host "`n========================================" -ForegroundColor Magenta
Write-Host "Converting HDR images to PNG..." -ForegroundColor Magenta
Write-Host "========================================" -ForegroundColor Magenta

$PfiltExe = Join-Path $BinPath "pfilt.exe"
$RaBmpExe = Join-Path $BinPath "ra_bmp.exe"
$FalsecolorExe = Join-Path $BinPath "falsecolor.exe"
$FalsecolorPl = Join-Path $BinPath "falsecolor.pl"

if ((Test-Path $PfiltExe) -and (Test-Path $RaBmpExe)) {
    $HdrFiles = Get-ChildItem -Path "test_output" -Filter "*.hdr"
    
    foreach ($HdrFile in $HdrFiles) {
        $BmpFile = $HdrFile.FullName -replace '\.hdr$', '.bmp'
        $PngFile = $HdrFile.FullName -replace '\.hdr$', '.png'
        
        Write-Host "Converting $($HdrFile.Name)..." -ForegroundColor Yellow
        
        # Use pfilt for tone mapping and ra_bmp for conversion
        # pfilt with exposure adjustment | ra_bmp
        $pfiltProc = Start-Process -FilePath $PfiltExe -ArgumentList "-e","2",$HdrFile.FullName -NoNewWindow -Wait -PassThru -RedirectStandardOutput "temp_filtered.hdr"
        
        if (Test-Path "temp_filtered.hdr") {
            $raBmpProc = Start-Process -FilePath $RaBmpExe -ArgumentList "temp_filtered.hdr",$BmpFile -NoNewWindow -Wait -PassThru
            
            if (Test-Path $BmpFile) {
                # Convert BMP to PNG if possible (using .NET)
                try {
                    Add-Type -AssemblyName System.Drawing
                    $bmp = [System.Drawing.Image]::FromFile($BmpFile)
                    $bmp.Save($PngFile, [System.Drawing.Imaging.ImageFormat]::Png)
                    $bmp.Dispose()
                    Remove-Item $BmpFile
                    Write-Host "  Created: $($PngFile | Split-Path -Leaf)" -ForegroundColor Green
                } catch {
                    Write-Host "  Created: $($BmpFile | Split-Path -Leaf) (PNG conversion failed)" -ForegroundColor Yellow
                }
            }
            
            Remove-Item "temp_filtered.hdr" -ErrorAction SilentlyContinue
        }
    }
} else {
    Write-Host "Image conversion tools not found. Skipping conversion." -ForegroundColor Yellow
}

# Generate falsecolor images
Write-Host "`n========================================" -ForegroundColor Magenta
Write-Host "Generating falsecolor illuminance maps..." -ForegroundColor Magenta
Write-Host "========================================" -ForegroundColor Magenta

if (Test-Path $FalsecolorExe) {
    $UseFalsecolor = $FalsecolorExe
    $UsePerl = $false
} elseif (Test-Path $FalsecolorPl) {
    $UseFalsecolor = $FalsecolorPl
    $UsePerl = $true
} else {
    $UseFalsecolor = $null
}

if ($UseFalsecolor) {
    $HdrFiles = Get-ChildItem -Path "test_output" -Filter "*.hdr"
    
    foreach ($HdrFile in $HdrFiles) {
        $FalsecolorFile = $HdrFile.FullName -replace '\.hdr$', '_fc.hdr'
        $FalsecolorPngFile = $HdrFile.FullName -replace '\.hdr$', '_fc.png'
        
        Write-Host "Creating falsecolor for $($HdrFile.Name)..." -ForegroundColor Yellow
        
        # Run falsecolor with -s 500 (scale to 500 lux)
        # Use cmd for proper binary redirection
        if ($UsePerl) {
            cmd /c "perl ""$UseFalsecolor"" -i ""$($HdrFile.FullName)"" -s 500 > ""$FalsecolorFile"" 2>&1"
        } else {
            cmd /c """$UseFalsecolor"" -i ""$($HdrFile.FullName)"" -s 500 > ""$FalsecolorFile"" 2>&1"
        }
        
        if (Test-Path $FalsecolorFile) {
            # Convert falsecolor HDR to BMP then PNG
            $FcBmpFile = $FalsecolorFile -replace '\.hdr$', '.bmp'
            
            if (Test-Path $RaBmpExe) {
                $raBmpProc = Start-Process -FilePath $RaBmpExe -ArgumentList $FalsecolorFile,$FcBmpFile -NoNewWindow -Wait -PassThru
                
                if (Test-Path $FcBmpFile) {
                    try {
                        Add-Type -AssemblyName System.Drawing -ErrorAction SilentlyContinue
                        $bmp = [System.Drawing.Image]::FromFile($FcBmpFile)
                        $bmp.Save($FalsecolorPngFile, [System.Drawing.Imaging.ImageFormat]::Png)
                        $bmp.Dispose()
                        Remove-Item $FcBmpFile
                        Remove-Item $FalsecolorFile
                        Write-Host "  Created: $($FalsecolorPngFile | Split-Path -Leaf)" -ForegroundColor Green
                    } catch {
                        Write-Host "  Created: $($FcBmpFile | Split-Path -Leaf) (PNG conversion failed)" -ForegroundColor Yellow
                    }
                }
            }
        }
    }
} else {
    Write-Host "falsecolor.exe not found. Skipping falsecolor generation." -ForegroundColor Yellow
}

Write-Host ""
if ($FailedTests.Count -eq 0) {
    Write-Host "=== ALL RPICT TESTS PASSED ===" -ForegroundColor Green
    exit 0
} else {
    Write-Host "=== SOME TESTS FAILED ===" -ForegroundColor Red
    Write-Host "Failed tests:" -ForegroundColor Red
    foreach ($failure in $FailedTests) {
        Write-Host "  - $failure" -ForegroundColor Red
    }
    exit 1
}
