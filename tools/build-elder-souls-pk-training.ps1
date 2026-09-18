$ErrorActionPreference = 'Stop'

function DriveGet([string]$id,[string]$out,[int]$retries=5) {
    $u = "https://drive.usercontent.google.com/download?id=$id&export=download&confirm=t"
    curl.exe -L --fail --retry $retries --retry-delay 4 -o $out $u
    if ($LASTEXITCODE -ne 0) { throw "Download failed: $id" }
}

Write-Host '=== Recover server and client sources ==='
New-Item -ItemType Directory -Force recovered/server/.git/objects/pack,recovered/client/.git/objects/pack | Out-Null
git -C recovered/server init
git -C recovered/client init
DriveGet '1yao606p_04R7yXH9vsdMitsLz1t-LB79' 'recovered/server/.git/objects/pack/pack-a0e3d5d13ccfe8addde9e81f30decc1fcb0b493f.pack'
DriveGet '1z_1DeNJMqx70GNjvlnOqL3FQThDmqaC3' 'recovered/server/.git/objects/pack/pack-a0e3d5d13ccfe8addde9e81f30decc1fcb0b493f.idx'
DriveGet '1mwe-bKDWPu5NQzHr3_XDI26F9wCdSZmN' 'recovered/client/.git/objects/pack/pack-aba9cc70f6092791ec6dbc4d5f3539166095e495.pack'
DriveGet '1e1-m-k3Skp43JE25_zz1TOkPPrzM5btb' 'recovered/client/.git/objects/pack/pack-aba9cc70f6092791ec6dbc4d5f3539166095e495.idx'
git -C recovered/server reset --hard 61999df3c7a90e50b8ffb7000433d09d621c2ac7
git -C recovered/client reset --hard 6fcd5e3f9e2bf360b53832090558fadb5d17ab11

Write-Host '=== Patch localhost/private operation ==='
$sp = 'recovered/server/src/main/java/com/rs/Settings.java'
$s = Get-Content $sp -Raw
$s = $s.Replace('public static final String SERVER_NAME = "Matrix";', 'public static final String SERVER_NAME = "Elder Souls Scape PK Training";')
$s = [regex]::Replace($s, 'private static final String LIVE_IP = "[^"]*";[^\r\n]*', 'private static final String LIVE_IP = "127.0.0.1"; // local-only')
$s = $s.Replace('new InetSocketAddress("0.0.0.0", 43593)', 'new InetSocketAddress("127.0.0.1", 43593)')
$s = $s.Replace('new InetSocketAddress("0.0.0.0", 43599)', 'new InetSocketAddress("127.0.0.1", 43599)')
$s = [regex]::Replace($s, 'public static final String EVERYTHING_RS_SECRET_KEY = "[^"]*";', 'public static final String EVERYTHING_RS_SECRET_KEY = "";')
$s = [regex]::Replace($s, 'public static String MASTER_PASSWORD = "[^"]*";', 'public static String MASTER_PASSWORD = "";')
Set-Content $sp $s -NoNewline

$gl = 'recovered/server/src/main/java/com/rs/GameLauncher.java'
$g = Get-Content $gl -Raw
$g = $g.Replace('} else {`r`n`t`t`t`t`t`t`tSystem.err.println("Unknown cmd");', '} else if (line.equalsIgnoreCase("shutdown")) {`r`n`t`t`t`t`t`t`tinitShutdown();`r`n`t`t`t`t`t`t`t} else {`r`n`t`t`t`t`t`t`tSystem.err.println("Unknown cmd");')
if (-not $g.Contains('line.equalsIgnoreCase("shutdown")')) {
    $g = $g.Replace('} else {`n`t`t`t`t`t`t`tSystem.err.println("Unknown cmd");', '} else if (line.equalsIgnoreCase("shutdown")) {`n`t`t`t`t`t`t`tinitShutdown();`n`t`t`t`t`t`t`t} else {`n`t`t`t`t`t`t`tSystem.err.println("Unknown cmd");')
}
Set-Content $gl $g -NoNewline

$ll = 'recovered/server/src/main/java/com/rs/LoginLauncher.java'
$l = Get-Content $ll -Raw
$needle = 'LoginServerChannelManager.sendReliablePacket(world, LoginChannelsPacketEncoder.encodeConsoleMessage("Hello there from login!").trim());'
$l = $l.Replace($needle, $needle + "`r`n`t`tif (!Settings.HOSTED) return; // integrated local login server: game launcher owns stdin")
Set-Content $ll $l -NoNewline

$cp = 'recovered/client/src/main/java/Settings.java'
$c = Get-Content $cp -Raw
$c = [regex]::Replace($c, 'public static String local = //[\s\S]*?//"127\.0\.0\.1"; // local', 'public static String local = "127.0.0.1"; // local-only Elder Souls Scape PK Training', 1)
$c = $c.Replace('public static final Object ABSOLOUTE_CACHE_NAME_1 = "MATRIX";', 'public static final Object ABSOLOUTE_CACHE_NAME_1 = "ELDER_SOULS_SCAPE_PK_TRAINING";')
$c = $c.Replace('public static final String ABSOLOUTE_CACHE_NAME_2 = "RSPS";', 'public static final String ABSOLOUTE_CACHE_NAME_2 = "718";')
$c = $c.Replace('public static final Object CACHE_NAME = "MATRIX";', 'public static final Object CACHE_NAME = "ELDER_SOULS_SCAPE_PK_TRAINING";')
$c = $c.Replace('public static final String CACHE_SUB_NAME = "MATRIX";', 'public static final String CACHE_SUB_NAME = "718";')
Set-Content $cp $c -NoNewline

$loader = 'recovered/client/src/main/java/Loader.java'
$x = Get-Content $loader -Raw
$x = $x.Replace('Matrix RSPS', 'Elder Souls Scape PK Training')
$x = [regex]::Replace($x, '(?m)^\s*Discord\.init\(\);\s*$', '        // Discord integration disabled for local build.')
Set-Content $loader $x -NoNewline

$rl = 'recovered/client/src/main/java/net/runelite/client/RuneLite.java'
$r = Get-Content $rl -Raw
$r = $r.Replace('new File(System.getProperty("user.home"), "MATRIX")', 'new File(System.getProperty("user.home"), "ElderSoulsScapePKTraining")')
Set-Content $rl $r -NoNewline

Write-Host '=== Apply PK Training Arena gameplay patch ==='
./tools/apply-elder-souls-pk-training.ps1

Write-Host '=== Download build dependencies ==='
New-Item -ItemType Directory -Force deps | Out-Null
$base='https://repo.maven.apache.org/maven2'
$urls=@(
    "$base/io/netty/netty-common/4.1.87.Final/netty-common-4.1.87.Final.jar",
    "$base/io/netty/netty-buffer/4.1.87.Final/netty-buffer-4.1.87.Final.jar",
    "$base/io/netty/netty-transport/4.1.87.Final/netty-transport-4.1.87.Final.jar",
    "$base/io/netty/netty-resolver/4.1.87.Final/netty-resolver-4.1.87.Final.jar",
    "$base/io/netty/netty-codec/4.1.87.Final/netty-codec-4.1.87.Final.jar",
    "$base/io/netty/netty-handler/4.1.87.Final/netty-handler-4.1.87.Final.jar",
    "$base/org/apache/httpcomponents/httpcore/4.4.16/httpcore-4.4.16.jar",
    "$base/org/apache/httpcomponents/httpclient/4.5.14/httpclient-4.5.14.jar",
    "$base/commons-logging/commons-logging/1.2/commons-logging-1.2.jar",
    "$base/commons-codec/commons-codec/1.15/commons-codec-1.15.jar",
    "$base/org/projectlombok/lombok/1.18.30/lombok-1.18.30.jar",
    "$base/org/slf4j/slf4j-api/1.7.7/slf4j-api-1.7.7.jar",
    "$base/com/google/code/findbugs/jsr305/3.0.2/jsr305-3.0.2.jar"
)
foreach($u in $urls){ curl.exe -L --fail -o (Join-Path deps ([IO.Path]::GetFileName($u))) $u; if($LASTEXITCODE -ne 0){throw "Dependency download failed: $u"} }

Write-Host '=== Compile server and client ==='
if(Test-Path build){Remove-Item build -Recurse -Force}
New-Item -ItemType Directory -Force build/server-classes,build/client-classes | Out-Null
Get-ChildItem recovered/server/src/main/java -Recurse -Filter *.java | ForEach-Object FullName | Set-Content build/server-sources.txt
& javac --release 17 -encoding UTF-8 -cp 'recovered/server/data/lib/*;deps/*' -d build/server-classes '@build/server-sources.txt'
if($LASTEXITCODE -ne 0){throw 'Server compile failed'}
Get-ChildItem recovered/client/src/main/java -Recurse -Filter *.java | ForEach-Object FullName | Set-Content build/client-sources.txt
& javac -source 8 -target 8 -encoding UTF-8 -cp 'recovered/client/lib/*;deps/*' -processorpath 'deps/lombok-1.18.30.jar' -d build/client-classes '@build/client-sources.txt'
if($LASTEXITCODE -ne 0){throw 'Client compile failed'}
& jar --create --file build/elder-souls-scape-pk-training-server.jar --main-class com.rs.GameLauncher -C build/server-classes .
& jar --create --file build/elder-souls-scape-pk-training-client.jar --main-class Loader -C build/client-classes .
if(Test-Path recovered/server/src/main/resources){& jar --update --file build/elder-souls-scape-pk-training-server.jar -C recovered/server/src/main/resources .}
if(Test-Path recovered/client/src/main/resources){& jar --update --file build/elder-souls-scape-pk-training-client.jar -C recovered/client/src/main/resources .}

Write-Host '=== Assemble app and full cache ==='
$root='dist/Elder Souls Scape PK Training 718'
New-Item -ItemType Directory -Force "$root/server/data/cache","$root/server/lib","$root/client/lib","$root/logs" | Out-Null
Copy-Item build/elder-souls-scape-pk-training-server.jar "$root/server/"
Copy-Item build/elder-souls-scape-pk-training-client.jar "$root/client/"
Copy-Item recovered/server/data/* "$root/server/data/" -Recurse -Force
if(Test-Path "$root/server/data/cache"){Remove-Item "$root/server/data/cache" -Recurse -Force}
New-Item -ItemType Directory -Force "$root/server/data/cache" | Out-Null
Copy-Item recovered/server/data/lib/* "$root/server/lib/" -Force
Copy-Item deps/*.jar "$root/server/lib/" -Force
Copy-Item recovered/client/lib/* "$root/client/lib/" -Force
Copy-Item deps/slf4j-api-1.7.7.jar "$root/client/lib/" -Force
Copy-Item deps/jsr305-3.0.2.jar "$root/client/lib/" -Force

$cache=@{
    'main_file_cache.dat2'='1RnuylAaBrJloewHYe1RI5mlD3sy3MvzA';
    'main_file_cache.idx0'='1J_GQvzjLsMWZMgynuFILOwy-Gct-V-4d'; 'main_file_cache.idx1'='19ajuYaKNxwNWLWRTuwNIHLF0SDs-GFZs';
    'main_file_cache.idx2'='1-lErZUN8L5S6MDosxTzKja_Ytm2FA_Rl'; 'main_file_cache.idx3'='1jX0hSkmpKnZ8hv6wV2_BGKiy4nBlt2_x';
    'main_file_cache.idx4'='1KgMoDzIPbP9RNHCes5ZX_IlQmbhHHWf7'; 'main_file_cache.idx5'='1iV87Hup2VbF60mO0uP75ArxpTREq0F1K';
    'main_file_cache.idx6'='1E0UasPeTaG9m6mwetMVeK73eYNkNbhfU'; 'main_file_cache.idx7'='1rEf24InYd1d-obzFZRN3cPCJJcsYmiVp';
    'main_file_cache.idx8'='1PWo3UAInEC2c__tX-WQpSL7kfgNWPKZP'; 'main_file_cache.idx9'='1y6_wf4j6VvtzOi88UUFpVx_2IkaNez2p';
    'main_file_cache.idx10'='1A_QbM0GyHWs9HKaApz33Q9Pgov-kWSPC'; 'main_file_cache.idx11'='1BDTrIsOcRW_xhjCH9RjllD0sPpga6DcX';
    'main_file_cache.idx12'='1v0SA8xvVpCmy31QtyGobjjVi_VAbAIi5'; 'main_file_cache.idx13'='1JPAx1QYWeZSH4iUKf-oUxCCRDGbdCALn';
    'main_file_cache.idx14'='1-XCu0Zln9cKFiq3bL609q0eSKRak_Pf5'; 'main_file_cache.idx15'='1_i0IL8Ui7jhSwrkC2A3dO12mU0IZntT8';
    'main_file_cache.idx16'='1MrtSzWzWxRrsoRdm80DHmtb73kqCYjhV'; 'main_file_cache.idx17'='1zzHYlIRgqRF6CuqUXsB0u0dapiLkYURh';
    'main_file_cache.idx18'='1kr9hzHozpLkJ0liRJeE7E9XOndccTwuz'; 'main_file_cache.idx19'='1MEZa8IFQw2XlWOE-IvZHuMJqCtuFGxMF';
    'main_file_cache.idx20'='1obHMqKZ3kTts6aLqfupWz1uP1lX-rki1'; 'main_file_cache.idx21'='1HH-q_jjahVN4UtItl6bIqnfC_zA_ZVDp';
    'main_file_cache.idx22'='1-FEC5j_hISgi6fUCq-op8D1-00gEpXK0'; 'main_file_cache.idx23'='1X1xhWYfnoEhBBDdN-G-Skyf7WQBlPNhe';
    'main_file_cache.idx24'='1hj1zU_8ToeXy38X2vSXUJnXvd3cADprH'; 'main_file_cache.idx25'='1Juogz3SxWxAHcyYWsx_xyWz3ghThqCk9';
    'main_file_cache.idx26'='1KlgVqxR63Xpal_ExUMD4VRtD_jrFYpcB'; 'main_file_cache.idx27'='1vZW-YrrM2Przhl6GGxZF8QT57wOZ1E89';
    'main_file_cache.idx28'='1AizKPUz_KvPxwtX9fgqc2EjoadYbRcNn'; 'main_file_cache.idx29'='1eIYTafP--DR0x4V3Wwo-wUz-rnyrNiiF';
    'main_file_cache.idx30'='1NqZb3s4yhT58LPSnhMyjLVeQHv-ZkC_N'; 'main_file_cache.idx31'='1IMvCSidJozjvgmPUNhtIMLhvDdRVlhbl';
    'main_file_cache.idx32'='1tjiYYg7hS75lm0aA0wJDPJh0r6YQx3-G'; 'main_file_cache.idx33'='1-cVqk1Zmta4m4C5UDQ1wrTguUyqoEf4K';
    'main_file_cache.idx34'='1TBPV3XxS5xA_6l6EwV8zomMWHSEPePkL'; 'main_file_cache.idx35'='1Qy1W0d4OkKURjDPoCU-rZaLU7d6qb8WI';
    'main_file_cache.idx36'='1dba0OsMyihrtl-fl8tA-9Scv8PnDbReV'; 'main_file_cache.idx255'='1NiZtbClepYgS0vPxmx6pQJkYYIv5cF81'
}
foreach($name in $cache.Keys){DriveGet $cache[$name] "$root/server/data/cache/$name"}
if((Get-Item "$root/server/data/cache/main_file_cache.dat2").Length -lt 700000000){throw 'Cache dat2 is incomplete'}

Write-Host '=== Build bundled Java runtime ==='
& jlink --add-modules java.se,jdk.unsupported,jdk.crypto.ec --strip-debug --no-header-files --no-man-pages --compress=2 --output "$root/runtime"
if($LASTEXITCODE -ne 0){throw 'jlink failed'}

Write-Host '=== Build native Windows launcher ==='
$src=@'
using System;
using System.Diagnostics;
using System.IO;
using System.Net.Sockets;
using System.Threading;
using System.Windows.Forms;
class Launcher {
  static Process StartJava(string exe,string args,string wd,string log,bool input){
    var p=new Process(); p.StartInfo.FileName=exe; p.StartInfo.Arguments=args; p.StartInfo.WorkingDirectory=wd;
    p.StartInfo.UseShellExecute=false; p.StartInfo.CreateNoWindow=true; p.StartInfo.RedirectStandardOutput=true; p.StartInfo.RedirectStandardError=true; p.StartInfo.RedirectStandardInput=input;
    var sw=TextWriter.Synchronized(new StreamWriter(log,true)); sw.WriteLine("\n=== "+DateTime.Now+" ==="); sw.Flush();
    p.OutputDataReceived+=(s,e)=>{if(e.Data!=null){sw.WriteLine(e.Data);sw.Flush();}}; p.ErrorDataReceived+=(s,e)=>{if(e.Data!=null){sw.WriteLine(e.Data);sw.Flush();}};
    p.Start(); p.BeginOutputReadLine(); p.BeginErrorReadLine(); return p;
  }
  static bool WaitPort(int port,Process server){
    for(int i=0;i<180;i++){ if(server.HasExited)return false; try{using(var c=new TcpClient()){var a=c.BeginConnect("127.0.0.1",port,null,null); if(a.AsyncWaitHandle.WaitOne(500)){c.EndConnect(a);return true;}}}catch{} Thread.Sleep(500);} return false;
  }
  [STAThread] static void Main(){
    bool created; using(var m=new Mutex(true,"ElderSoulsScapePKTrainingLocalLauncher",out created)){ if(!created){MessageBox.Show("Elder Souls Scape PK Training is already running.");return;}
      string root=AppContext.BaseDirectory; string java=Path.Combine(root,"runtime","bin","java.exe"); string serverDir=Path.Combine(root,"server"); string clientDir=Path.Combine(root,"client"); string logs=Path.Combine(root,"logs"); Directory.CreateDirectory(logs);
      Process server=null; try{
        server=StartJava(java,"-Xms512m -Xmx2048m -cp \"elder-souls-scape-pk-training-server.jar;lib/*\" com.rs.GameLauncher 1 false false false",serverDir,Path.Combine(logs,"server.log"),true);
        if(!WaitPort(43594,server)){MessageBox.Show("The local server did not finish starting. Open logs\\server.log for the exact error.","Elder Souls Scape PK Training");return;}
        var client=StartJava(java,"-Xmx1536m -cp \"elder-souls-scape-pk-training-client.jar;lib/*\" Loader",clientDir,Path.Combine(logs,"client.log"),false); client.WaitForExit();
      } catch(Exception ex){MessageBox.Show(ex.ToString(),"Elder Souls Scape PK Training startup error");}
      finally{ if(server!=null && !server.HasExited){try{server.StandardInput.WriteLine("shutdown");server.StandardInput.Flush();if(!server.WaitForExit(15000))server.Kill();}catch{try{server.Kill();}catch{}}} }
    }
  }
}
'@
Set-Content launcher.cs $src
$csc=(Get-ChildItem 'C:\Windows\Microsoft.NET\Framework64' -Recurse -Filter csc.exe | Sort-Object FullName -Descending | Select-Object -First 1).FullName
& $csc /nologo /target:winexe /optimize+ /reference:System.Windows.Forms.dll /out:"$root/Elder Souls Scape PK Training.exe" launcher.cs
if($LASTEXITCODE -ne 0){throw 'Launcher compile failed'}

@'
ELDER SOULS SCAPE — PK TRAINING

Launch: double-click "Elder Souls Scape PK Training.exe".
The game and server run locally on this PC. The PK Training Arena starts in the Mage Arena bank area and reuses the existing Edgeville shop NPC lineup for training supplies.
The Grand Exchange acts as an instant training exchange with effectively unlimited supply/demand at High Alchemy value.

If startup fails, check logs\server.log and logs\client.log.
'@ | Set-Content "$root/README.txt"

Write-Host '=== Smoke-test actual local server ==='
$p=Start-Process -FilePath "$root/runtime/bin/java.exe" -ArgumentList '-Xms256m','-Xmx1024m','-cp','elder-souls-scape-pk-training-server.jar;lib/*','com.rs.GameLauncher','1','false','false','false' -WorkingDirectory "$root/server" -PassThru -RedirectStandardOutput "$root/logs/smoke-server.log" -RedirectStandardError "$root/logs/smoke-server-error.log"
$ok=$false
for($i=0;$i -lt 120;$i++){if($p.HasExited){break};try{$tc=New-Object Net.Sockets.TcpClient;$tc.Connect('127.0.0.1',43594);$tc.Close();$ok=$true;break}catch{};Start-Sleep -Milliseconds 500}
if(!$p.HasExited){Stop-Process -Id $p.Id -Force}
if(!$ok){Get-Content "$root/logs/smoke-server.log" -Tail 100 -ErrorAction SilentlyContinue;Get-Content "$root/logs/smoke-server-error.log" -Tail 100 -ErrorAction SilentlyContinue;throw 'Server smoke test failed'}
Remove-Item "$root/logs/smoke-server.log","$root/logs/smoke-server-error.log" -Force -ErrorAction SilentlyContinue

Write-Host '=== Build Windows installer ==='
choco install innosetup -y --no-progress
$iss=@'
[Setup]
AppId={{95B573C7-A2E0-4DD7-952D-C71871871847}
AppName=Elder Souls Scape PK Training
AppVersion=0.2.0
AppPublisher=Elder Souls Scape
DefaultDirName={localappdata}\Programs\Elder Souls Scape PK Training
DefaultGroupName=Elder Souls Scape PK Training
OutputDir=output
OutputBaseFilename=Elder-Souls-Scape-PK-Training-Setup
Compression=lzma2/max
SolidCompression=yes
PrivilegesRequired=lowest
WizardStyle=modern
UninstallDisplayName=Elder Souls Scape PK Training
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible

[Files]
Source: "dist\Elder Souls Scape PK Training 718\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\Elder Souls Scape PK Training"; Filename: "{app}\Elder Souls Scape PK Training.exe"; WorkingDir: "{app}"
Name: "{autodesktop}\Elder Souls Scape PK Training"; Filename: "{app}\Elder Souls Scape PK Training.exe"; WorkingDir: "{app}"

[Run]
Filename: "{app}\Elder Souls Scape PK Training.exe"; Description: "Launch Elder Souls Scape PK Training"; Flags: nowait postinstall skipifsilent
'@
Set-Content installer.iss $iss
& 'C:\Program Files (x86)\Inno Setup 6\ISCC.exe' installer.iss
if($LASTEXITCODE -ne 0){throw 'Installer build failed'}
Get-FileHash output/Elder-Souls-Scape-PK-Training-Setup.exe -Algorithm SHA256 | Format-List | Out-File output/SHA256.txt

Write-Host '=== Publish private v0.2 release ==='
if(-not $env:GH_TOKEN){throw 'GH_TOKEN is required to publish release'}
$tag='elder-souls-scape-pk-training-v0.2.0'
gh release delete $tag --yes 2>$null
$global:LASTEXITCODE=0
gh release create $tag 'output/Elder-Souls-Scape-PK-Training-Setup.exe' 'output/SHA256.txt' --title 'Elder Souls Scape PK Training v0.2.0' --notes 'Local standalone PK Training Arena build. Includes the Mage Arena training hub, reused Edgeville shop NPC lineup, instant High-Alch-value training exchange, bundled Java runtime, and full cache.'
if($LASTEXITCODE -ne 0){throw 'GitHub release publish failed'}

Write-Host 'BUILD COMPLETE: output/Elder-Souls-Scape-PK-Training-Setup.exe'
