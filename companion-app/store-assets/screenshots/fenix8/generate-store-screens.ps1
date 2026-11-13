param(
    [string]$OutputDirectory = $PSScriptRoot
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Add-Type -AssemblyName System.Drawing

$CanvasSize = 454
$Center = [single]($CanvasSize / 2)
$Radius = [single](($CanvasSize / 2.0) * 0.75)

$Colors = @{
    Black     = [System.Drawing.Color]::FromArgb(255, 0, 0, 0)
    White     = [System.Drawing.Color]::FromArgb(255, 255, 255, 255)
    LightGray = [System.Drawing.Color]::FromArgb(255, 205, 205, 205)
    DarkGray  = [System.Drawing.Color]::FromArgb(255, 74, 78, 76)
    Green     = [System.Drawing.Color]::FromArgb(255, 0, 255, 32)
    DarkGreen = [System.Drawing.Color]::FromArgb(255, 0, 112, 20)
    Yellow    = [System.Drawing.Color]::FromArgb(255, 255, 204, 0)
    Orange    = [System.Drawing.Color]::FromArgb(255, 255, 102, 0)
    Purple    = [System.Drawing.Color]::FromArgb(255, 190, 70, 255)
    Red       = [System.Drawing.Color]::FromArgb(255, 255, 45, 45)
    DarkRed   = [System.Drawing.Color]::FromArgb(255, 115, 20, 20)
    Blue      = [System.Drawing.Color]::FromArgb(255, 45, 150, 255)
    Cyan      = [System.Drawing.Color]::FromArgb(255, 0, 220, 255)
}

function New-Canvas {
    $bitmap = [System.Drawing.Bitmap]::new(
        $CanvasSize,
        $CanvasSize,
        [System.Drawing.Imaging.PixelFormat]::Format32bppArgb
    )
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $graphics.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
    $graphics.Clear($Colors.Black)
    return @($bitmap, $graphics)
}

function New-Font([single]$Size, [System.Drawing.FontStyle]$Style = [System.Drawing.FontStyle]::Regular) {
    return [System.Drawing.Font]::new('Segoe UI', $Size, $Style, [System.Drawing.GraphicsUnit]::Pixel)
}

function Draw-CenteredText(
    [System.Drawing.Graphics]$Graphics,
    [string]$Text,
    [single]$X,
    [single]$Y,
    [System.Drawing.Font]$Font,
    [System.Drawing.Color]$Color
) {
    $brush = [System.Drawing.SolidBrush]::new($Color)
    $format = [System.Drawing.StringFormat]::new()
    $format.Alignment = [System.Drawing.StringAlignment]::Center
    $format.LineAlignment = [System.Drawing.StringAlignment]::Center
    $Graphics.DrawString($Text, $Font, $brush, $X, $Y, $format)
    $format.Dispose()
    $brush.Dispose()
}

function Draw-LeftText(
    [System.Drawing.Graphics]$Graphics,
    [string]$Text,
    [single]$X,
    [single]$Y,
    [System.Drawing.Font]$Font,
    [System.Drawing.Color]$Color
) {
    $brush = [System.Drawing.SolidBrush]::new($Color)
    $Graphics.DrawString($Text, $Font, $brush, $X, $Y)
    $brush.Dispose()
}

function Draw-PageIndicator([System.Drawing.Graphics]$Graphics, [int]$CurrentPage) {
    $startY = ($CanvasSize / 2) - 24
    for ($i = 0; $i -lt 4; $i++) {
        $color = if ($i -eq $CurrentPage) { $Colors.White } else { $Colors.DarkGray }
        $brush = [System.Drawing.SolidBrush]::new($color)
        $Graphics.FillEllipse($brush, 33, ($startY + ($i * 16) - 3), 6, 6)
        $brush.Dispose()
    }
}

function Draw-Sun([System.Drawing.Graphics]$Graphics, [single]$X, [single]$Y) {
    $sunBrush = [System.Drawing.SolidBrush]::new($Colors.Yellow)
    $sunPen = [System.Drawing.Pen]::new($Colors.Yellow, 2)
    $Graphics.FillEllipse($sunBrush, $X - 8, $Y - 8, 16, 16)
    for ($angle = 0; $angle -lt 360; $angle += 45) {
        $rad = $angle * [Math]::PI / 180.0
        $x1 = $X + [single](12 * [Math]::Cos($rad))
        $y1 = $Y + [single](12 * [Math]::Sin($rad))
        $x2 = $X + [single](18 * [Math]::Cos($rad))
        $y2 = $Y + [single](18 * [Math]::Sin($rad))
        $Graphics.DrawLine($sunPen, $x1, $y1, $x2, $y2)
    }
    $sunPen.Dispose()
    $sunBrush.Dispose()
}

function Polar-Point([single]$Azimuth, [single]$Distance, [single]$MaxDistance = 1.0) {
    $rad = ($Azimuth - 90.0) * [Math]::PI / 180.0
    $r = $Radius * ($Distance / $MaxDistance)
    return [System.Drawing.PointF]::new(
        [single]($Center + ($r * [Math]::Cos($rad))),
        [single]($Center + ($r * [Math]::Sin($rad)))
    )
}

function Save-Canvas(
    [System.Drawing.Bitmap]$Bitmap,
    [System.Drawing.Graphics]$Graphics,
    [string]$FileName
) {
    if (!(Test-Path -LiteralPath $OutputDirectory)) {
        New-Item -ItemType Directory -Path $OutputDirectory | Out-Null
    }
    $path = Join-Path $OutputDirectory $FileName
    $Graphics.Dispose()
    $Bitmap.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
    $Bitmap.Dispose()
    Write-Output $path
}

function New-PanoramaScreenshot {
    $canvas = New-Canvas
    $bitmap = $canvas[0]
    $graphics = $canvas[1]

    $gridPen = [System.Drawing.Pen]::new($Colors.DarkGray, 1)
    $tinyFont = New-Font 15
    foreach ($elevation in @(0, 30, 60)) {
        $padding = $CanvasSize * 0.2
        $y = [single]($CanvasSize - $padding - (($elevation / 90.0) * ($CanvasSize - ($padding * 2))))
        $graphics.DrawLine($gridPen, 0, $y, $CanvasSize, $y)
        Draw-CenteredText $graphics ($elevation.ToString() + [char]0x00B0) 427 ($y - 8) $tinyFont $Colors.DarkGray
    }

    $cardinalFont = New-Font 24 ([System.Drawing.FontStyle]::Bold)
    Draw-CenteredText $graphics 'W' 62 70 $cardinalFont $Colors.LightGray
    Draw-CenteredText $graphics 'N' 227 70 $cardinalFont $Colors.White
    Draw-CenteredText $graphics 'E' 392 70 $cardinalFont $Colors.LightGray

    $pathPen = [System.Drawing.Pen]::new($Colors.Yellow, 3)
    $pathPoints = [System.Drawing.PointF[]]@(
        [System.Drawing.PointF]::new(54, 350),
        [System.Drawing.PointF]::new(105, 284),
        [System.Drawing.PointF]::new(158, 224),
        [System.Drawing.PointF]::new(214, 188),
        [System.Drawing.PointF]::new(270, 192),
        [System.Drawing.PointF]::new(326, 234),
        [System.Drawing.PointF]::new(382, 297),
        [System.Drawing.PointF]::new(430, 351)
    )
    $graphics.DrawCurve($pathPen, $pathPoints, 0.35)

    $terrainBrush = [System.Drawing.SolidBrush]::new($Colors.DarkGreen)
    $terrainPen = [System.Drawing.Pen]::new($Colors.Green, 3)
    $terrain = [System.Drawing.PointF[]]@(
        [System.Drawing.PointF]::new(0, 345),
        [System.Drawing.PointF]::new(36, 315),
        [System.Drawing.PointF]::new(82, 329),
        [System.Drawing.PointF]::new(124, 290),
        [System.Drawing.PointF]::new(173, 310),
        [System.Drawing.PointF]::new(225, 267),
        [System.Drawing.PointF]::new(274, 298),
        [System.Drawing.PointF]::new(325, 259),
        [System.Drawing.PointF]::new(372, 275),
        [System.Drawing.PointF]::new(418, 238),
        [System.Drawing.PointF]::new(454, 273),
        [System.Drawing.PointF]::new(454, 454),
        [System.Drawing.PointF]::new(0, 454)
    )
    $graphics.FillPolygon($terrainBrush, $terrain)
    $graphics.DrawLines($terrainPen, $terrain[0..10])

    $headingPen = [System.Drawing.Pen]::new($Colors.Red, 2)
    $graphics.DrawLine($headingPen, $Center, 91, $Center, 363)

    Draw-Sun $graphics 284 195
    $pulsePen = [System.Drawing.Pen]::new([System.Drawing.Color]::FromArgb(160, $Colors.Yellow), 2)
    $graphics.DrawEllipse($pulsePen, 260, 171, 48, 48)

    $sunriseFont = New-Font 18 ([System.Drawing.FontStyle]::Bold)
    Draw-CenteredText $graphics ([char]0x2191) 54 364 $sunriseFont $Colors.Yellow
    Draw-CenteredText $graphics ([char]0x2193) 430 364 $sunriseFont $Colors.Purple

    Draw-PageIndicator $graphics 0
    Save-Canvas $bitmap $graphics '02-panorama.png'

    $gridPen.Dispose(); $tinyFont.Dispose(); $cardinalFont.Dispose(); $pathPen.Dispose()
    $terrainBrush.Dispose(); $terrainPen.Dispose(); $headingPen.Dispose(); $pulsePen.Dispose(); $sunriseFont.Dispose()
}

function New-SkyPlotScreenshot {
    $canvas = New-Canvas
    $bitmap = $canvas[0]
    $graphics = $canvas[1]

    $gridPen = [System.Drawing.Pen]::new($Colors.DarkGray, 1)
    $graphics.DrawEllipse($gridPen, $Center - $Radius, $Center - $Radius, $Radius * 2, $Radius * 2)
    $graphics.DrawEllipse($gridPen, $Center - ($Radius / 2), $Center - ($Radius / 2), $Radius, $Radius)
    $graphics.DrawLine($gridPen, $Center, $Center - $Radius, $Center, $Center + $Radius)
    $graphics.DrawLine($gridPen, $Center - $Radius, $Center, $Center + $Radius, $Center)

    $cardinalFont = New-Font 22 ([System.Drawing.FontStyle]::Bold)
    Draw-CenteredText $graphics 'N' $Center 35 $cardinalFont $Colors.White
    Draw-CenteredText $graphics 'E' 420 $Center $cardinalFont $Colors.LightGray
    Draw-CenteredText $graphics 'S' $Center 419 $cardinalFont $Colors.LightGray
    Draw-CenteredText $graphics 'W' 34 $Center $cardinalFont $Colors.LightGray

    $terrainOutline = New-Object System.Collections.Generic.List[System.Drawing.PointF]
    $outerOutline = New-Object System.Collections.Generic.List[System.Drawing.PointF]
    for ($az = 0; $az -lt 360; $az += 10) {
        $elevation = 11 + (9 * [Math]::Sin(($az + 25) * [Math]::PI / 70)) + (5 * [Math]::Sin($az * [Math]::PI / 24))
        $elevation = [Math]::Max(3, [Math]::Min(29, $elevation))
        $terrainOutline.Add((Polar-Point $az ([single](1 - ($elevation / 90.0)))))
        $outerOutline.Add((Polar-Point $az 1.0))
    }
    $terrainPolygon = New-Object System.Collections.Generic.List[System.Drawing.PointF]
    foreach ($p in $terrainOutline) { $terrainPolygon.Add($p) }
    for ($i = $outerOutline.Count - 1; $i -ge 0; $i--) { $terrainPolygon.Add($outerOutline[$i]) }
    $terrainBrush = [System.Drawing.SolidBrush]::new($Colors.DarkGreen)
    $terrainPen = [System.Drawing.Pen]::new($Colors.Green, 2)
    $graphics.FillPolygon($terrainBrush, $terrainPolygon.ToArray())
    $graphics.DrawClosedCurve($terrainPen, $terrainOutline.ToArray(), 0.25, [System.Drawing.Drawing2D.FillMode]::Alternate)

    $sunPath = New-Object System.Collections.Generic.List[System.Drawing.PointF]
    for ($az = 75; $az -le 285; $az += 10) {
        $elevation = 4 + (56 * [Math]::Sin((($az - 75) / 210.0) * [Math]::PI))
        $sunPath.Add((Polar-Point $az ([single](1 - ($elevation / 90.0)))))
    }
    $sunPen = [System.Drawing.Pen]::new($Colors.Yellow, 3)
    $graphics.DrawCurve($sunPen, $sunPath.ToArray(), 0.2)

    $headingPoint = Polar-Point 32 1.0
    $headingPen = [System.Drawing.Pen]::new($Colors.Red, 2)
    $graphics.DrawLine($headingPen, $Center, $Center, $headingPoint.X, $headingPoint.Y)
    $terrainMarker = Polar-Point 32 0.78
    $markerBrush = [System.Drawing.SolidBrush]::new($Colors.Blue)
    $graphics.FillEllipse($markerBrush, $terrainMarker.X - 5, $terrainMarker.Y - 5, 10, 10)

    $currentSun = Polar-Point 142 0.47
    Draw-Sun $graphics $currentSun.X $currentSun.Y
    $pulsePen = [System.Drawing.Pen]::new([System.Drawing.Color]::FromArgb(150, $Colors.Yellow), 2)
    $graphics.DrawEllipse($pulsePen, $currentSun.X - 23, $currentSun.Y - 23, 46, 46)

    Draw-PageIndicator $graphics 1
    Save-Canvas $bitmap $graphics '03-sky-plot.png'

    $gridPen.Dispose(); $cardinalFont.Dispose(); $terrainBrush.Dispose(); $terrainPen.Dispose()
    $sunPen.Dispose(); $headingPen.Dispose(); $markerBrush.Dispose(); $pulsePen.Dispose()
}

function New-RadarScreenshot {
    $canvas = New-Canvas
    $bitmap = $canvas[0]
    $graphics = $canvas[1]

    $gridPen = [System.Drawing.Pen]::new($Colors.DarkGray, 1)
    foreach ($fraction in @(0.33, 0.66, 1.0)) {
        $r = $Radius * $fraction
        $graphics.DrawEllipse($gridPen, $Center - $r, $Center - $r, $r * 2, $r * 2)
    }
    $graphics.DrawLine($gridPen, $Center, $Center - $Radius, $Center, $Center + $Radius)
    $graphics.DrawLine($gridPen, $Center - $Radius, $Center, $Center + $Radius, $Center)

    $cardinalFont = New-Font 22 ([System.Drawing.FontStyle]::Bold)
    $tinyFont = New-Font 14
    Draw-CenteredText $graphics 'N' $Center 35 $cardinalFont $Colors.White
    Draw-CenteredText $graphics 'E' 420 $Center $cardinalFont $Colors.LightGray
    Draw-CenteredText $graphics 'S' $Center 419 $cardinalFont $Colors.LightGray
    Draw-CenteredText $graphics 'W' 34 $Center $cardinalFont $Colors.LightGray
    Draw-LeftText $graphics '10' 286 229 $tinyFont $Colors.DarkGray
    Draw-LeftText $graphics '20' 342 229 $tinyFont $Colors.DarkGray
    Draw-LeftText $graphics '30' 398 229 $tinyFont $Colors.DarkGray

    $terrain = New-Object System.Collections.Generic.List[System.Drawing.PointF]
    for ($az = 0; $az -lt 360; $az += 10) {
        $distance = 0.35 + (0.20 * [Math]::Sin(($az + 35) * [Math]::PI / 80)) + (0.16 * [Math]::Sin($az * [Math]::PI / 30))
        $distance = [Math]::Max(0.18, [Math]::Min(0.78, $distance))
        $terrain.Add((Polar-Point $az ([single]$distance)))
    }
    $terrainBrush = [System.Drawing.SolidBrush]::new($Colors.DarkGreen)
    $terrainPen = [System.Drawing.Pen]::new($Colors.Green, 2)
    $graphics.FillPolygon($terrainBrush, $terrain.ToArray())
    $graphics.DrawClosedCurve($terrainPen, $terrain.ToArray(), 0.25, [System.Drawing.Drawing2D.FillMode]::Alternate)

    $heading = 32
    foreach ($offset in @(-15, -10, -5, 5, 10, 15)) {
        $p = Polar-Point ($heading + $offset) 1.0
        $beamEdgePen = [System.Drawing.Pen]::new($Colors.DarkRed, 1)
        $graphics.DrawLine($beamEdgePen, $Center, $Center, $p.X, $p.Y)
        $beamEdgePen.Dispose()
    }
    $beamPoint = Polar-Point $heading 1.0
    $beamPen = [System.Drawing.Pen]::new($Colors.Red, 2)
    $graphics.DrawLine($beamPen, $Center, $Center, $beamPoint.X, $beamPoint.Y)

    $labelPoint = Polar-Point $heading 0.70
    $labelFont = New-Font 16 ([System.Drawing.FontStyle]::Bold)
    $labelBrush = [System.Drawing.SolidBrush]::new($Colors.Black)
    $graphics.FillRectangle($labelBrush, $labelPoint.X - 25, $labelPoint.Y - 12, 50, 24)
    Draw-CenteredText $graphics '14.2 km' $labelPoint.X $labelPoint.Y $labelFont $Colors.White

    $sunPoint = Polar-Point 142 0.91
    $sunLinePen = [System.Drawing.Pen]::new($Colors.Yellow, 1)
    $graphics.DrawLine($sunLinePen, $Center, $Center, $sunPoint.X, $sunPoint.Y)
    Draw-Sun $graphics $sunPoint.X $sunPoint.Y

    $sonarPen = [System.Drawing.Pen]::new([System.Drawing.Color]::FromArgb(170, $Colors.Cyan), 2)
    $graphics.DrawArc($sonarPen, $Center - 108, $Center - 108, 216, 216, -70, 115)
    $sweepPoint = Polar-Point 108 0.82
    $graphics.DrawLine($sonarPen, $Center, $Center, $sweepPoint.X, $sweepPoint.Y)

    Draw-PageIndicator $graphics 2
    Save-Canvas $bitmap $graphics '04-radar.png'

    $gridPen.Dispose(); $cardinalFont.Dispose(); $tinyFont.Dispose(); $terrainBrush.Dispose(); $terrainPen.Dispose()
    $beamPen.Dispose(); $labelFont.Dispose(); $labelBrush.Dispose(); $sunLinePen.Dispose(); $sonarPen.Dispose()
}

function Draw-DetailsIcon(
    [System.Drawing.Graphics]$Graphics,
    [single]$X,
    [single]$Y,
    [System.Drawing.Color]$Color,
    [string]$Kind
) {
    $pen = [System.Drawing.Pen]::new($Color, 3)
    $brush = [System.Drawing.SolidBrush]::new($Color)
    if ($Kind -eq 'heading') {
        $graphics.DrawArc($pen, $X - 17, $Y - 17, 34, 34, 205, 110)
        $graphics.DrawLine($pen, $X, $Y + 8, $X + 13, $Y - 11)
        $graphics.FillEllipse($brush, $X - 3, $Y + 5, 6, 6)
    } else {
        $graphics.FillEllipse($brush, $X - 8, $Y - 8, 16, 16)
        $graphics.DrawLine($pen, $X - 18, $Y + 13, $X + 18, $Y + 13)
        $arrowY = if ($Kind -eq 'rise') { $Y + 22 } else { $Y + 4 }
        $arrowEndY = if ($Kind -eq 'rise') { $Y + 7 } else { $Y + 19 }
        $graphics.DrawLine($pen, $X, $arrowY, $X, $arrowEndY)
        $graphics.DrawLine($pen, $X, $arrowEndY, $X - 5, ($arrowEndY + $(if ($Kind -eq 'rise') { 5 } else { -5 })))
        $graphics.DrawLine($pen, $X, $arrowEndY, $X + 5, ($arrowEndY + $(if ($Kind -eq 'rise') { 5 } else { -5 })))
    }
    $pen.Dispose(); $brush.Dispose()
}

function New-DetailsScreenshot {
    $canvas = New-Canvas
    $bitmap = $canvas[0]
    $graphics = $canvas[1]

    $separatorPen = [System.Drawing.Pen]::new($Colors.DarkGray, 1)
    $graphics.DrawLine($separatorPen, 91, 168, 363, 168)
    $graphics.DrawLine($separatorPen, 91, 281, 363, 281)

    $labelFont = New-Font 19 ([System.Drawing.FontStyle]::Bold)
    $valueFont = New-Font 29
    $rows = @(
        @{ Y = 114; Label = 'SUNRISE'; Value = '7:20 (10/25)'; Color = $Colors.Yellow; Kind = 'rise' },
        @{ Y = 227; Label = 'SUNSET'; Value = '18:05 (10/25)'; Color = $Colors.Purple; Kind = 'set' },
        @{ Y = 340; Label = 'HEADING'; Value = '26.0' + [char]0x00B0; Color = $Colors.Green; Kind = 'heading' }
    )
    foreach ($row in $rows) {
        Draw-DetailsIcon $graphics 145 $row.Y $row.Color $row.Kind
        Draw-LeftText $graphics $row.Label 204 ($row.Y - 37) $labelFont $Colors.LightGray
        Draw-LeftText $graphics $row.Value 204 ($row.Y - 10) $valueFont $Colors.White
    }

    Draw-PageIndicator $graphics 3
    Save-Canvas $bitmap $graphics '05-details.png'

    $separatorPen.Dispose(); $labelFont.Dispose(); $valueFont.Dispose()
}

$generated = @()
$generated += New-PanoramaScreenshot
$generated += New-SkyPlotScreenshot
$generated += New-RadarScreenshot
$generated += New-DetailsScreenshot

Write-Output ('Generated {0} store screenshots.' -f $generated.Count)
