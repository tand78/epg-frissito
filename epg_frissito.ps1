$url = "https://www.dropbox.com/scl/fi/caifjmth2phg24fq4k8to/friss_epg.xml?rlkey=ndai73r0r4bl98ip838p1ko5f&st=l2ehpif9&dl=1"
$output = "friss_epg.xml"
$temp = "temp_epg.dat"

Invoke-WebRequest -Uri $url -OutFile $temp

$bytes = [System.IO.File]::ReadAllBytes($temp)
if ($bytes.Length -ge 2 -and $bytes.GetValue(0) -eq 0x1F -and $bytes.GetValue(1) -eq 0x8B) {
    $in = New-Object System.IO.FileStream $temp, ([IO.FileMode]::Open)
    $out = New-Object System.IO.FileStream $output, ([IO.FileMode]::Create)
    $gz = New-Object System.IO.Compression.GzipStream $in, ([IO.Compression.CompressionMode]::Decompress)
    $gz.CopyTo($out)
    $gz.Close(); $out.Close(); $in.Close()
    Remove-Item $temp -Force
} else {
    Move-Item $temp $output -Force
}

$content = Get-Content -Path $output -Raw -Encoding UTF8

# 1. Általános tisztítás, nagybetűsítés és (HD) / .hu törlése
$pattern = '(?i)(?<prefix>id="|channel="|<display-name[^>]*>)(?:HU:\s*)?(?<name>[^"<]+?)(?:\s*(?:\(HD\)|\.hu))*\s*(?<suffix>"|</display-name>)'
$newContent = [regex]::Replace($content, $pattern, { param($m) return $m.Groups['prefix'].Value + "HU: " + $m.Groups['name'].Value.Trim().ToUpper() + $m.Groups['suffix'].Value })

# 2. Minden egyedi csatornanév-csere
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

# 3. Több <display-name> névvariáció generálása minden csatornához (┃HU┃ előtaggal)
$channelPattern = '(?s)<channel[^>]*id="HU:\s*(?<cname>[^"]+)"[^>]*>(?<inner>.*?)</channel>'
$newContent = [regex]::Replace($newContent, $channelPattern, {
    param($m)
    $baseName = $m.Groups['cname'].Value.Trim()
    $inner = [regex]::Replace($m.Groups['inner'].Value, '(?s)\s*<display-name[^>]*>.*?</display-name>', '')
    $names = "`r`n  <display-name>$baseName</display-name>" +
             "`r`n  <display-name>HU: $baseName</display-name>" +
             "`r`n  <display-name>HUN: $baseName</display-name>" +
             "`r`n  <display-name>IHUI $baseName</display-name>" +
             "`r`n  <display-name>┃HU┃ $baseName</display-name>" +
             "`r`n  <display-name>$baseName (HD)</display-name>"
    return "<channel id=`"HU: $baseName`">$names$inner</channel>"
})

Set-Content -Path $output -Value $newContent -Encoding UTF8
