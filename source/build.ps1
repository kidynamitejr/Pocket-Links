# Builds the installable home-screen version of Pocket Links into ./site
# Run again after editing game.html.
$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
$out = Join-Path $root 'site'
New-Item -ItemType Directory -Force $out | Out-Null

$head = @'
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
<link rel="manifest" href="manifest.webmanifest">
<link rel="apple-touch-icon" href="icon-180.png">
<link rel="icon" type="image/png" href="icon-192.png">
<meta name="apple-mobile-web-app-capable" content="yes">
<meta name="mobile-web-app-capable" content="yes">
<meta name="apple-mobile-web-app-status-bar-style" content="black-translucent">
<meta name="apple-mobile-web-app-title" content="Pocket Links">
<meta name="theme-color" content="#0a2a1d">
<style>html{box-sizing:border-box;padding:env(safe-area-inset-top,0px) 0 env(safe-area-inset-bottom,0px)}*,*::before,*::after{box-sizing:inherit}body{margin:0}[hidden]{display:none!important}</style>
</head>
<body>
'@
$tail = @'
<script>if('serviceWorker' in navigator){addEventListener('load',()=>navigator.serviceWorker.register('sw.js').catch(()=>{}))}</script>
</body>
</html>
'@
$game = Get-Content -Raw -Encoding utf8 (Join-Path $root 'game.html')
$utf8 = New-Object System.Text.UTF8Encoding $false
[IO.File]::WriteAllText((Join-Path $out 'index.html'), $head + $game + $tail, $utf8)

$manifest = @'
{
  "name": "Pocket Links",
  "short_name": "Pocket Links",
  "description": "Nine holes of mini golf.",
  "start_url": "./",
  "scope": "./",
  "display": "standalone",
  "orientation": "portrait",
  "background_color": "#0a2a1d",
  "theme_color": "#0a2a1d",
  "icons": [
    { "src": "icon-192.png", "sizes": "192x192", "type": "image/png" },
    { "src": "icon-512.png", "sizes": "512x512", "type": "image/png", "purpose": "any maskable" }
  ]
}
'@
[IO.File]::WriteAllText((Join-Path $out 'manifest.webmanifest'), $manifest, $utf8)

# Bump the cache name whenever the game changes so phones pick up the new version
$stamp = (Get-Date).ToString('yyyyMMddHHmmss')
$sw = @"
const CACHE = 'pocket-links-$stamp';
const CORE = ['./', './index.html', './manifest.webmanifest', './icon-180.png', './icon-192.png', './icon-512.png'];
self.addEventListener('install', e => { e.waitUntil(caches.open(CACHE).then(c => c.addAll(CORE)).then(() => self.skipWaiting())); });
self.addEventListener('activate', e => {
  e.waitUntil(caches.keys().then(keys => Promise.all(keys.filter(k => k !== CACHE).map(k => caches.delete(k)))).then(() => self.clients.claim()));
});
self.addEventListener('fetch', e => {
  if (e.request.method !== 'GET') return;
  e.respondWith(caches.match(e.request).then(hit => hit || fetch(e.request).then(res => {
    if (res.ok || res.type === 'opaque') { const copy = res.clone(); caches.open(CACHE).then(c => c.put(e.request, copy)); }
    return res;
  }).catch(() => caches.match('./index.html'))));
});
"@
[IO.File]::WriteAllText((Join-Path $out 'sw.js'), $sw, $utf8)

Add-Type -AssemblyName System.Drawing
function New-Icon([int]$size, [string]$path) {
  $bmp = New-Object System.Drawing.Bitmap $size, $size
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.SmoothingMode = 'AntiAlias'
  $u = $size / 100.0
  $C = { param($hex) [System.Drawing.ColorTranslator]::FromHtml($hex) }
  $P = { param($x, $y) New-Object System.Drawing.PointF ([single]($x*$u)), ([single]($y*$u)) }
  $full = New-Object System.Drawing.Rectangle 0, 0, $size, $size

  # fairway background with diagonal mowing stripes
  $bg = New-Object System.Drawing.Drawing2D.LinearGradientBrush $full, (& $C '#1e6b3a'), (& $C '#0a2a1d'), 90
  $g.FillRectangle($bg, $full)
  $stripe = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(22, 255, 255, 255))
  for ($k = -100; $k -lt 200; $k += 22) {
    $g.FillPolygon($stripe, [System.Drawing.PointF[]]@((& $P $k 0), (& $P ($k + 11) 0), (& $P ($k - 39) 100), (& $P ($k - 50) 100)))
  }

  # putting green with fringe and stripes
  $g.FillEllipse((New-Object System.Drawing.SolidBrush (& $C '#4f9a3f')), 6*$u, 52*$u, 88*$u, 42*$u)
  $greenPath = New-Object System.Drawing.Drawing2D.GraphicsPath
  $greenPath.AddEllipse(9*$u, 55*$u, 82*$u, 36*$u)
  $g.FillPath((New-Object System.Drawing.SolidBrush (& $C '#7cc35a')), $greenPath)
  $g.SetClip($greenPath)
  $gs = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(40, 255, 255, 255))
  for ($k = 0; $k -lt 120; $k += 12) { $g.FillPolygon($gs, [System.Drawing.PointF[]]@((& $P $k 50), (& $P ($k + 6) 50), (& $P ($k - 14) 95), (& $P ($k - 20) 95))) }
  $g.ResetClip()

  # cup and flagstick
  $g.FillEllipse((New-Object System.Drawing.SolidBrush (& $C '#0b140e')), 60*$u, 69*$u, 12*$u, 5.5*$u)
  $shadowPen = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(60, 0, 0, 0)), (2.4*$u)
  $g.DrawLine($shadowPen, 66*$u, 72*$u, 86*$u, 80*$u)
  $pole = New-Object System.Drawing.Pen (& $C '#f7f7f2'), (2.6*$u)
  $pole.StartCap = 'Round'; $pole.EndCap = 'Round'
  $g.DrawLine($pole, 66*$u, 72*$u, 66*$u, 12*$u)
  $flag = New-Object System.Drawing.Drawing2D.GraphicsPath
  $flag.AddBezier((& $P 67 12), (& $P 74 9), (& $P 80 17), (& $P 90 15))
  $flag.AddBezier((& $P 90 15), (& $P 84 21), (& $P 78 24), (& $P 86 30))
  $flag.AddBezier((& $P 86 30), (& $P 78 33), (& $P 73 26), (& $P 67 30))
  $flag.CloseFigure()
  $g.FillPath((New-Object System.Drawing.SolidBrush (& $C '#ffd23f')), $flag)

  # dimpled golf ball with shading
  $bx = 34; $by = 64; $br = 16
  $g.FillEllipse((New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(80, 0, 0, 0))), ($bx - $br + 3)*$u, ($by + $br - 5)*$u, ($br * 2)*$u, 9*$u)
  $ball = New-Object System.Drawing.Drawing2D.GraphicsPath
  $ball.AddEllipse(($bx - $br)*$u, ($by - $br)*$u, ($br * 2)*$u, ($br * 2)*$u)
  $shade = New-Object System.Drawing.Drawing2D.PathGradientBrush $ball
  $shade.CenterPoint = & $P ($bx - 5) ($by - 6)
  $shade.CenterColor = [System.Drawing.Color]::White
  $shade.SurroundColors = [System.Drawing.Color[]]@((& $C '#c9cfc9'))
  $g.FillPath($shade, $ball)
  $g.SetClip($ball)
  $dimple = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(24, 20, 40, 30))
  $row = 0
  for ($y = $by - $br; $y -le $by + $br; $y += 4.4) {
    $off = if ($row % 2) { 2.5 } else { 0 }
    for ($x = $bx - $br - 3 + $off; $x -le $bx + $br; $x += 5) { $g.FillEllipse($dimple, ($x - 1.3)*$u, ($y - 1.3)*$u, 2.6*$u, 2.6*$u) }
    $row++
  }
  $g.ResetClip()
  $g.FillEllipse((New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(150, 255, 255, 255))), ($bx - 9)*$u, ($by - 10)*$u, 7*$u, 5*$u)
  $g.Dispose()
  $bmp.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
  $bmp.Dispose()
}
New-Icon 180 (Join-Path $out 'icon-180.png')
New-Icon 192 (Join-Path $out 'icon-192.png')
New-Icon 512 (Join-Path $out 'icon-512.png')
Write-Output "Built $out"
