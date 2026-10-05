param(
    [string]$Version = ''
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$projectRoot = [System.IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$pubspecPath = Join-Path $projectRoot 'pubspec.yaml'
$licensePath = Join-Path $projectRoot 'LICENSE'
$gradlePath = Join-Path $projectRoot 'android\app\build.gradle.kts'
$constantsPath = Join-Path $projectRoot 'lib\utils\constants.dart'

if (-not (Test-Path -LiteralPath $pubspecPath -PathType Leaf) -or
    -not (Test-Path -LiteralPath $licensePath -PathType Leaf)) {
    throw 'Run this script from the Meditation Timer source project.'
}

$pubspec = Get-Content -LiteralPath $pubspecPath -Raw
$versionMatch = [regex]::Match(
    $pubspec,
    '(?m)^version:\s*([0-9]+\.[0-9]+\.[0-9]+)\+[0-9]+\s*$'
)
if (-not $versionMatch.Success) {
    throw 'Could not read the semantic version from pubspec.yaml.'
}

$pubspecVersion = $versionMatch.Groups[1].Value
if ([string]::IsNullOrWhiteSpace($Version)) {
    $Version = $pubspecVersion
}
if ($Version -ne $pubspecVersion) {
    throw "Requested version $Version does not match pubspec version $pubspecVersion."
}

$constants = Get-Content -LiteralPath $constantsPath -Raw
$escapedVersion = [regex]::Escape($Version)
if ($constants -notmatch "appVersion\s*=\s*'$escapedVersion'") {
    throw "lib/utils/constants.dart does not report version $Version."
}

$gradle = Get-Content -LiteralPath $gradlePath -Raw
$expectedPackage = 'org.tipitakapali.ekatimer'
$escapedPackage = [regex]::Escape($expectedPackage)
if ($gradle -notmatch "applicationId\s*=\s*`"$escapedPackage`"" -or
    $gradle -notmatch "namespace\s*=\s*`"$escapedPackage`"") {
    throw "Android applicationId/namespace must remain $expectedPackage."
}

$releaseName = "Meditation Timer-v$Version-GPL-source"
$distRoot = Join-Path $projectRoot 'dist'
$stagingContainer = Join-Path $distRoot '.source-release-staging'
$stagingRoot = Join-Path $stagingContainer $releaseName
$zipPath = Join-Path $distRoot "$releaseName.zip"
$checksumPath = "$zipPath.sha256.txt"

New-Item -ItemType Directory -Path $distRoot -Force | Out-Null

function Assert-SafeReleasePath {
    param([Parameter(Mandatory = $true)][string]$Path)

    $resolved = [System.IO.Path]::GetFullPath($Path)
    $allowed = [System.IO.Path]::GetFullPath($distRoot) +
        [System.IO.Path]::DirectorySeparatorChar
    if (-not $resolved.StartsWith(
        $allowed,
        [System.StringComparison]::OrdinalIgnoreCase
    )) {
        throw "Unsafe release path: $resolved"
    }
}

function Get-ProjectRelativePath {
    param(
        [Parameter(Mandatory = $true)][string]$BasePath,
        [Parameter(Mandatory = $true)][string]$FullPath
    )

    $normalizedBase = [System.IO.Path]::GetFullPath($BasePath).TrimEnd('\', '/')
    $normalizedFile = [System.IO.Path]::GetFullPath($FullPath)
    $prefix = $normalizedBase + [System.IO.Path]::DirectorySeparatorChar
    if (-not $normalizedFile.StartsWith(
        $prefix,
        [System.StringComparison]::OrdinalIgnoreCase
    )) {
        throw "Path is outside the expected root: $normalizedFile"
    }
    return $normalizedFile.Substring($prefix.Length)
}

Assert-SafeReleasePath -Path $stagingContainer
Assert-SafeReleasePath -Path $zipPath
Assert-SafeReleasePath -Path $checksumPath

if (Test-Path -LiteralPath $stagingContainer) {
    Remove-Item -LiteralPath $stagingContainer -Recurse -Force
}
if (Test-Path -LiteralPath $zipPath) {
    Remove-Item -LiteralPath $zipPath -Force
}
if (Test-Path -LiteralPath $checksumPath) {
    Remove-Item -LiteralPath $checksumPath -Force
}
New-Item -ItemType Directory -Path $stagingRoot -Force | Out-Null

$topLevelFiles = @(
    '.gitattributes',
    '.gitignore',
    '.metadata',
    'analysis_options.yaml',
    'CHANGELOG.md',
    'devtools_options.yaml',
    'LICENSE',
    'NOTICE',
    'pubspec.lock',
    'pubspec.yaml',
    'README.md',
    'SOURCE_RELEASE.md',
    'THIRD_PARTY_NOTICES.md'
)

$sourceRoots = @(
    'android',
    'assets',
    'ios',
    'lib',
    'linux',
    'macos',
    'test',
    'tools',
    'web',
    'windows'
)

# The generator source is outside the normal source roots, so include it
# explicitly; otherwise a release archive cannot reproduce the launcher icons.
$explicitFiles = @('images\ekaTimer_BrownbgZoomLotus.png')

$excludePatterns = @(
    '(^|/)(\.git|\.dart_tool|\.pub-cache|build|dist|coverage|\.gradle|\.kotlin|Pods|DerivedData|ephemeral|xcuserdata)(/|$)',
    '(^|/)(local|key)\.properties$',
    '(^|/)google-services\.json$',
    '(^|/)\.flutter-plugins(-dependencies)?$',
    '(^|/)GeneratedPluginRegistrant\.(java|h|m|swift)$',
    '(^|/)generated_plugin_registrant\.(cc|h)$',
    '(^|/)generated_plugins\.cmake$',
    '(^|/)flutter_(export_environment|native_integration)\.(sh|env)$',
    '^assets/images/quality/',
    '^lib/widgets/sitting_quality_icon\.dart$',
    '\.(apk|aab|ipa|jks|keystore|p12|pfx|pem|key|dSYM|bak)$'
)

function Test-ExcludedPath {
    param([Parameter(Mandatory = $true)][string]$RelativePath)

    $normalized = $RelativePath.Replace('\', '/')
    foreach ($pattern in $excludePatterns) {
        if ($normalized -match $pattern) {
            return $true
        }
    }
    return $false
}

$releaseFiles = [System.Collections.Generic.List[string]]::new()
foreach ($relativePath in $topLevelFiles + $explicitFiles) {
    $sourcePath = Join-Path $projectRoot $relativePath
    if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) {
        throw "Required release file is missing: $relativePath"
    }
    $releaseFiles.Add($relativePath)
}

foreach ($sourceRoot in $sourceRoots) {
    $absoluteRoot = Join-Path $projectRoot $sourceRoot
    if (-not (Test-Path -LiteralPath $absoluteRoot -PathType Container)) {
        throw "Required source directory is missing: $sourceRoot"
    }
    foreach ($file in Get-ChildItem -LiteralPath $absoluteRoot -Recurse -File -Force) {
        $relativePath = Get-ProjectRelativePath `
            -BasePath $projectRoot `
            -FullPath $file.FullName
        if (-not (Test-ExcludedPath -RelativePath $relativePath)) {
            $releaseFiles.Add($relativePath)
        }
    }
}

$releaseFiles = $releaseFiles | Sort-Object -Unique
foreach ($relativePath in $releaseFiles) {
    $sourcePath = Join-Path $projectRoot $relativePath
    $targetPath = Join-Path $stagingRoot $relativePath
    $targetDirectory = Split-Path -Parent $targetPath
    New-Item -ItemType Directory -Path $targetDirectory -Force | Out-Null
    Copy-Item -LiteralPath $sourcePath -Destination $targetPath -Force
}

$forbiddenFiles = Get-ChildItem -LiteralPath $stagingRoot -Recurse -File -Force |
    Where-Object {
        $_.Name -in @(
            'local.properties',
            'key.properties',
            'google-services.json',
            'GoogleService-Info.plist'
        ) -or
        $_.Extension -in @(
            '.apk', '.aab', '.jks', '.keystore', '.p12', '.pfx', '.pem', '.key'
        )
    }
if ($forbiddenFiles) {
    throw "Forbidden file entered the package: $($forbiddenFiles.FullName -join ', ')"
}

$secretPattern = '(?i)-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----|AIza[0-9A-Za-z_-]{30,}|gh[pousr]_[0-9A-Za-z]{30,}|xox[baprs]-[0-9A-Za-z-]{20,}'
$textExtensions = @(
    '.dart', '.kt', '.kts', '.java', '.swift', '.m', '.h', '.cc', '.cpp',
    '.xml', '.json', '.yaml', '.yml', '.md', '.txt', '.properties',
    '.gradle', '.ps1', '.sh', '.bat'
)
foreach ($file in Get-ChildItem -LiteralPath $stagingRoot -Recurse -File -Force) {
    if ($file.Extension -in $textExtensions -or
        $file.Name -in @('.gitignore', '.gitattributes')) {
        $content = Get-Content `
            -LiteralPath $file.FullName `
            -Raw `
            -ErrorAction SilentlyContinue
        if ($null -ne $content -and $content -match $secretPattern) {
            throw "Potential credential detected in $($file.FullName)."
        }
    }
}

$manifestLines = foreach ($file in Get-ChildItem -LiteralPath $stagingRoot -Recurse -File -Force | Sort-Object FullName) {
    $relativePath = Get-ProjectRelativePath `
        -BasePath $stagingRoot `
        -FullPath $file.FullName
    $relativePath = $relativePath.Replace('\', '/')
    $hash = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
    "$hash  $relativePath"
}
$manifestPath = Join-Path $stagingRoot 'SOURCE_MANIFEST.sha256'
Set-Content -LiteralPath $manifestPath -Value $manifestLines -Encoding utf8

Add-Type -AssemblyName System.IO.Compression.FileSystem
[System.IO.Compression.ZipFile]::CreateFromDirectory(
    $stagingRoot,
    $zipPath,
    [System.IO.Compression.CompressionLevel]::Optimal,
    $true
)

$archive = [System.IO.Compression.ZipFile]::OpenRead($zipPath)
try {
    $entryNames = $archive.Entries |
        ForEach-Object { $_.FullName.Replace('\', '/') }
    if (-not ($entryNames | Where-Object { $_ -match '/LICENSE$' })) {
        throw 'LICENSE is missing from the generated archive.'
    }
    $forbiddenEntry = $entryNames | Where-Object {
        $_ -match '(^|/)(\.git|\.dart_tool|\.pub-cache|build|dist|\.gradle|local\.properties|key\.properties)(/|$)' -or
        $_ -match '\.(apk|aab|jks|keystore|p12|pfx|pem|key)$'
    } | Select-Object -First 1
    if ($forbiddenEntry) {
        throw "Forbidden archive entry detected: $forbiddenEntry"
    }
}
finally {
    $archive.Dispose()
}

$zipHash = (Get-FileHash -LiteralPath $zipPath -Algorithm SHA256).Hash.ToLowerInvariant()
Set-Content `
    -LiteralPath $checksumPath `
    -Value "$zipHash  $([System.IO.Path]::GetFileName($zipPath))" `
    -Encoding ascii

Remove-Item -LiteralPath $stagingContainer -Recurse -Force

Write-Output "Source archive: $zipPath"
Write-Output "SHA-256: $zipHash"
Write-Output "Checksum file: $checksumPath"
Write-Output "Included source files: $($releaseFiles.Count + 1)"
