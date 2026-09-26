$ErrorActionPreference = 'Stop'

function DriveGet([string]$id,[string]$out,[int]$retries=5) {
    $u = "https://drive.usercontent.google.com/download?id=$id&export=download&confirm=t"
    curl.exe -L --fail --retry $retries --retry-delay 4 -o $out $u
    if ($LASTEXITCODE -ne 0) { throw "Download failed: $id" }
}

Write-Host '=== Recover 718 server/client source for branding audit ==='
New-Item -ItemType Directory -Force recovered/server/.git/objects/pack,recovered/client/.git/objects/pack | Out-Null
git -C recovered/server init | Out-Null
git -C recovered/client init | Out-Null
DriveGet '1yao606p_04R7yXH9vsdMitsLz1t-LB79' 'recovered/server/.git/objects/pack/pack-a0e3d5d13ccfe8addde9e81f30decc1fcb0b493f.pack'
DriveGet '1z_1DeNJMqx70GNjvlnOqL3FQThDmqaC3' 'recovered/server/.git/objects/pack/pack-a0e3d5d13ccfe8addde9e81f30decc1fcb0b493f.idx'
DriveGet '1mwe-bKDWPu5NQzHr3_XDI26F9wCdSZmN' 'recovered/client/.git/objects/pack/pack-aba9cc70f6092791ec6dbc4d5f3539166095e495.pack'
DriveGet '1e1-m-k3Skp43JE25_zz1TOkPPrzM5btb' 'recovered/client/.git/objects/pack/pack-aba9cc70f6092791ec6dbc4d5f3539166095e495.idx'
git -C recovered/server reset --hard 61999df3c7a90e50b8ffb7000433d09d621c2ac7 | Out-Null
git -C recovered/client reset --hard 6fcd5e3f9e2bf360b53832090558fadb5d17ab11 | Out-Null

$roots = @(
    'recovered/server',
    'recovered/client',
    'tools',
    'desktop',
    '.github'
)

$patterns = @(
    'Matrix',
    'MATRIX',
    'matrix',
    'Ciphered Souls',
    'CipheredSouls',
    'Elder Souls Scape',
    'ElderSoulsScape',
    'PK Training'
)

$extensions = @(
    '.java','.kt','.scala','.txt','.xml','.json','.yml','.yaml','.properties',
    '.ini','.cfg','.conf','.js','.cjs','.mjs','.ps1','.bat','.cmd','.cs','.iss'
)

Write-Host '=== BRANDING STRING REFERENCES ==='
foreach ($root in $roots) {
    if (-not (Test-Path $root)) { continue }
    Get-ChildItem $root -Recurse -File -ErrorAction SilentlyContinue |
        Where-Object {
            ($extensions -contains $_.Extension.ToLowerInvariant()) -and
            $_.FullName -notmatch '\\.git\\'
        } |
        ForEach-Object {
            $file = $_.FullName
            foreach ($pattern in $patterns) {
                Select-String -Path $file -SimpleMatch -Pattern $pattern -ErrorAction SilentlyContinue |
                    ForEach-Object {
                        $rel = Resolve-Path -Relative $_.Path
                        Write-Host ("MATCH|{0}|{1}|{2}|{3}" -f $pattern,$rel,$_.LineNumber,$_.Line.Trim())
                    }
            }
        }
}

Write-Host '=== FILE/FOLDER NAMES CONTAINING MATRIX/CIPHERED/PK-TRAINING ==='
foreach ($root in @('recovered/server','recovered/client','desktop','tools')) {
    if (-not (Test-Path $root)) { continue }
    Get-ChildItem $root -Recurse -Force -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -notmatch '\\.git\\' -and $_.Name -match '(?i)matrix|ciphered|pk.?training' } |
        ForEach-Object {
            Write-Host ("PATH|{0}" -f (Resolve-Path -Relative $_.FullName))
        }
}

Write-Host '=== END BRANDING AUDIT ==='
