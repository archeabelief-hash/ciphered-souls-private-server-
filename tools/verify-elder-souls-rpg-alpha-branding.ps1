$ErrorActionPreference = 'Stop'

$roots = @(
    'recovered/server/src/main/java',
    'recovered/server/data',
    'recovered/client/src/main/java',
    'recovered/client/src/main/resources'
)

$forbidden = @(
    'matrixrsps.io',
    'Matrix RSPS',
    'Matrix''s',
    'Matrix Token',
    'Matrix guide',
    'Matrix pet',
    'Matrix nexus',
    'Matrix''s Statue',
    'Welcome to Matrix',
    'Starting Matrix',
    'Error loading Matrix',
    '/MATRIX/logs/',
    '"Matrix.dat"',
    'Fatal error starting Matrix',
    'Matrix was unable',
    'Matrix is unable',
    'Matrix encountered',
    'Matrix client settings',
    'world of Matrix',
    'citizens of Matrix',
    'Elder Souls Scape PK Training',
    'ElderSoulsScapePKTraining',
    'Ciphered Souls',
    'CipheredSouls'
)

$allowedMatrixFragments = @(
    'Matrix class',
    'new Matrix(',
    'Matrix.aClass',
    'glMatrix',
    'LoadMatrix',
    'PushMatrix',
    'PopMatrix',
    'NormalMatrix',
    'TextureMatrix',
    'WorldMatrix',
    'modelMatrix',
    'viewMatrix',
    'projectionMatrix',
    'matrix.title',
    'matrix.version',
    'matrix.discord',
    'matrix.forums',
    'matrix.rules',
    'matrix.store',
    'matrix.vote',
    'matrix.wiki',
    'matrix.launcher',
    'matrix.dnschange',
    'Watch-Matrix-End',
    'distance matrix'
)

$failures = New-Object System.Collections.Generic.List[string]

foreach ($root in $roots) {
    if (-not (Test-Path $root)) { continue }

    Get-ChildItem $root -Recurse -File -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -notmatch '\\.git\\' } |
        ForEach-Object {
            $path = $_.FullName

            foreach ($pattern in $forbidden) {
                Select-String -Path $path -SimpleMatch -Pattern $pattern -ErrorAction SilentlyContinue |
                    ForEach-Object {
                        $entry = "FORBIDDEN|$($_.Path)|$($_.LineNumber)|$($_.Line.Trim())"
                        $failures.Add($entry)
                    }
            }

            Select-String -Path $path -Pattern '\bMatrix\b' -ErrorAction SilentlyContinue |
                ForEach-Object {
                    $line = $_.Line
                    $allowed = $false
                    foreach ($fragment in $allowedMatrixFragments) {
                        if ($line.Contains($fragment)) {
                            $allowed = $true
                            break
                        }
                    }
                    if (-not $allowed) {
                        Write-Host ("REVIEW-MATRIX|{0}|{1}|{2}" -f $_.Path,$_.LineNumber,$line.Trim())
                    }
                }
        }
}

if ($failures.Count -gt 0) {
    foreach ($failure in $failures) { Write-Host $failure }
    throw "Elder Souls RPG Alpha branding verification failed with $($failures.Count) forbidden legacy references."
}

Write-Host 'Elder Souls RPG Alpha branding verification passed.'
Write-Host 'Internal rendering/math Matrix identifiers and matrix.* DI keys remain intentionally compatible.'
