Add-Type -AssemblyName System.Drawing

$outDir = Join-Path $PSScriptRoot ''
$green = [System.Drawing.ColorTranslator]::FromHtml('#355F4F')
$canvas = [System.Drawing.ColorTranslator]::FromHtml('#F7F8F7')
$ink = [System.Drawing.ColorTranslator]::FromHtml('#252725')
$muted = [System.Drawing.ColorTranslator]::FromHtml('#7B807D')
$line = [System.Drawing.ColorTranslator]::FromHtml('#E5E8E6')
$surface = [System.Drawing.ColorTranslator]::FromHtml('#E9EFEB')
$white = [System.Drawing.Color]::White

function New-Font([float]$size, [System.Drawing.FontStyle]$style = [System.Drawing.FontStyle]::Regular) {
    return New-Object System.Drawing.Font('Segoe UI', $size, $style, [System.Drawing.GraphicsUnit]::Pixel)
}
function Text($g, [string]$value, [float]$x, [float]$y, [float]$size = 13, [System.Drawing.Color]$color = $script:ink, [System.Drawing.FontStyle]$style = [System.Drawing.FontStyle]::Regular) {
    $font = New-Font $size $style
    $brush = New-Object System.Drawing.SolidBrush($color)
    $g.DrawString($value, $font, $brush, $x, $y)
    $brush.Dispose(); $font.Dispose()
}
function Box($g, [float]$x, [float]$y, [float]$w, [float]$h, [System.Drawing.Color]$color, [float]$radius = 12, [System.Drawing.Color]$stroke = [System.Drawing.Color]::Empty) {
    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
    $d = $radius * 2
    $path.AddArc($x, $y, $d, $d, 180, 90); $path.AddArc($x + $w - $d, $y, $d, $d, 270, 90)
    $path.AddArc($x + $w - $d, $y + $h - $d, $d, $d, 0, 90); $path.AddArc($x, $y + $h - $d, $d, $d, 90, 90)
    $path.CloseFigure()
    $brush = New-Object System.Drawing.SolidBrush($color); $g.FillPath($brush, $path); $brush.Dispose()
    if ($stroke -ne [System.Drawing.Color]::Empty) { $pen = New-Object System.Drawing.Pen($stroke, 1); $g.DrawPath($pen, $path); $pen.Dispose() }
    $path.Dispose()
}
function New-Canvas {
    $bitmap = New-Object System.Drawing.Bitmap(393, 852)
    $g = [System.Drawing.Graphics]::FromImage($bitmap)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
    $g.Clear($script:canvas)
    Text $g '9:41' 24 15 16 $script:ink ([System.Drawing.FontStyle]::Bold)
    Text $g '●●●  ◉  ▰' 300 16 14 $script:ink
    Box $g 0 52 393 80 $script:white 24
    Text $g '☰' 24 77 22 $script:ink
    Text $g '↗ Meldingen' 133 76 22 $script:green ([System.Drawing.FontStyle]::Bold)
    return @($bitmap, $g)
}
function Draw-Controls($g) {
    Text $g 'Je meldingen' 20 153 15 $script:green ([System.Drawing.FontStyle]::Bold)
    Text $g 'Alles wat jouw aandacht nodig heeft.' 20 176 11 $script:muted
    Box $g 20 202 126 34 $script:green 17; Text $g 'Alle meldingen' 34 211 11 $script:white ([System.Drawing.FontStyle]::Bold)
    Box $g 153 202 104 34 $script:surface 17; Text $g 'Ongelezen (2)' 166 211 11 $script:muted
    Box $g 20 247 307 40 $script:white 10 $script:line; Text $g '⌕   Zoek in meldingen' 33 259 12 $script:muted
    Box $g 336 247 37 40 $script:surface 10; Text $g '▽' 346 256 16 $script:green
}
function Draw-Row($g, [float]$y, [string]$icon, [string]$title, [string]$person, [string]$time, [bool]$unread = $true) {
    $fill = if ($unread) { $script:surface } else { $script:white }
    Box $g 20 $y 353 76 $fill 13 $(if ($unread) { $fill } else { $script:line })
    Box $g 31 ($y + 13) 38 38 $script:white 11
    Text $g $icon 42 ($y + 20) 17 $script:green ([System.Drawing.FontStyle]::Bold)
    Text $g $title 79 ($y + 12) 12 $script:ink ([System.Drawing.FontStyle]::Bold)
    Text $g $person 79 ($y + 30) 11 $script:ink
    Text $g $time 79 ($y + 52) 10 $script:muted
    Text $g 'Bekijk melding  →' 239 ($y + 51) 10 $script:green
    if ($unread) { $b = New-Object System.Drawing.SolidBrush($script:green); $g.FillEllipse($b, 359, ($y + 16), 6, 6); $b.Dispose() }
}
function Save-Screen($bitmap, $g, [string]$name) {
    $bitmap.Save((Join-Path $script:outDir $name), [System.Drawing.Imaging.ImageFormat]::Png)
    $g.Dispose(); $bitmap.Dispose()
}

$pair = New-Canvas; $bitmap = $pair[0]; $g = $pair[1]; Draw-Controls $g
Text $g 'Vandaag' 20 306 11 $muted; Text $g '1 ongelezen' 306 306 10 $green
Draw-Row $g 326 '✓' 'Bewijs geverifieerd' 'Middelbaar College' '10:20' $true
Text $g 'Gisteren' 20 418 11 $muted
Draw-Row $g 438 '◉' 'Stagegesprek met Ayla' 'Ayla' '11:30' $false
Text $g 'Voorbeeld met fictieve meldingen' 97 540 10 $muted
Save-Screen $bitmap $g 'notifications-learner.png'

$pair = New-Canvas; $bitmap = $pair[0]; $g = $pair[1]; Draw-Controls $g
Text $g 'Vandaag' 20 306 11 $muted; Text $g '2 ongelezen' 306 306 10 $green
Draw-Row $g 326 '✓' 'Verificatie aanvraag' 'Gianna Beenen' '10:20' $true
Draw-Row $g 412 '✓' 'Verificatie aanvraag' 'Daaf Heijnekamp' '10:30' $true
Text $g 'Gisteren' 20 508 11 $muted
Draw-Row $g 528 '◉' 'Gesprek voor stage' 'Gianna Beenen' '11:30' $false
Text $g 'Alleen toegewezen aanvragen verschijnen' 65 625 10 $muted
Save-Screen $bitmap $g 'notifications-reviewer.png'

$pair = New-Canvas; $bitmap = $pair[0]; $g = $pair[1]
Text $g '←  Terug naar meldingen' 20 151 11 $green
Text $g 'Verificatie aanvraag' 20 179 20 $ink ([System.Drawing.FontStyle]::Bold)
Box $g 20 216 353 54 $surface 12; Box $g 31 226 34 34 $white 17
Text $g 'GB' 38 236 11 $green ([System.Drawing.FontStyle]::Bold); Text $g 'Gianna Beenen' 75 226 12 $ink ([System.Drawing.FontStyle]::Bold); Text $g 'Verstuurd om 10:20' 75 244 10 $muted
Box $g 20 288 353 240 $white 16 $line; Box $g 20 288 353 56 ([System.Drawing.ColorTranslator]::FromHtml('#DEECD2')) 16
Box $g 34 320 49 49 ([System.Drawing.ColorTranslator]::FromHtml('#82BC19')) 25 $white; Text $g 'PLUS' 42 338 11 $white ([System.Drawing.FontStyle]::Bold)
Text $g 'Leidinggevende' 35 383 14 $ink ([System.Drawing.FontStyle]::Bold); Box $g 265 376 96 23 ([System.Drawing.ColorTranslator]::FromHtml('#FFF0D9')) 8; Text $g 'In afwachting' 276 381 9 ([System.Drawing.ColorTranslator]::FromHtml('#A56B20'))
Text $g 'Werkervaring' 35 408 10 $muted; Text $g '▦  Plus Laurijssen Oosterhout' 35 432 11 $ink; Text $g '▢  nov 2025 - nu' 35 457 11 $ink
Text $g 'Vaardigheden' 35 487 10 $muted; Text $g 'Leiderschap   Communicatie   +2' 35 504 10 $ink
Text $g 'Document' 20 550 11 $muted
Box $g 20 569 353 55 $white 11 $line; Text $g '▤' 33 583 18 $green; Text $g 'Bewijsstuk.pdf' 61 588 11 $ink; Text $g 'Bekijk  ↗' 305 588 10 $green
Text $g 'Het originele bestand opent tijdelijk in Quick Look.' 20 638 10 $muted
Box $g 20 671 353 49 $green 25; Text $g '✓  Verifieer document' 126 687 13 $white ([System.Drawing.FontStyle]::Bold)
Box $g 20 730 353 49 $surface 25; Text $g 'Aanvraag afwijzen' 143 746 13 $green ([System.Drawing.FontStyle]::Bold)
Save-Screen $bitmap $g 'notifications-verification-detail.png'
