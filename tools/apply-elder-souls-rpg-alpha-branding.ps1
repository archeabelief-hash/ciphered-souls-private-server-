$ErrorActionPreference = 'Stop'

$serverRoot = 'recovered/server'
$clientRoot = 'recovered/client'
$brand = 'Elder Souls RPG Alpha'
$brandCompact = 'ElderSoulsRPGAlpha'
$brandCache = 'ELDER_SOULS_RPG_ALPHA'
$projectUrl = 'https://github.com/archeabelief-hash/ciphered-souls-private-server-'

function Write-Text([string]$path, [string]$text) {
    Set-Content -Path $path -Value $text -NoNewline -Encoding UTF8
}

function Replace-Literal([string]$path, [string]$old, [string]$new) {
    if (-not (Test-Path $path)) { return }
    $text = Get-Content $path -Raw
    $next = $text.Replace($old, $new)
    if ($next -ne $text) {
        Write-Text $path $next
        Write-Host "BRAND-PATCH|$path|$old|$new"
    }
}

function Replace-Regex([string]$path, [string]$pattern, [string]$replacement) {
    if (-not (Test-Path $path)) { return }
    $text = Get-Content $path -Raw
    $next = [regex]::Replace($text, $pattern, $replacement)
    if ($next -ne $text) {
        Write-Text $path $next
        Write-Host "BRAND-REGEX|$path|$pattern"
    }
}

Write-Host '=== Elder Souls RPG Alpha branding / path normalization ==='

$settings = "$serverRoot/src/main/java/com/rs/Settings.java"
if (Test-Path $settings) {
    $s = Get-Content $settings -Raw
    $s = [regex]::Replace($s, 'public static final String SERVER_NAME = "[^"]*";', 'public static final String SERVER_NAME = "Elder Souls RPG Alpha";')
    $s = $s.Replace('"Matrix", LIVE_IP', '"Elder Souls RPG Alpha", LIVE_IP')
    $s = [regex]::Replace($s, 'public static final String WEB_API_LINK = "[^"]*";', 'public static final String WEB_API_LINK = "";')
    $s = [regex]::Replace($s, 'public static final String HIGHSCORES_API_LINK = "[^"]*";', 'public static final String HIGHSCORES_API_LINK = "";')
    foreach ($field in @('WEBSITE_LINK','FORUMS_LINK','HIGHSCORES_LINK','VOTE_LINK','YOUTUBE_LINK','DONATE_LINK','OFFENCES_LINK','EMAIL_LINK','PASSWORD_LINK','COMMANDS_LINK','SHOWTHREAD_LINK','HELP_LINK')) {
        $s = [regex]::Replace($s, ('public static final String ' + $field + ' = "[^"]*";'), ('public static final String ' + $field + ' = "' + $projectUrl + '";'))
    }
    $s = $s.Replace('Matrix!', 'Elder Souls RPG Alpha!')
    Write-Text $settings $s
}

$serverDataFiles = Get-ChildItem "$serverRoot/data" -Recurse -File -ErrorAction SilentlyContinue |
    Where-Object { $_.Extension.ToLowerInvariant() -in @('.txt','.cfg','.conf','.xml','.json','.properties') }

foreach ($file in $serverDataFiles) {
    $text = Get-Content $file.FullName -Raw -ErrorAction SilentlyContinue
    if ($null -eq $text) { continue }
    $next = $text
    $next = [regex]::Replace($next, '\s*<small><a[^>]*href="http://Matrix\.wikia\.com/[^"]*"[^>]*>edit</a></small>', '')
    $next = [regex]::Replace($next, '\bMatrix''s\b', "Elder Souls RPG Alpha's")
    $next = [regex]::Replace($next, '\bMatrix\b', 'Elder Souls RPG Alpha')
    if ($next -ne $text) {
        Write-Text $file.FullName $next
        Write-Host "DATA-BRAND|$($file.FullName)"
    }
}

$serverJava = Get-ChildItem "$serverRoot/src/main/java" -Recurse -Filter '*.java' -File -ErrorAction SilentlyContinue
foreach ($file in $serverJava) {
    if ($file.FullName -eq (Resolve-Path $settings).Path) { continue }
    $text = Get-Content $file.FullName -Raw
    $next = $text

    $next = $next.Replace("Matrix's", "Elder Souls RPG Alpha's")
    $next = $next.Replace('Welcome to Matrix', 'Welcome to Elder Souls RPG Alpha')
    $next = $next.Replace('Starting Matrix', 'Starting Elder Souls RPG Alpha')
    $next = $next.Replace('Error loading Matrix', 'Error loading Elder Souls RPG Alpha')
    $next = $next.Replace('world of Matrix', 'world of Elder Souls RPG Alpha')
    $next = $next.Replace('World of Matrix', 'World of Elder Souls RPG Alpha')
    $next = $next.Replace('citizens of Matrix', 'citizens of Elder Souls RPG Alpha')
    $next = $next.Replace('citizen of Matrix', 'citizen of Elder Souls RPG Alpha')
    $next = $next.Replace('throughout Matrix', 'throughout Elder Souls RPG Alpha')
    $next = $next.Replace('exploring Matrix', 'exploring Elder Souls RPG Alpha')
    $next = $next.Replace('on Matrix', 'in Elder Souls RPG Alpha')
    $next = $next.Replace('of Matrix', 'of Elder Souls RPG Alpha')
    $next = $next.Replace('Matrix is ', 'Elder Souls RPG Alpha is ')
    $next = $next.Replace('Matrix boss', 'Elder Souls boss')
    $next = $next.Replace('Matrix RSPS', 'Elder Souls RPG Alpha')
    $next = $next.Replace('Matrix guide', 'Elder Guide')
    $next = $next.Replace('Matrix friends chat', 'Elder Souls friends chat')
    $next = $next.Replace('Matrix Mode', 'Elder Souls Mode')
    $next = $next.Replace('"MATRIX"', '"ELDER SOULS"')

    $next = $next.Replace('equals("Matrix")', 'equals("Elder Warden")')
    $next = $next.Replace('equalsIgnoreCase("Matrix")', 'equalsIgnoreCase("Elder Warden")')
    $next = $next.Replace('"Matrix", "Alchemical Hydra"', '"Elder Warden", "Alchemical Hydra"')

    $next = [regex]::Replace($next, 'https?://(?:www\.)?matrixrsps\.io[^"]*', $projectUrl)
    $next = $next.Replace('matrixrsps.io', 'github')

    if ($next -ne $text) {
        Write-Text $file.FullName $next
        Write-Host "SERVER-BRAND|$($file.FullName)"
    }
}

Replace-Literal "$serverRoot/src/main/java/com/rs/game/player/content/custom/CustomItems.java" 'config.name = "Matrix Token";' 'config.name = "Elder Sigil";'
Replace-Literal "$serverRoot/src/main/java/com/rs/game/player/content/custom/CustomObjects.java" 'config.name = "Matrix''s statue";' 'config.name = "Elder Souls Monument";'

$highscores = "$serverRoot/src/main/java/com/rs/sql/Highscores.java"
if (Test-Path $highscores) {
    Replace-Regex $highscores 'Database db = new Database\("[^"]*", "[^"]*", "[^"]*", "[^"]*"\);' 'Database db = new Database("127.0.0.1", "", "", ""); // hosted highscores disabled in local alpha'
}

$playersOnline = "$serverRoot/src/main/java/com/rs/utils/PlayersOnline.java"
if (Test-Path $playersOnline) {
    Replace-Regex $playersOnline 'https?://matrixrsps\.io/playercount\.php\?key=[^"&]*&count=' 'http://127.0.0.1:65535/playercount?count='
}

$clientSettings = "$clientRoot/src/main/java/Settings.java"
if (Test-Path $clientSettings) {
    $x = Get-Content $clientSettings -Raw
    $x = [regex]::Replace($x, 'public static final Object ABSOLOUTE_CACHE_NAME_1 = "[^"]*";', 'public static final Object ABSOLOUTE_CACHE_NAME_1 = "ELDER_SOULS_RPG_ALPHA";')
    $x = [regex]::Replace($x, 'public static final String ABSOLOUTE_CACHE_NAME_2 = "[^"]*";', 'public static final String ABSOLOUTE_CACHE_NAME_2 = "718";')
    $x = [regex]::Replace($x, 'public static final Object CACHE_NAME = "[^"]*";', 'public static final Object CACHE_NAME = "ELDER_SOULS_RPG_ALPHA";')
    $x = [regex]::Replace($x, 'public static final String CACHE_SUB_NAME = "[^"]*";', 'public static final String CACHE_SUB_NAME = "718";')
    $x = [regex]::Replace($x, 'public static final String RECOVER_PASS_LINK = "[^"]*";', ('public static final String RECOVER_PASS_LINK = "' + $projectUrl + '";'))
    Write-Text $clientSettings $x
}

$loader = "$clientRoot/src/main/java/Loader.java"
if (Test-Path $loader) {
    $x = Get-Content $loader -Raw
    $x = $x.Replace('Matrix RSPS', 'Elder Souls RPG Alpha')
    $x = $x.Replace('Elder Souls Scape PK Training', 'Elder Souls RPG Alpha')
    $x = $x.Replace('Ciphered Souls - Local 718', 'Elder Souls RPG Alpha')
    $x = $x.Replace('Ciphered Souls — Local 718', 'Elder Souls RPG Alpha')
    Write-Text $loader $x
}

$runeLite = "$clientRoot/src/main/java/net/runelite/client/RuneLite.java"
if (Test-Path $runeLite) {
    $x = Get-Content $runeLite -Raw
    $x = [regex]::Replace($x, 'new File\(System\.getProperty\("user\.home"\), "[^"]*"\)', 'new File(System.getProperty("user.home"), "ElderSoulsRPGAlpha")', 1)
    Write-Text $runeLite $x
}

Replace-Literal "$clientRoot/src/main/java/logback.xml" '${user.home}/MATRIX/logs/' '${user.home}/ElderSoulsRPGAlpha/logs/'
Replace-Literal "$clientRoot/src/main/java/Class291.java" '"Matrix.dat"' '"ElderSoulsRPGAlpha.dat"'

foreach ($path in @(
    "$clientRoot/src/main/java/Class460.java",
    "$clientRoot/src/main/java/client.java"
)) {
    if (Test-Path $path) {
        $x = Get-Content $path -Raw
        $x = [regex]::Replace($x, 'https?://(?:www\.)?matrixrsps\.io[^"]*', $projectUrl)
        Write-Text $path $x
    }
}

foreach ($path in @(
    "$clientRoot/src/main/java/ClientScript.java",
    "$clientRoot/src/main/java/WidgetConfig.java"
)) {
    if (Test-Path $path) {
        $x = Get-Content $path -Raw
        $x = $x.Replace('string.replace("runescape", "matrix")', 'string.replace("runescape", "elder souls")')
        $x = $x.Replace('string.replace("RuneScape", "Matrix")', 'string.replace("RuneScape", "Elder Souls RPG Alpha")')
        $x = $x.Replace('string.replace("Runescape", "Matrix")', 'string.replace("Runescape", "Elder Souls RPG Alpha")')
        $x = $x.Replace('text.replace("runescape", "matrix")', 'text.replace("runescape", "elder souls")')
        $x = $x.Replace('text.replace("RuneScape", "Matrix")', 'text.replace("RuneScape", "Elder Souls RPG Alpha")')
        $x = $x.Replace('text.replace("Runescape", "Matrix")', 'text.replace("Runescape", "Elder Souls RPG Alpha")')
        Write-Text $path $x
    }
}

$customItems = "$clientRoot/src/main/java/CustomItems.java"
if (Test-Path $customItems) {
    $x = Get-Content $customItems -Raw
    $x = $x.Replace('Matrix Token', 'Elder Sigil')
    $x = $x.Replace('Matrix pet', 'Elder familiar')
    $x = $x.Replace('(short) 48547; // #4B1F6F deep purple', '(short) 49699; // #4B1F6F deep royal purple')
    $x = $x.Replace('(short) (i == elderCapeColors.length - 1 ? 7726 : 8770); // dark/gold trim', '(short) (i == elderCapeColors.length - 1 ? 8899 : 7855); // gold / dark-gold trim')
    $x = $x.Replace('(short) (i % 2 == 0 ? 48547 : 49683); // purple + shadow purple', '(short) (i % 2 == 0 ? 49699 : 50707); // royal purple / shadow purple')
    Write-Text $customItems $x
}

$customNpcs = "$clientRoot/src/main/java/CustomNPCs.java"
if (Test-Path $customNpcs) {
    $x = Get-Content $customNpcs -Raw
    $x = $x.Replace('Matrix guide', 'Elder Guide')
    $x = $x.Replace('Matrix pet', 'Elder familiar')
    $x = $x.Replace('config.name = "Matrix";', 'config.name = "Elder Warden";')
    Write-Text $customNpcs $x
}

$customObjects = "$clientRoot/src/main/java/CustomObjects.java"
if (Test-Path $customObjects) {
    $x = Get-Content $customObjects -Raw
    $x = $x.Replace("Matrix's hand", "Elder hand")
    $x = $x.Replace('Matrix nexus', 'Elder nexus')
    $x = $x.Replace("Matrix's Statue", "Elder Souls Monument")
    Write-Text $customObjects $x
}

$discord = "$clientRoot/src/main/java/Discord.java"
if (Test-Path $discord) {
    $x = Get-Content $discord -Raw
    $x = $x.Replace('Playing [matrixrsps.io]', 'Playing Elder Souls RPG Alpha')
    $x = $x.Replace('Matrix RSPS', 'Elder Souls RPG Alpha')
    Write-Text $discord $x
}

$packets = "$clientRoot/src/main/java/PacketsDecoder.java"
if (Test-Path $packets) {
    $x = Get-Content $packets -Raw
    $x = $x.Replace('"Matrix", "matrix", "Matrix"', '"Elder Souls", "elder_souls", "Elder Souls RPG Alpha"')
    Write-Text $packets $x
}

$clientLoader = "$clientRoot/src/main/java/net/runelite/client/rs/ClientLoader.java"
if (Test-Path $clientLoader) {
    $x = Get-Content $clientLoader -Raw
    $x = $x.Replace('Starting Matrix', 'Starting Elder Souls RPG Alpha')
    $x = $x.Replace('Error loading Matrix!', 'Error loading Elder Souls RPG Alpha!')
    Write-Text $clientLoader $x
}

$configPlugin = "$clientRoot/src/main/java/net/runelite/client/plugins/config/ConfigPlugin.java"
if (Test-Path $configPlugin) {
    $x = Get-Content $configPlugin -Raw
    $x = $x.Replace('"Matrix", "Matrix client settings"', '"Elder Souls RPG Alpha", "Elder Souls RPG Alpha client settings"')
    Write-Text $configPlugin $x
}

$fatal = "$clientRoot/src/main/java/net/runelite/client/ui/FatalErrorDialog.java"
if (Test-Path $fatal) {
    $x = Get-Content $fatal -Raw
    $x = $x.Replace('starting Matrix', 'starting Elder Souls RPG Alpha')
    $x = $x.Replace('Matrix was unable', 'Elder Souls RPG Alpha was unable')
    $x = $x.Replace('Matrix is unable', 'Elder Souls RPG Alpha is unable')
    $x = $x.Replace('Matrix encountered', 'Elder Souls RPG Alpha encountered')
    Write-Text $fatal $x
}

$props = "$clientRoot/src/main/resources/runelite.properties"
if (Test-Path $props) {
    $x = Get-Content $props -Raw
    $x = [regex]::Replace($x, '(?m)^matrix\.title=.*$', 'matrix.title=Elder Souls RPG Alpha')
    $x = [regex]::Replace($x, '(?m)^matrix\.(forums|rules|store|vote|wiki)\.link=.*$', ('matrix.$1.link=' + $projectUrl))
    Write-Text $props $x
}

Write-Host '=== Branding patch complete ==='
Write-Host 'Compatibility identifiers intentionally retained: Java math class Matrix, OpenGL matrix APIs, matrix.* DI keys, Watch-Matrix-End action key.'
