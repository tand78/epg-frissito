$urls = @(
    $env:DROPBOX_EPG_URL,
    "http://www.open-epg.com/files/hungary1.xml.gz"
)

$output = "friss_epg.xml"
$outputGz = "friss_epg.xml.gz"
$temp = "temp_epg.dat"
$xmlTemp = "temp_part.xml"

$allChannels = ""
$allProgrammes = ""

foreach ($url in $urls) {
    if ([string]::IsNullOrWhiteSpace($url)) { continue }

    try {
        Invoke-WebRequest -Uri $url -OutFile $temp -UserAgent "Mozilla/5.0" -TimeoutSec 30 -ErrorAction Stop
    } catch {
        Write-Warning "Nem sikerult letolteni: $url"
        continue
    }

    $bytes = [System.IO.File]::ReadAllBytes($temp)
    if ($bytes.Length -ge 2 -and $bytes.GetValue(0) -eq 0x1F -and $bytes.GetValue(1) -eq 0x8B) {
        $in = New-Object System.IO.FileStream $temp, ([IO.FileMode]::Open)
        $out = New-Object System.IO.FileStream $xmlTemp, ([IO.FileMode]::Create)
        $gz = New-Object System.IO.Compression.GzipStream $in, ([IO.Compression.CompressionMode]::Decompress)
        $gz.CopyTo($out)
        $gz.Close(); $out.Close(); $in.Close()
        Remove-Item $temp -Force
    } else {
        Move-Item $temp $xmlTemp -Force
    }

    $partContent = Get-Content -Path $xmlTemp -Raw -Encoding UTF8

    $channelsMatch = [regex]::Matches($partContent, '(?s)<channel\b.*?</channel>')
    foreach ($m in $channelsMatch) { $allChannels += "`r`n" + $m.Value }

    $progMatch = [regex]::Matches($partContent, '(?s)<programme\b.*?</programme>')
    foreach ($m in $progMatch) { $allProgrammes += "`r`n" + $m.Value }

    Remove-Item $xmlTemp -Force
}

$content = "<?xml version=`"1.0`" encoding=`"UTF-8`"?>`r`n<tv>$allChannels$allProgrammes`r`n</tv>"

# 1. Általános tisztítás, nagybetűsítés és (HD) / .hu törlése
$pattern = '(?i)(?<prefix>id="|channel="|<display-name[^>]*>)(?:HU:\s*)?(?<name>[^"<]+?)(?:\s*(?:\(HD\)|\.hu))*\s*(?<suffix>"|</display-name>)'
$newContent = [regex]::Replace($content, $pattern, { param($m) return $m.Groups['prefix'].Value + "HU: " + $m.Groups['name'].Value.Trim().ToUpper() + $m.Groups['suffix'].Value })

# 2. Minden egyedi csatornanév-csere (egységes alapazonosítóra hozás)
$newContent = [regex]::Replace($newContent, '(?i)(?<prefix>id="|channel="|<display-name[^>]*>)HU:\s*M2\b[^"<]*PET[^"<]*(?<suffix>"|</display-name>)', '${prefix}HU: M2${suffix}')
$newContent = [regex]::Replace($newContent, '(?i)(?<prefix>id="|channel="|<display-name[^>]*>)HU:\s*DUNA\s+TV(?<suffix>"|</display-name>)', '${prefix}HU: DUNA${suffix}')
$newContent = [regex]::Replace($newContent, '(?i)(?<prefix>id="|channel="|<display-name[^>]*>)HU:\s*FEM\s*3(?<suffix>"|</display-name>)', '${prefix}HU: FEM 3${suffix}')
$newContent = [regex]::Replace($newContent, '(?i)(?<prefix>id="|channel="|<display-name[^>]*>)HU:\s*FILM\s+CAF(É|E)(?<suffix>"|</display-name>)', '${prefix}HU: FILM CAFE${suffix}')
$newContent = [regex]::Replace($newContent, '(?i)(?<prefix>id="|channel="|<display-name[^>]*>)HU:\s*FILM\s+M(Á|A)NIA(?<suffix>"|</display-name>)', '${prefix}HU: FILM MANIA${suffix}')
$newContent = [regex]::Replace($newContent, '(?i)(?<prefix>id="|channel="|<display-name[^>]*>)HU:\s*GALAXY\s*4(?<suffix>"|</display-name>)', '${prefix}HU: GALAXY4${suffix}')
$newContent = [regex]::Replace($newContent, '(?i)(?<prefix>id="|channel="|<display-name[^>]*>)HU:\s*M4\s+SPORT(?<suffix>"|</display-name>)', '${prefix}HU: M4${suffix}')
$newContent = [regex]::Replace($newContent, '(?i)(?<prefix>id="|channel="|<display-name[^>]*>)HU:\s*OZONE\s*TV(?<suffix>"|</display-name>)', '${prefix}HU: OZONE NETWORK${suffix}')
$newContent = [regex]::Replace($newContent, '(?i)(?<prefix>id="|channel="|<display-name[^>]*>)HU:\s*RTL\s+KETT(Ő|Ö|O)(?<suffix>"|</display-name>)', '${prefix}HU: RTL II${suffix}')
$newContent = [regex]::Replace($newContent, '(?i)(?<prefix>id="|channel="|<display-name[^>]*>)HU:\s*RTL(?<suffix>"|</display-name>)', '${prefix}HU: RTL KLUB${suffix}')
$newContent = [regex]::Replace($newContent, '(?i)(?<prefix>id="|channel="|<display-name[^>]*>)HU:\s*SL(Á|A)GER\s+TV(?<suffix>"|</display-name>)', '${prefix}HU: SLAGER TV${suffix}')
$newContent = [regex]::Replace($newContent, '(?i)(?<prefix>id="|channel="|<display-name[^>]*>)HU:\s*MOZI\s*(\+|PLUS)(?<suffix>"|</display-name>)', '${prefix}HU: MOZI+${suffix}')
$newContent = [regex]::Replace($newContent, '(?i)(?<prefix>id="|channel="|<display-name[^>]*>)HU:\s*TV2\s*S(É|E)F(?<suffix>"|</display-name>)', '${prefix}HU: TV2 SÉF${suffix}')
$newContent = [regex]::Replace($newContent, '(?i)(?<prefix>id="|channel="|<display-name[^>]*>)HU:\s*TV\s*4(?<suffix>"|</display-name>)', '${prefix}HU: TV 4${suffix}')
$newContent = [regex]::Replace($newContent, '(?i)(?<prefix>id="|channel="|<display-name[^>]*>)HU:\s*(THE\s+)?FISHING\s*(&amp;|&|AND)\s*HUNTING(?<suffix>"|</display-name>)', '${prefix}HU: FISHING AND HUNTING${suffix}')
$newContent = [regex]::Replace($newContent, '(?i)(?<prefix>id="|channel="|<display-name[^>]*>)HU:\s*RTL\s*(\+|PLUS)(?<suffix>"|</display-name>)', '${prefix}HU: RTL+${suffix}')

# 3. Duplikált csatornák kiszűrése és többes névvariációk generálása
$seenChannels = @{}
$channelPattern = '(?s)<channel[^>]*id="HU:\s*(?<cname>[^"]+)"[^>]*>(?<inner>.*?)</channel>'
$newContent = [regex]::Replace($newContent, $channelPattern, {
    param($m)
    $baseName = $m.Groups['cname'].Value.Trim()
    if ($seenChannels.ContainsKey($baseName)) {
        return ""
    }
    $seenChannels[$baseName] = $true

    $inner = [regex]::Replace($m.Groups['inner'].Value, '(?s)\s*<display-name[^>]*>.*?</display-name>', '')
    
    $aliases = @($baseName)
    switch ($baseName) {
        "MOZI+"               { $aliases = @("MOZI+", "MOZI", "MOZI PLUS") }
        "TV2 SÉF"             { $aliases = @("TV2 SÉF", "TV2 SEF", "TV2SEF", "TV2SÉF") }
        "TV 4"                { $aliases = @("TV 4", "TV4") }
        "FISHING AND HUNTING" { $aliases = @("FISHING &amp; HUNTING", "FISHING AND HUNTING") }
        "RTL+"                { $aliases = @("RTL+", "RTL +", "RTL PLUS", "RTLPLUS") }
    }

    $names = ""
    foreach ($alias in $aliases) {
        $names += "`r`n  <display-name>$alias</display-name>" +
                  "`r`n  <display-name>HU: $alias</display-name>" +
                  "`r`n  <display-name>HUN: $alias</display-name>" +
                  "`r`n  <display-name>IHUI $alias</display-name>" +
                  "`r`n  <display-name>┃HU┃ $alias</display-name>" +
                  "`r`n  <display-name>HU -  $alias</display-name>" +
                  "`r`n  <display-name>$alias (HD)</display-name>"
    }

    return "<channel id=`"HU: $baseName`">$names$inner</channel>"
})

# 4. Duplikált műsorok kiszűrése
$seenProgrammes = @{}
$progPattern = '(?s)<programme[^>]*start="(?<start>[^"]+)"[^>]*channel="(?<chan>[^"]+)"[^>]*>.*?</programme>'
$newContent = [regex]::Replace($newContent, $progPattern, {
    param($m)
    $key = $m.Groups['chan'].Value + "_" + $m.Groups['start'].Value
    if ($seenProgrammes.ContainsKey($key)) {
        return ""
    }
    $seenProgrammes[$key] = $true
    return $m.Value
})

Set-Content -Path $output -Value $newContent -Encoding UTF8

# Tömörített .xml.gz mentése is
$rawBytes = [System.Text.Encoding]::UTF8.GetBytes($newContent)
$outGzStream = New-Object System.IO.FileStream $outputGz, ([IO.FileMode]::Create)
$gzipWriter = New-Object System.IO.Compression.GzipStream $outGzStream, ([IO.Compression.CompressionMode]::Compress)
$gzipWriter.Write($rawBytes, 0, $rawBytes.Length)
$gzipWriter.Close()
$outGzStream.Close()
