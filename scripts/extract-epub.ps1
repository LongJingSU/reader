[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$EpubPath,

    [Parameter(Mandatory = $true)]
    [string]$OutputDir,

    [string]$BookId,
    [string]$Title,
    [string]$Subtitle = '',
    [string]$Creator,
    [string]$Translator = '',
    [string]$Publisher,
    [string]$Language,
    [string[]]$AllowedRemoteImageHosts = @()
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem

function Get-HashText {
    param([Parameter(Mandatory = $true)][string]$Value)
    $algorithm = [System.Security.Cryptography.SHA256]::Create()
    try {
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($Value)
        return ([System.BitConverter]::ToString($algorithm.ComputeHash($bytes))).Replace('-', '').ToLowerInvariant()
    }
    finally {
        $algorithm.Dispose()
    }
}

function Resolve-ZipPath {
    param(
        [Parameter(Mandatory = $true)][string]$BaseFile,
        [Parameter(Mandatory = $true)][string]$Href
    )
    $nativeBaseFile = $BaseFile.Replace('/', [System.IO.Path]::DirectorySeparatorChar)
    $baseDirectory = ([System.IO.Path]::GetDirectoryName($nativeBaseFile)).Replace([System.IO.Path]::DirectorySeparatorChar, '/')
    if ($baseDirectory) { $baseDirectory += '/' }
    $baseUri = [Uri]('https://epub.local/' + $baseDirectory)
    $resolved = [Uri]::new($baseUri, $Href)
    return [Uri]::UnescapeDataString($resolved.AbsolutePath.TrimStart('/'))
}

function Get-EntryText {
    param(
        [Parameter(Mandatory = $true)]$Entry,
        [System.Text.Encoding]$Encoding = [System.Text.Encoding]::UTF8
    )
    $stream = $Entry.Open()
    try {
        $reader = [System.IO.StreamReader]::new($stream, $Encoding, $true)
        try { return $reader.ReadToEnd() }
        finally { $reader.Dispose() }
    }
    finally { $stream.Dispose() }
}

function Get-PlainText {
    param([string]$Html)
    $withoutTags = [regex]::Replace($Html, '<[^>]+>', ' ')
    $decoded = [System.Net.WebUtility]::HtmlDecode($withoutTags)
    return [regex]::Replace($decoded, '\s+', ' ').Trim()
}

function Remove-UnsafeHtml {
    param([string]$Html)
    $value = [regex]::Replace($Html, '(?is)<(script|style|iframe|object|embed|form)\b[^>]*>.*?</\1\s*>', '')
    $value = [regex]::Replace($value, '(?is)<(script|style|iframe|object|embed|form)\b[^>]*/?>', '')
    $value = [regex]::Replace($value, '(?is)\s+on[a-z]+\s*=\s*("[^"]*"|''[^'']*''|[^\s>]+)', '')
    $value = [regex]::Replace($value, '(?is)\s+style\s*=\s*("[^"]*"|''[^'']*''|[^\s>]+)', '')
    $value = [regex]::Replace($value, '(?is)(href|src)\s*=\s*(["''])\s*javascript:[^"'']*\2', '$1="#"')
    return $value
}

$resolvedEpub = (Resolve-Path -LiteralPath $EpubPath).Path
$resolvedOutput = [System.IO.Path]::GetFullPath($OutputDir)
[System.IO.Directory]::CreateDirectory($resolvedOutput) | Out-Null
$imageOutput = Join-Path $resolvedOutput 'images'
[System.IO.Directory]::CreateDirectory($imageOutput) | Out-Null

$archive = [System.IO.Compression.ZipFile]::OpenRead($resolvedEpub)
try {
    $entryMap = @{}
    foreach ($entry in $archive.Entries) {
        $entryMap[$entry.FullName.Replace('\', '/').ToLowerInvariant()] = $entry
    }

    $containerEntry = $entryMap['meta-inf/container.xml']
    if (-not $containerEntry) { throw 'Invalid EPUB: META-INF/container.xml was not found.' }
    [xml]$containerXml = Get-EntryText -Entry $containerEntry
    $rootFile = $containerXml.SelectSingleNode("//*[local-name()='rootfile']")
    if (-not $rootFile) { throw 'Invalid EPUB: package rootfile was not declared.' }
    $opfPath = ([string]$rootFile.GetAttribute('full-path')).Replace('\', '/')
    $opfEntry = $entryMap[$opfPath.ToLowerInvariant()]
    if (-not $opfEntry) { throw "Invalid EPUB: package file '$opfPath' was not found." }

    [xml]$opfXml = Get-EntryText -Entry $opfEntry
    $metadataNode = $opfXml.SelectSingleNode("//*[local-name()='metadata']")
    $manifestNodes = $opfXml.SelectNodes("//*[local-name()='manifest']/*[local-name()='item']")
    $spineNodes = $opfXml.SelectNodes("//*[local-name()='spine']/*[local-name()='itemref']")

    $manifest = @{}
    foreach ($item in $manifestNodes) {
        $manifest[[string]$item.GetAttribute('id')] = [pscustomobject]@{
            Id = [string]$item.GetAttribute('id')
            Href = [string]$item.GetAttribute('href')
            MediaType = [string]$item.GetAttribute('media-type')
            Properties = [string]$item.GetAttribute('properties')
        }
    }

    function Read-MetadataValue([string]$LocalName) {
        $node = $metadataNode.SelectSingleNode("./*[local-name()='$LocalName']")
        if ($node) { return ([string]$node.InnerText).Trim() }
        return ''
    }

    if (-not $Title) { $Title = Read-MetadataValue 'title' }
    if (-not $Creator) { $Creator = Read-MetadataValue 'creator' }
    if (-not $Publisher) { $Publisher = Read-MetadataValue 'publisher' }
    if (-not $Language) { $Language = Read-MetadataValue 'language' }
    if (-not $Title) { $Title = [System.IO.Path]::GetFileNameWithoutExtension($resolvedEpub) }
    if (-not $BookId) { $BookId = 'book-' + (Get-HashText -Value ($Title + '|' + $Creator)).Substring(0, 12) }

    $assetCache = @{}
    $blockedRemoteImages = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)

    function Save-ArchiveAsset {
        param([Parameter(Mandatory = $true)][string]$ZipPath)
        $normalized = $ZipPath.Replace('\', '/')
        if ($assetCache.ContainsKey($normalized)) { return $assetCache[$normalized] }
        $sourceEntry = $entryMap[$normalized.ToLowerInvariant()]
        if (-not $sourceEntry) { return $null }
        $extension = [System.IO.Path]::GetExtension($normalized)
        if (-not $extension -or $extension.Length -gt 8) { $extension = '.bin' }
        $fileName = (Get-HashText -Value $normalized).Substring(0, 20) + $extension.ToLowerInvariant()
        $destination = Join-Path $imageOutput $fileName
        $input = $sourceEntry.Open()
        try {
            $output = [System.IO.File]::Create($destination)
            try { $input.CopyTo($output) }
            finally { $output.Dispose() }
        }
        finally { $input.Dispose() }
        $publicPath = '/book/images/' + $fileName
        $assetCache[$normalized] = $publicPath
        return $publicPath
    }

    function Save-RemoteAsset {
        param([Parameter(Mandatory = $true)][Uri]$Uri)
        if ($AllowedRemoteImageHosts -notcontains $Uri.Host) {
            [void]$blockedRemoteImages.Add($Uri.AbsoluteUri)
            return $Uri.AbsoluteUri
        }
        if ($assetCache.ContainsKey($Uri.AbsoluteUri)) { return $assetCache[$Uri.AbsoluteUri] }
        $extension = [System.IO.Path]::GetExtension($Uri.AbsolutePath)
        if (-not $extension -or $extension.Length -gt 8) { $extension = '.img' }
        $fileName = (Get-HashText -Value $Uri.AbsoluteUri).Substring(0, 20) + $extension.ToLowerInvariant()
        $destination = Join-Path $imageOutput $fileName
        Invoke-WebRequest -Uri $Uri.AbsoluteUri -OutFile $destination -UseBasicParsing
        $publicPath = '/book/images/' + $fileName
        $assetCache[$Uri.AbsoluteUri] = $publicPath
        return $publicPath
    }

    $chapters = [System.Collections.Generic.List[object]]::new()
    $chapterOrder = 0
    foreach ($spineItem in $spineNodes) {
        $idref = [string]$spineItem.GetAttribute('idref')
        if (-not $manifest.ContainsKey($idref)) { continue }
        $manifestItem = $manifest[$idref]
        if ($manifestItem.MediaType -notmatch '(xhtml|html)') { continue }
        $chapterPath = Resolve-ZipPath -BaseFile $opfPath -Href $manifestItem.Href
        $chapterEntry = $entryMap[$chapterPath.ToLowerInvariant()]
        if (-not $chapterEntry) { continue }
        $rawChapter = Get-EntryText -Entry $chapterEntry
        try { [xml]$chapterXml = $rawChapter }
        catch { throw "Invalid chapter XML '$chapterPath': $($_.Exception.Message)" }
        $bodyNode = $chapterXml.SelectSingleNode("//*[local-name()='body']")
        if (-not $bodyNode) { continue }
        $chapterHtml = Remove-UnsafeHtml -Html ([string]$bodyNode.InnerXml)

        $currentChapterPath = $chapterPath
        $imageEvaluator = [System.Text.RegularExpressions.MatchEvaluator]{
            param($match)
            $prefix = $match.Groups[1].Value
            $quote = $match.Groups[2].Value
            $source = [System.Net.WebUtility]::HtmlDecode($match.Groups[3].Value.Trim())
            if ($source -match '^data:image/') { return $match.Value }
            if ($source -match '^https?://') {
                $replacement = Save-RemoteAsset -Uri ([Uri]$source)
            }
            elseif ($source.StartsWith('#')) {
                return $match.Value
            }
            else {
                $assetPath = Resolve-ZipPath -BaseFile $currentChapterPath -Href $source
                $replacement = Save-ArchiveAsset -ZipPath $assetPath
                if (-not $replacement) { throw "Chapter '$currentChapterPath' references missing image '$source'." }
            }
            return $prefix + $quote + $replacement + $quote
        }
        $chapterHtml = [regex]::Replace($chapterHtml, '(?is)(\bsrc\s*=\s*)(["''])(.*?)(\2)', $imageEvaluator)

        $titleNode = $chapterXml.SelectSingleNode("//*[local-name()='title']")
        $chapterTitle = if ($titleNode) { ([string]$titleNode.InnerText).Trim() } else { '' }
        if (-not $chapterTitle) {
            $headingNode = $bodyNode.SelectSingleNode(".//*[local-name()='h1' or local-name()='h2']")
            if ($headingNode) { $chapterTitle = ([string]$headingNode.InnerText).Trim() }
        }
        if (-not $chapterTitle) { $chapterTitle = "第 $($chapterOrder + 1) 节" }
        $chapterId = 'chapter-' + (Get-HashText -Value $chapterPath).Substring(0, 16)
        $plainText = Get-PlainText -Html $chapterHtml
        if (-not $plainText) { continue }

        $chapters.Add([ordered]@{
            id = $chapterId
            order = $chapterOrder
            section = '正文'
            title = $chapterTitle
            source = $chapterPath
            html = $chapterHtml
            plainText = $plainText
        })
        $chapterOrder++
    }

    if ($blockedRemoteImages.Count -gt 0) {
        $list = ($blockedRemoteImages | Sort-Object) -join "`n  - "
        throw "EPUB contains remote images that were not localized. Inspect them, then pass only trusted hosts via -AllowedRemoteImageHosts:`n  - $list"
    }
    if ($chapters.Count -eq 0) { throw 'No readable spine chapters were extracted.' }

    $coverPath = ''
    $coverItem = $manifest.Values | Where-Object { $_.Properties -match '(^|\s)cover-image(\s|$)' } | Select-Object -First 1
    if (-not $coverItem) {
        $coverMeta = $metadataNode.SelectSingleNode("./*[local-name()='meta' and translate(@name,'ABCDEFGHIJKLMNOPQRSTUVWXYZ','abcdefghijklmnopqrstuvwxyz')='cover']")
        if ($coverMeta) { $coverItem = $manifest[[string]$coverMeta.GetAttribute('content')] }
    }
    if (-not $coverItem) {
        $coverItem = $manifest.Values | Where-Object { $_.MediaType -match '^image/' -and $_.Href -match 'cover' } | Select-Object -First 1
    }
    if ($coverItem) {
        $coverZipPath = Resolve-ZipPath -BaseFile $opfPath -Href $coverItem.Href
        $localizedCover = Save-ArchiveAsset -ZipPath $coverZipPath
        if ($localizedCover) {
            $extension = [System.IO.Path]::GetExtension($localizedCover)
            $coverName = 'cover' + $extension
            Copy-Item -LiteralPath (Join-Path $resolvedOutput $localizedCover.TrimStart('/').Substring('book/'.Length).Replace('/', '\')) -Destination (Join-Path $resolvedOutput $coverName) -Force
            $coverPath = '/book/' + $coverName
        }
    }

    $bookData = [ordered]@{
        id = $BookId
        title = $Title
        subtitle = $Subtitle
        creator = $Creator
        translator = $Translator
        publisher = $Publisher
        language = $Language
        cover = $coverPath
        chapterCount = $chapters.Count
        chapters = $chapters
    }
    $jsonPath = Join-Path $resolvedOutput 'book-data.json'
    $bookData | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $jsonPath -Encoding utf8

    [pscustomobject]@{
        BookId = $BookId
        Title = $Title
        Language = $Language
        Chapters = $chapters.Count
        LocalizedAssets = $assetCache.Count
        Output = $jsonPath
    }
}
finally {
    $archive.Dispose()
}
