param(
  [string]$Ffmpeg = "ffmpeg"
)

$ErrorActionPreference = "Stop"

$brandDirectory = $PSScriptRoot
$repositoryRoot = [System.IO.Path]::GetFullPath(
  (Join-Path $brandDirectory "..\..")
)
$source = Join-Path $brandDirectory "ordin-app-icon-v1.png"
$warmWhite = "FCF8EE"
$removeWarmWhite = "format=rgba,colorkey=0x${warmWhite}:0.10:0.04"

if (-not (Test-Path -LiteralPath $source)) {
  throw "Brand master not found: $source"
}

function Ensure-Directory {
  param([string]$Path)

  [System.IO.Directory]::CreateDirectory($Path) | Out-Null
}

function Invoke-BrandFfmpeg {
  param(
    [string]$Filter,
    [string]$Output
  )

  Ensure-Directory ([System.IO.Path]::GetDirectoryName($Output))
  & $Ffmpeg -hide_banner -loglevel error -y -i $source `
    -vf $Filter -frames:v 1 $Output
  if ($LASTEXITCODE -ne 0) {
    throw "ffmpeg failed while generating $Output"
  }
}

function New-OpaqueIcon {
  param(
    [int]$Size,
    [string]$Output,
    [string]$PixelFormat = "rgb24"
  )

  Invoke-BrandFfmpeg `
    "scale=${Size}:${Size}:flags=lanczos,setsar=1,format=$PixelFormat" `
    $Output
}

function New-TransparentMark {
  param(
    [int]$Size,
    [string]$Output
  )

  Invoke-BrandFfmpeg `
    "$removeWarmWhite,scale=${Size}:${Size}:flags=lanczos,setsar=1,format=rgba" `
    $Output
}

function New-AdaptiveLayer {
  param(
    [int]$CanvasSize,
    [int]$MarkSize,
    [string]$Output,
    [switch]$Monochrome
  )

  $filter = "$removeWarmWhite,scale=${MarkSize}:${MarkSize}:flags=lanczos," +
    "pad=${CanvasSize}:${CanvasSize}:(ow-iw)/2:(oh-ih)/2:color=black@0," +
    "setsar=1,format=rgba"
  if ($Monochrome) {
    $filter += ",lutrgb=r=255:g=255:b=255"
  }
  Invoke-BrandFfmpeg $filter $Output
}

$androidResourceRoot = Join-Path `
  $repositoryRoot "apps\client\android\app\src\main\res"
$androidDensities = [ordered]@{
  "mdpi" = @{ Legacy = 48; Foreground = 108; SafeMark = 92; Splash = 96 }
  "hdpi" = @{ Legacy = 72; Foreground = 162; SafeMark = 138; Splash = 144 }
  "xhdpi" = @{ Legacy = 96; Foreground = 216; SafeMark = 184; Splash = 192 }
  "xxhdpi" = @{ Legacy = 144; Foreground = 324; SafeMark = 276; Splash = 288 }
  "xxxhdpi" = @{ Legacy = 192; Foreground = 432; SafeMark = 368; Splash = 384 }
}

foreach ($density in $androidDensities.GetEnumerator()) {
  $mipmapDirectory = Join-Path $androidResourceRoot "mipmap-$($density.Key)"
  $drawableDirectory = Join-Path $androidResourceRoot "drawable-$($density.Key)"
  New-OpaqueIcon $density.Value.Legacy `
    (Join-Path $mipmapDirectory "ordin_launcher.png")
  New-AdaptiveLayer $density.Value.Foreground $density.Value.SafeMark `
    (Join-Path $mipmapDirectory "ordin_launcher_foreground.png")
  New-AdaptiveLayer $density.Value.Foreground $density.Value.SafeMark `
    (Join-Path $mipmapDirectory "ordin_launcher_monochrome.png") -Monochrome
  New-TransparentMark $density.Value.Splash `
    (Join-Path $drawableDirectory "ordin_splash_mark.png")
}

$iosAppIconDirectory = Join-Path `
  $repositoryRoot "apps\client\ios\Runner\Assets.xcassets\AppIcon.appiconset"
$iosIconSizes = 20, 29, 40, 58, 60, 76, 80, 87, 120, 152, 167, 180, 1024
foreach ($size in $iosIconSizes) {
  New-OpaqueIcon $size `
    (Join-Path $iosAppIconDirectory "ordin-app-icon-${size}.png")
}

$iosLaunchDirectory = Join-Path `
  $repositoryRoot "apps\client\ios\Runner\Assets.xcassets\LaunchImage.imageset"
New-TransparentMark 112 (Join-Path $iosLaunchDirectory "ordin-launch-mark.png")
New-TransparentMark 224 (Join-Path $iosLaunchDirectory "ordin-launch-mark@2x.png")
New-TransparentMark 336 (Join-Path $iosLaunchDirectory "ordin-launch-mark@3x.png")

$macAppIconDirectory = Join-Path `
  $repositoryRoot "apps\client\macos\Runner\Assets.xcassets\AppIcon.appiconset"
$macIconSizes = 16, 32, 64, 128, 256, 512, 1024
foreach ($size in $macIconSizes) {
  New-OpaqueIcon $size `
    (Join-Path $macAppIconDirectory "ordin-app-icon-${size}.png")
}

$macLaunchDirectory = Join-Path `
  $repositoryRoot "apps\client\macos\Runner\Assets.xcassets\OrdinLaunchMark.imageset"
New-TransparentMark 112 (Join-Path $macLaunchDirectory "ordin-launch-mark.png")
New-TransparentMark 224 (Join-Path $macLaunchDirectory "ordin-launch-mark@2x.png")
New-TransparentMark 336 (Join-Path $macLaunchDirectory "ordin-launch-mark@3x.png")

$windowsResourceDirectory = Join-Path `
  $repositoryRoot "apps\client\windows\runner\resources"
$icoPartsDirectory = Join-Path $brandDirectory ".ico-parts"
Ensure-Directory $icoPartsDirectory
$icoSizes = 16, 24, 32, 48, 64, 128, 256
$icoImages = @()
try {
  foreach ($size in $icoSizes) {
    $part = Join-Path $icoPartsDirectory "ordin-app-icon-${size}.png"
    New-OpaqueIcon $size $part "rgba"
    $icoImages += [PSCustomObject]@{
      Size = $size
      Bytes = [System.IO.File]::ReadAllBytes($part)
    }
  }

  $icoPath = Join-Path $windowsResourceDirectory "ordin_app_icon.ico"
  Ensure-Directory $windowsResourceDirectory
  $stream = [System.IO.File]::Open(
    $icoPath,
    [System.IO.FileMode]::Create,
    [System.IO.FileAccess]::Write,
    [System.IO.FileShare]::None
  )
  $writer = [System.IO.BinaryWriter]::new($stream)
  try {
    $writer.Write([UInt16]0)
    $writer.Write([UInt16]1)
    $writer.Write([UInt16]$icoImages.Count)
    $offset = 6 + (16 * $icoImages.Count)
    foreach ($image in $icoImages) {
      $dimension = if ($image.Size -eq 256) { 0 } else { $image.Size }
      $writer.Write([Byte]$dimension)
      $writer.Write([Byte]$dimension)
      $writer.Write([Byte]0)
      $writer.Write([Byte]0)
      $writer.Write([UInt16]1)
      $writer.Write([UInt16]32)
      $writer.Write([UInt32]$image.Bytes.Length)
      $writer.Write([UInt32]$offset)
      $offset += $image.Bytes.Length
    }
    foreach ($image in $icoImages) {
      $writer.Write([Byte[]]$image.Bytes)
    }
  } finally {
    $writer.Dispose()
  }
} finally {
  foreach ($part in Get-ChildItem -LiteralPath $icoPartsDirectory -File) {
    Remove-Item -LiteralPath $part.FullName
  }
  Remove-Item -LiteralPath $icoPartsDirectory
}
