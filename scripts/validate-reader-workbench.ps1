[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ProjectPath,
    [switch]$SkipBuild
)

$ErrorActionPreference = 'Stop'
$project = (Resolve-Path -LiteralPath $ProjectPath).Path
$requiredFiles = @(
    'public\book\book-data.json',
    'app\page.tsx',
    'app\globals.css',
    '.openai\hosting.json',
    'scripts\launch-reader.ps1'
)

foreach ($relativePath in $requiredFiles) {
    $candidate = Join-Path $project $relativePath
    if (-not (Test-Path -LiteralPath $candidate -PathType Leaf)) {
        throw "Required reader file is missing: $relativePath"
    }
}

$launchers = Get-ChildItem -LiteralPath $project -Filter '*.cmd' -File
if ($launchers.Count -eq 0) { throw 'A one-click .cmd launcher is required at the project root.' }

$bookJsonPath = Join-Path $project 'public\book\book-data.json'
$bookJsonRaw = Get-Content -LiteralPath $bookJsonPath -Raw
$book = $bookJsonRaw | ConvertFrom-Json
if (-not $book.id -or -not $book.title) { throw 'book-data.json must contain non-empty id and title.' }
if (-not $book.chapters -or @($book.chapters).Count -eq 0) { throw 'book-data.json contains no chapters.' }
$chapterIds = @($book.chapters | ForEach-Object { $_.id })
if (($chapterIds | Sort-Object -Unique).Count -ne $chapterIds.Count) { throw 'Chapter IDs must be unique.' }
foreach ($chapter in $book.chapters) {
    $chapterPropertyNames = @($chapter.PSObject.Properties.Name)
    if (-not $chapter.id -or -not $chapter.html -or $chapterPropertyNames -notcontains 'title' -or $chapterPropertyNames -notcontains 'plainText') {
        throw "Chapter '$($chapter.id)' is missing required content."
    }
}

$assetUrls = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
if ($book.cover -and ([string]$book.cover).StartsWith('/book/')) { [void]$assetUrls.Add([string]$book.cover) }
foreach ($chapter in $book.chapters) {
    $chapterHtml = [string]$chapter.html
    if ($chapterHtml -match '(?i)\bsrc\s*=\s*["'']https?://') {
        throw "Chapter '$($chapter.id)' still contains a remote image; localize it under public/book/."
    }
    foreach ($match in [regex]::Matches($chapterHtml, '(?i)\bsrc\s*=\s*["''](/book/[^"''?#]+)')) {
        [void]$assetUrls.Add($match.Groups[1].Value)
    }
}
foreach ($assetUrl in $assetUrls) {
    $assetRelative = $assetUrl.TrimStart('/').Replace('/', '\')
    if (-not (Test-Path -LiteralPath (Join-Path $project ('public\' + $assetRelative)) -PathType Leaf)) {
        throw "Referenced offline asset is missing: $assetUrl"
    }
}

$pagePath = Join-Path $project 'app\page.tsx'
$pageSource = Get-Content -LiteralPath $pagePath -Raw
$pageRequirements = [ordered]@{
    'device-local persistence (localStorage)' = 'localStorage'
    'persistent highlight class' = 'reader-highlight'
    'highlight cancellation action' = '取消高亮'
    'margin-note connector' = 'margin-note-guide'
    'JSON state backup' = 'JSON'
    'Markdown note export' = 'Markdown'
}
foreach ($requirement in $pageRequirements.GetEnumerator()) {
    if ($pageSource -notmatch [regex]::Escape([string]$requirement.Value)) {
        throw "Reader implementation is missing $($requirement.Key)."
    }
}

$cssSource = Get-Content -LiteralPath (Join-Path $project 'app\globals.css') -Raw
if ($cssSource -notmatch '(?is)margin-note.*border.*dashed|border[^;]*dashed') {
    throw 'The page margin must include a dashed note-area treatment.'
}

$hosting = Get-Content -LiteralPath (Join-Path $project '.openai\hosting.json') -Raw | ConvertFrom-Json
if ($null -ne $hosting.d1 -or $null -ne $hosting.r2) {
    throw '.openai/hosting.json must keep d1 and r2 bindings null for this local reader.'
}

$launcherScript = Join-Path $project 'scripts\launch-reader.ps1'
$parseErrors = $null
[void][System.Management.Automation.Language.Parser]::ParseFile($launcherScript, [ref]$null, [ref]$parseErrors)
if ($parseErrors.Count -gt 0) {
    throw "Launcher PowerShell has syntax errors: $($parseErrors[0].Message)"
}

if (-not $SkipBuild) {
    $packagePath = Join-Path $project 'package.json'
    if (-not (Test-Path -LiteralPath $packagePath -PathType Leaf)) { throw 'package.json is required for production build validation.' }
    Push-Location $project
    try {
        & npm.cmd run build
        if ($LASTEXITCODE -ne 0) { throw "Production build failed with exit code $LASTEXITCODE." }
    }
    finally { Pop-Location }
}

[pscustomobject]@{
    Project = $project
    Book = $book.title
    Chapters = @($book.chapters).Count
    OfflineAssets = $assetUrls.Count
    BuildChecked = -not $SkipBuild
    Status = 'PASS'
}
