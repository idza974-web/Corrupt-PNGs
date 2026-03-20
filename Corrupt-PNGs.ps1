# Corrupt-PNGs.ps1
# Applies visual glitch effects to all PNGs in a directory recursively.
# Output PNGs are valid files that still open — they just look messed up.
#
# Usage:
#   .\Corrupt-PNGs.ps1 -Directory "C:\path\to\folder"
#   .\Corrupt-PNGs.ps1 -Directory "C:\path\to\folder" -Intensity 1
#   .\Corrupt-PNGs.ps1 -Directory "C:\path\to\folder" -BackupOriginals
#   .\Corrupt-PNGs.ps1 -Directory "C:\path\to\folder" -OutputDirectory "C:\glitched"

param(
    [Parameter(Mandatory = $true)]
    [string]$Directory,

    [Parameter(Mandatory = $false)]
    [ValidateRange(0.1, 1.0)]
    [double]$Intensity = 0.5,

    [Parameter(Mandatory = $false)]
    [switch]$BackupOriginals,

    [Parameter(Mandatory = $false)]
    [string]$OutputDirectory
)

Add-Type -AssemblyName System.Drawing

# -- helpers ------------------------------------------------------------------

function Get-RandomEffect {
    $effects = @(
        'PixelSort',
        'ChannelShift',
        'ScanlineGlitch',
        'BlockCorruption',
        'ColorInvert',
        'ChannelDrop',
        'HorizontalTear',
        'Pixelate'
    )
    return $effects | Get-Random -Count ($effects.Count) | Select-Object -First ([math]::Max(1, [math]::Round($Intensity * 3)))
}

function Apply-PixelSort {
    param($bmp, $intensity)
    $rand = [System.Random]::new()
    $height = $bmp.Height
    $width  = $bmp.Width
    if ($width -lt 2) { return }
    $numRows = [math]::Max(1, [int]($height * $intensity * 0.4))

    for ($i = 0; $i -lt $numRows; $i++) {
        $y      = $rand.Next(0, $height)
        $xStart = $rand.Next(0, $width - 1)
        $maxEnd = [math]::Min($width, $xStart + [int]($width * 0.6 * $intensity) + 10)
        if ($maxEnd -le $xStart + 1) { continue }
        $xEnd   = $rand.Next($xStart + 1, $maxEnd)

        $pixels = @()
        for ($x = $xStart; $x -lt $xEnd; $x++) {
            $pixels += $bmp.GetPixel($x, $y)
        }

        $sorted = $pixels | Sort-Object { ($_.R * 299 + $_.G * 587 + $_.B * 114) / 1000 }

        for ($x = $xStart; $x -lt $xEnd; $x++) {
            $bmp.SetPixel($x, $y, $sorted[$x - $xStart])
        }
    }
}

function Apply-ChannelShift {
    param($bmp, $intensity)
    $rand   = [System.Random]::new()
    $shift  = [int]($bmp.Width * 0.05 * $intensity) + $rand.Next(5, 30)
    $clone  = $bmp.Clone()

    $height = $bmp.Height
    $width  = $bmp.Width

    for ($y = 0; $y -lt $height; $y++) {
        for ($x = 0; $x -lt $width; $x++) {
            $srcX = [math]::Abs(($x + $shift) % $width)
            $p1   = $clone.GetPixel($srcX, $y)   # shifted pixel (red channel donor)
            $p2   = $clone.GetPixel($x, $y)       # original pixel
            $color = [System.Drawing.Color]::FromArgb(
                $p2.A,
                $p1.R,
                $p2.G,
                $p2.B
            )
            $bmp.SetPixel($x, $y, $color)
        }
    }
    $clone.Dispose()
}

function Apply-ScanlineGlitch {
    param($bmp, $intensity)
    $rand      = [System.Random]::new()
    if ($bmp.Width -lt 2) { return }
    $numGlitch = [math]::Max(2, [int]($bmp.Height * $intensity * 0.15))

    for ($i = 0; $i -lt $numGlitch; $i++) {
        $y        = $rand.Next(0, $bmp.Height)
        $offsetX  = $rand.Next(-[int]($bmp.Width * 0.3 * $intensity), [int]($bmp.Width * 0.3 * $intensity))
        $thickness = $rand.Next(1, [math]::Max(2, [int](8 * $intensity)))

        for ($dy = 0; $dy -lt $thickness; $dy++) {
            $row = $y + $dy
            if ($row -ge $bmp.Height) { break }
            $rowPixels = @()
            for ($x = 0; $x -lt $bmp.Width; $x++) {
                $rowPixels += $bmp.GetPixel($x, $row)
            }
            for ($x = 0; $x -lt $bmp.Width; $x++) {
                $srcX = (($x - $offsetX) % $bmp.Width + $bmp.Width) % $bmp.Width
                $srcX = [math]::Max(0, [math]::Min($bmp.Width - 1, $srcX))
                $bmp.SetPixel($x, $row, $rowPixels[$srcX])
            }
        }
    }
}

function Apply-BlockCorruption {
    param($bmp, $intensity)
    $rand     = [System.Random]::new()
    $w = $bmp.Width
    $h = $bmp.Height
    if ($w -lt 2 -or $h -lt 2) { return }
    $numBlocks = [math]::Max(3, [int](30 * $intensity))

    for ($i = 0; $i -lt $numBlocks; $i++) {
        $blockW = [math]::Min($w, $rand.Next(2, [math]::Max(3, [int]($w * 0.2 * $intensity) + 2)))
        $blockH = [math]::Min($h, $rand.Next(2, [math]::Max(3, [int]($h * 0.1 * $intensity) + 2)))

        # Clamp dest and source so block never exceeds image bounds
        $bx   = $rand.Next(0, $w - $blockW + 1)
        $by   = $rand.Next(0, $h - $blockH + 1)
        $srcX = $rand.Next(0, $w - $blockW + 1)
        $srcY = $rand.Next(0, $h - $blockH + 1)

        for ($dy = 0; $dy -lt $blockH; $dy++) {
            for ($dx = 0; $dx -lt $blockW; $dx++) {
                $px = [math]::Min($srcX + $dx, $w - 1)
                $py = [math]::Min($srcY + $dy, $h - 1)
                $tx = [math]::Min($bx  + $dx, $w - 1)
                $ty = [math]::Min($by  + $dy, $h - 1)
                $p = $bmp.GetPixel($px, $py)
                $bmp.SetPixel($tx, $ty, $p)
            }
        }
    }
}

function Apply-ColorInvert {
    param($bmp, $intensity)
    $rand       = [System.Random]::new()
    if ($bmp.Width -lt 2 -or $bmp.Height -lt 2) {
        # Just invert the whole image for tiny sprites
        for ($y = 0; $y -lt $bmp.Height; $y++) {
            for ($x = 0; $x -lt $bmp.Width; $x++) {
                $p = $bmp.GetPixel($x, $y)
                $bmp.SetPixel($x, $y, [System.Drawing.Color]::FromArgb($p.A, 255-$p.R, 255-$p.G, 255-$p.B))
            }
        }
        return
    }
    $numRegions = [math]::Max(1, [int](5 * $intensity))

    for ($i = 0; $i -lt $numRegions; $i++) {
        $rw = [math]::Min($bmp.Width,  $rand.Next(2, [math]::Max(3, [int]($bmp.Width  * 0.4 * $intensity) + 1)))
        $rh = [math]::Min($bmp.Height, $rand.Next(1, [math]::Max(2, [int]($bmp.Height * 0.2 * $intensity) + 1)))
        $rx = $rand.Next(0, [math]::Max(1, $bmp.Width  - $rw))
        $ry = $rand.Next(0, [math]::Max(1, $bmp.Height - $rh))

        for ($dy = 0; $dy -lt $rh; $dy++) {
            for ($dx = 0; $dx -lt $rw; $dx++) {
                $p = $bmp.GetPixel($rx + $dx, $ry + $dy)
                $inv = [System.Drawing.Color]::FromArgb($p.A, 255 - $p.R, 255 - $p.G, 255 - $p.B)
                $bmp.SetPixel($rx + $dx, $ry + $dy, $inv)
            }
        }
    }
}

function Apply-ChannelDrop {
    param($bmp, $intensity)
    $rand    = [System.Random]::new()
    $channel = @('R', 'G', 'B') | Get-Random

    $height = $bmp.Height
    $width  = $bmp.Width

    for ($y = 0; $y -lt $height; $y++) {
        if ($rand.NextDouble() -gt $intensity * 0.7) { continue }
        for ($x = 0; $x -lt $width; $x++) {
            $p = $bmp.GetPixel($x, $y)
            $color = switch ($channel) {
                'R' { [System.Drawing.Color]::FromArgb($p.A, 0,    $p.G, $p.B) }
                'G' { [System.Drawing.Color]::FromArgb($p.A, $p.R, 0,    $p.B) }
                'B' { [System.Drawing.Color]::FromArgb($p.A, $p.R, $p.G, 0   ) }
            }
            $bmp.SetPixel($x, $y, $color)
        }
    }
}

function Apply-HorizontalTear {
    param($bmp, $intensity)
    $rand    = [System.Random]::new()
    if ($bmp.Width -lt 2) { return }
    $numTears = [math]::Max(1, [int](6 * $intensity))

    for ($i = 0; $i -lt $numTears; $i++) {
        $y1 = $rand.Next(0, $bmp.Height)
        $y2 = [math]::Min($bmp.Height - 1, $y1 + $rand.Next(1, [math]::Max(2, [int](20 * $intensity))))

        $maxShift = [math]::Max(1, [int]($bmp.Width * 0.5 * $intensity))
        $shift = $rand.Next(0, $maxShift)
        $direction = if ($rand.Next(2) -eq 0) { 1 } else { -1 }

        for ($y = $y1; $y -le $y2; $y++) {
            $rowPixels = @()
            for ($x = 0; $x -lt $bmp.Width; $x++) {
                $rowPixels += $bmp.GetPixel($x, $y)
            }
            for ($x = 0; $x -lt $bmp.Width; $x++) {
                $srcX = (($x - $shift * $direction) % $bmp.Width + $bmp.Width) % $bmp.Width
                $srcX = [math]::Max(0, [math]::Min($bmp.Width - 1, $srcX))
                $bmp.SetPixel($x, $y, $rowPixels[$srcX])
            }
        }
    }
}

function Apply-Pixelate {
    param($bmp, $intensity)
    $rand      = [System.Random]::new()
    $blockSize = [math]::Max(4, [int](20 * $intensity))
    $numRegions = [math]::Max(2, [int](8 * $intensity))

    for ($i = 0; $i -lt $numRegions; $i++) {
        $rw = $rand.Next($blockSize * 3, [math]::Max($blockSize * 4, [int]($bmp.Width  * 0.35)))
        $rh = $rand.Next($blockSize * 2, [math]::Max($blockSize * 3, [int]($bmp.Height * 0.25)))
        $rx = $rand.Next(0, [math]::Max(1, $bmp.Width  - $rw))
        $ry = $rand.Next(0, [math]::Max(1, $bmp.Height - $rh))

        $by = $ry
        while ($by -lt ($ry + $rh)) {
            $bx = $rx
            while ($bx -lt ($rx + $rw)) {
                # Average color in block
                $rSum = 0; $gSum = 0; $bSum = 0; $aSum = 0; $count = 0
                for ($dy = 0; $dy -lt $blockSize -and ($by + $dy) -lt $bmp.Height; $dy++) {
                    for ($dx = 0; $dx -lt $blockSize -and ($bx + $dx) -lt $bmp.Width; $dx++) {
                        $p = $bmp.GetPixel($bx + $dx, $by + $dy)
                        $rSum += $p.R; $gSum += $p.G; $bSum += $p.B; $aSum += $p.A; $count++
                    }
                }
                if ($count -gt 0) {
                    $avg = [System.Drawing.Color]::FromArgb(
                        [int]($aSum / $count),
                        [int]($rSum / $count),
                        [int]($gSum / $count),
                        [int]($bSum / $count)
                    )
                    for ($dy = 0; $dy -lt $blockSize -and ($by + $dy) -lt $bmp.Height; $dy++) {
                        for ($dx = 0; $dx -lt $blockSize -and ($bx + $dx) -lt $bmp.Width; $dx++) {
                            $bmp.SetPixel($bx + $dx, $by + $dy, $avg)
                        }
                    }
                }
                $bx += $blockSize
            }
            $by += $blockSize
        }
    }
}

# -- main ---------------------------------------------------------------------

if (-not (Test-Path $Directory)) {
    Write-Error "Directory not found: $Directory"
    exit 1
}

if ($OutputDirectory -and -not (Test-Path $OutputDirectory)) {
    New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
    Write-Host "Created output directory: $OutputDirectory"
}

$pngFiles = Get-ChildItem -Path $Directory -Recurse -Filter "*.png"

if ($pngFiles.Count -eq 0) {
    Write-Host "No PNG files found in $Directory"
    exit 0
}

Write-Host ""
Write-Host "Found $($pngFiles.Count) PNG file(s). Intensity: $Intensity"
Write-Host ("-" * 60)

$success = 0
$failed  = 0

foreach ($file in $pngFiles) {
    try {
        Write-Host "Processing: $($file.Name)" -NoNewline

        # Backup if requested
        if ($BackupOriginals) {
            $backupPath = "$($file.FullName).bak"
            Copy-Item -Path $file.FullName -Destination $backupPath -Force
        }

        # Load bitmap
        $bmp = [System.Drawing.Bitmap]::new($file.FullName)

        # Convert to Format32bppArgb for full pixel manipulation
        $editable = [System.Drawing.Bitmap]::new($bmp.Width, $bmp.Height, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
        $gfx = [System.Drawing.Graphics]::FromImage($editable)
        $gfx.DrawImage($bmp, 0, 0)
        $gfx.Dispose()
        $bmp.Dispose()

        # Choose and apply random effects
        $effects = Get-RandomEffect
        $effectNames = $effects -join ", "
        Write-Host " → $effectNames" -NoNewline

        foreach ($effect in $effects) {
            switch ($effect) {
                'PixelSort'       { Apply-PixelSort       $editable $Intensity }
                'ChannelShift'    { Apply-ChannelShift    $editable $Intensity }
                'ScanlineGlitch'  { Apply-ScanlineGlitch  $editable $Intensity }
                'BlockCorruption' { Apply-BlockCorruption $editable $Intensity }
                'ColorInvert'     { Apply-ColorInvert     $editable $Intensity }
                'ChannelDrop'     { Apply-ChannelDrop     $editable $Intensity }
                'HorizontalTear'  { Apply-HorizontalTear  $editable $Intensity }
                'Pixelate'        { Apply-Pixelate        $editable $Intensity }
            }
        }

        # Determine save path
        if ($OutputDirectory) {
            $relativePath = $file.FullName.Substring($Directory.TrimEnd('\', '/').Length).TrimStart('\', '/')
            $savePath = Join-Path $OutputDirectory $relativePath
            $saveDir  = Split-Path $savePath -Parent
            if (-not (Test-Path $saveDir)) {
                New-Item -ItemType Directory -Path $saveDir -Force | Out-Null
            }
        } else {
            $savePath = $file.FullName
        }

        # Save as PNG (valid file, visually corrupted)
        $editable.Save($savePath, [System.Drawing.Imaging.ImageFormat]::Png)
        $editable.Dispose()

        Write-Host " ✓" -ForegroundColor Green
        $success++
    }
    catch {
        Write-Host " ✗ ERROR: $_" -ForegroundColor Red
        $failed++
        if ($editable) { try { $editable.Dispose() } catch {} }
        if ($bmp)      { try { $bmp.Dispose()      } catch {} }
    }
}

Write-Host ("-" * 60)
Write-Host "Done. Success: $success  Failed: $failed"
if ($BackupOriginals) {
    Write-Host "Originals backed up as *.png.bak alongside each file."
}
