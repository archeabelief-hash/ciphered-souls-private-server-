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
$s = $s.Replace('public static final String SERVER_NAME = "Matrix";', 'public static final String SERVER_NAME = "Elder Souls RPG Alpha";')
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
$c = [regex]::Replace($c, 'public static String local = //[\s\S]*?//"127\.0\.0\.1"; // local', 'public static String local = "127.0.0.1"; // local-only Elder Souls RPG Alpha', 1)
$c = $c.Replace('public static final Object ABSOLOUTE_CACHE_NAME_1 = "MATRIX";', 'public static final Object ABSOLOUTE_CACHE_NAME_1 = "ELDER_SOULS_RPG_ALPHA";')
$c = $c.Replace('public static final String ABSOLOUTE_CACHE_NAME_2 = "RSPS";', 'public static final String ABSOLOUTE_CACHE_NAME_2 = "718";')
$c = $c.Replace('public static final Object CACHE_NAME = "MATRIX";', 'public static final Object CACHE_NAME = "ELDER_SOULS_RPG_ALPHA";')
$c = $c.Replace('public static final String CACHE_SUB_NAME = "MATRIX";', 'public static final String CACHE_SUB_NAME = "718";')
Set-Content $cp $c -NoNewline

$loader = 'recovered/client/src/main/java/Loader.java'
$x = Get-Content $loader -Raw
$x = $x.Replace('Matrix RSPS', 'Elder Souls RPG Alpha')
$x = [regex]::Replace($x, '(?m)^\s*Discord\.init\(\);\s*$', '        // Discord integration disabled for local build.')
Set-Content $loader $x -NoNewline

$rl = 'recovered/client/src/main/java/net/runelite/client/RuneLite.java'
$r = Get-Content $rl -Raw
$r = $r.Replace('new File(System.getProperty("user.home"), "MATRIX")', 'new File(System.getProperty("user.home"), "ElderSoulsRPGAlpha")')
Set-Content $rl $r -NoNewline

Write-Host '=== Apply PK Training Arena gameplay patch ==='
./tools/apply-elder-souls-pk-training.ps1

Write-Host '=== Apply local controller gateway patch ==='
./tools/apply-elder-souls-agent-gateway.ps1

Write-Host '=== Normalize Elder Souls RPG Alpha branding and paths ==='
./tools/apply-elder-souls-rpg-alpha-branding.ps1

Write-Host '=== Verify no stale user-facing Matrix branding remains ==='
./tools/verify-elder-souls-rpg-alpha-branding.ps1

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
& jar --create --file build/elder-souls-rpg-alpha-server.jar --main-class com.rs.GameLauncher -C build/server-classes .
& jar --create --file build/elder-souls-rpg-alpha-client.jar --main-class Loader -C build/client-classes .
if(Test-Path recovered/server/src/main/resources){& jar --update --file build/elder-souls-rpg-alpha-server.jar -C recovered/server/src/main/resources .}
if(Test-Path recovered/client/src/main/resources){& jar --update --file build/elder-souls-rpg-alpha-client.jar -C recovered/client/src/main/resources .}

Write-Host '=== Assemble app and full cache ==='
$root='dist/Elder Souls RPG Alpha 718'
New-Item -ItemType Directory -Force "$root/server/data/cache","$root/server/lib","$root/client/lib","$root/logs","$root/agent" | Out-Null
Copy-Item build/elder-souls-rpg-alpha-server.jar "$root/server/"
Copy-Item build/elder-souls-rpg-alpha-client.jar "$root/client/"
Copy-Item recovered/server/data/* "$root/server/data/" -Recurse -Force
if(Test-Path "$root/server/data/cache"){Remove-Item "$root/server/data/cache" -Recurse -Force}
New-Item -ItemType Directory -Force "$root/server/data/cache" | Out-Null
Copy-Item recovered/server/data/lib/* "$root/server/lib/" -Force
Copy-Item deps/*.jar "$root/server/lib/" -Force
Copy-Item recovered/client/lib/* "$root/client/lib/" -Force
Copy-Item deps/slf4j-api-1.7.7.jar "$root/client/lib/" -Force
Copy-Item deps/jsr305-3.0.2.jar "$root/client/lib/" -Force
Copy-Item agent/* "$root/agent/" -Recurse -Force

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
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Net;
using System.Net.Sockets;
using System.Security.Cryptography;
using System.Threading;
using System.Web.Script.Serialization;
using System.Windows.Forms;

class GitHubAsset {
  public string name { get; set; }
  public string browser_download_url { get; set; }
  public string digest { get; set; }
}

class GitHubRelease {
  public string tag_name { get; set; }
  public bool draft { get; set; }
  public bool prerelease { get; set; }
  public List<GitHubAsset> assets { get; set; }
}

class UpdateForm : Form {
  readonly string url;
  readonly string target;
  readonly ProgressBar bar;
  readonly Label label;
  WebClient client;

  public UpdateForm(string url,string target,string version){
    this.url=url; this.target=target;
    Text="Elder Souls RPG Alpha Updater";
    Width=480; Height=150;
    StartPosition=FormStartPosition.CenterScreen;
    FormBorderStyle=FormBorderStyle.FixedDialog;
    MaximizeBox=false; MinimizeBox=false; ControlBox=false;
    label=new Label(){Left=20,Top=18,Width=425,Height=32,Text="Downloading Elder Souls RPG Alpha "+version+"..."};
    bar=new ProgressBar(){Left=20,Top=58,Width=425,Height=24,Minimum=0,Maximum=100};
    Controls.Add(label); Controls.Add(bar);
    Shown += (s,e)=>BeginDownload();
  }

  void BeginDownload(){
    client=new WebClient();
    client.Headers[HttpRequestHeader.UserAgent]="ElderSoulsRPGAlpha-Updater";
    client.DownloadProgressChanged += (s,e)=>{
      if(IsDisposed)return;
      bar.Value=Math.Max(0,Math.Min(100,e.ProgressPercentage));
      label.Text="Downloading update... "+e.ProgressPercentage+"%";
    };
    client.DownloadFileCompleted += (s,e)=>{
      if(IsDisposed)return;
      if(e.Error!=null){
        MessageBox.Show("The update could not be downloaded. The installed version will start instead.\n\n"+e.Error.Message,"Elder Souls RPG Alpha Updater");
        DialogResult=DialogResult.Cancel;
      } else if(e.Cancelled) {
        DialogResult=DialogResult.Cancel;
      } else {
        bar.Value=100;
        label.Text="Update downloaded.";
        DialogResult=DialogResult.OK;
      }
      Close();
    };
    client.DownloadFileAsync(new Uri(url),target);
  }

  protected override void Dispose(bool disposing){
    if(disposing && client!=null) client.Dispose();
    base.Dispose(disposing);
  }
}

class Launcher {
  const string CurrentVersion="0.1.0";
  const string ReleasePrefix="elder-souls-rpg-alpha-v";
  const string SetupAssetName="Elder-Souls-RPG-Alpha-Setup.exe";
  const string ReleasesApi="https://api.github.com/repos/archeabelief-hash/ciphered-souls-private-server-/releases?per_page=30";

  static bool TryParseReleaseVersion(string tag,out Version version){
    version=null;
    if(String.IsNullOrWhiteSpace(tag) || !tag.StartsWith(ReleasePrefix,StringComparison.OrdinalIgnoreCase)) return false;
    var raw=tag.Substring(ReleasePrefix.Length);
    return Version.TryParse(raw,out version);
  }

  static string Sha256(string file){
    using(var sha=SHA256.Create())
    using(var stream=File.OpenRead(file)){
      var hash=sha.ComputeHash(stream);
      return BitConverter.ToString(hash).Replace("-","").ToLowerInvariant();
    }
  }

  static bool VerifyDigest(string file,string digest){
    if(String.IsNullOrWhiteSpace(digest) || !digest.StartsWith("sha256:",StringComparison.OrdinalIgnoreCase)) return true;
    var expected=digest.Substring(7).Trim().ToLowerInvariant();
    return String.Equals(Sha256(file),expected,StringComparison.OrdinalIgnoreCase);
  }

  static bool TryAutoUpdate(){
    try{
      ServicePointManager.SecurityProtocol=SecurityProtocolType.Tls12;

      string json;
      using(var wc=new WebClient()){
        wc.Headers[HttpRequestHeader.UserAgent]="ElderSoulsRPGAlpha-Updater";
        wc.Headers[HttpRequestHeader.Accept]="application/vnd.github+json";
        json=wc.DownloadString(ReleasesApi);
      }

      var releases=new JavaScriptSerializer().Deserialize<List<GitHubRelease>>(json);
      if(releases==null)return false;

      Version current;
      if(!Version.TryParse(CurrentVersion,out current))return false;

      GitHubRelease best=null;
      Version bestVersion=current;

      foreach(var release in releases){
        if(release==null || release.draft)continue;
        Version candidate;
        if(!TryParseReleaseVersion(release.tag_name,out candidate))continue;
        if(candidate>bestVersion){
          best=release;
          bestVersion=candidate;
        }
      }

      if(best==null || best.assets==null)return false;

      GitHubAsset setup=null;
      foreach(var asset in best.assets){
        if(asset!=null && String.Equals(asset.name,SetupAssetName,StringComparison.OrdinalIgnoreCase)){
          setup=asset;
          break;
        }
      }
      if(setup==null || String.IsNullOrWhiteSpace(setup.browser_download_url))return false;

      var temp=Path.Combine(Path.GetTempPath(),"Elder-Souls-RPG-Alpha-"+bestVersion+"-Setup.exe");
      try{if(File.Exists(temp))File.Delete(temp);}catch{}

      using(var form=new UpdateForm(setup.browser_download_url,temp,bestVersion.ToString())){
        if(form.ShowDialog()!=DialogResult.OK || !File.Exists(temp))return false;
      }

      if(!VerifyDigest(temp,setup.digest)){
        try{File.Delete(temp);}catch{}
        MessageBox.Show("The downloaded update failed its SHA-256 verification. The installed version will start instead.","Elder Souls RPG Alpha Updater");
        return false;
      }

      var restart=Path.Combine(Path.GetTempPath(),"elder-souls-rpg-alpha-update.cmd");
      var gameExe=Path.Combine(AppContext.BaseDirectory,"Elder Souls RPG Alpha.exe");
      var cmd=
        "@echo off\r\n"+
        "timeout /t 2 /nobreak >nul\r\n"+
        "start /wait \"\" \""+temp+"\" /VERYSILENT /SUPPRESSMSGBOXES /NORESTART /CLOSEAPPLICATIONS\r\n"+
        "start \"\" \""+gameExe+"\"\r\n"+
        "del /q \""+temp+"\" >nul 2>nul\r\n"+
        "del /q \"%~f0\" >nul 2>nul\r\n";
      File.WriteAllText(restart,cmd);
      Process.Start(new ProcessStartInfo(){FileName=restart,UseShellExecute=true,WindowStyle=ProcessWindowStyle.Hidden});
      return true;
    }catch{
      return false;
    }
  }

  static Process StartJava(string exe,string args,string wd,string log,bool input){
    var p=new Process(); p.StartInfo.FileName=exe; p.StartInfo.Arguments=args; p.StartInfo.WorkingDirectory=wd;
    p.StartInfo.UseShellExecute=false; p.StartInfo.CreateNoWindow=true; p.StartInfo.RedirectStandardOutput=true; p.StartInfo.RedirectStandardError=true; p.StartInfo.RedirectStandardInput=input;
    var sw=TextWriter.Synchronized(new StreamWriter(log,true)); sw.WriteLine("\n=== "+DateTime.Now+" ==="); sw.Flush();
    p.OutputDataReceived+=(s,e)=>{if(e.Data!=null){sw.WriteLine(e.Data);sw.Flush();}}; p.ErrorDataReceived+=(s,e)=>{if(e.Data!=null){sw.WriteLine(e.Data);sw.Flush();}};
    p.Start(); p.BeginOutputReadLine(); p.BeginErrorReadLine(); return p;
  }

  static bool WaitPort(int port,Process server){
    for(int i=0;i<180;i++){
      if(server.HasExited)return false;
      try{
        using(var c=new TcpClient()){
          var a=c.BeginConnect("127.0.0.1",port,null,null);
          if(a.AsyncWaitHandle.WaitOne(500)){c.EndConnect(a);return true;}
        }
      }catch{}
      Thread.Sleep(500);
    }
    return false;
  }

  [STAThread] static void Main(){
    Application.EnableVisualStyles();
    Application.SetCompatibleTextRenderingDefault(false);

    bool created;
    using(var m=new Mutex(true,"ElderSoulsRPGAlphaLocalLauncher",out created)){
      if(!created){MessageBox.Show("Elder Souls RPG Alpha is already running.");return;}

      if(TryAutoUpdate())return;

      string root=AppContext.BaseDirectory;
      string java=Path.Combine(root,"runtime","bin","java.exe");
      string serverDir=Path.Combine(root,"server");
      string clientDir=Path.Combine(root,"client");
      string logs=Path.Combine(root,"logs");
      Directory.CreateDirectory(logs);

      Process server=null;
      try{
        server=StartJava(java,"-Xms512m -Xmx2048m -cp \"elder-souls-rpg-alpha-server.jar;lib/*\" com.rs.GameLauncher 1 false false false",serverDir,Path.Combine(logs,"server.log"),true);
        if(!WaitPort(43594,server)){
          MessageBox.Show("The local server did not finish starting. Open logs\\server.log for the exact error.","Elder Souls RPG Alpha");
          return;
        }
        var client=StartJava(java,"-Xmx1536m -cp \"elder-souls-rpg-alpha-client.jar;lib/*\" Loader",clientDir,Path.Combine(logs,"client.log"),false);
        client.WaitForExit();
      }catch(Exception ex){
        MessageBox.Show(ex.ToString(),"Elder Souls RPG Alpha startup error");
      }finally{
        if(server!=null && !server.HasExited){
          try{
            server.StandardInput.WriteLine("shutdown");
            server.StandardInput.Flush();
            if(!server.WaitForExit(15000))server.Kill();
          }catch{
            try{server.Kill();}catch{}
          }
        }
      }
    }
  }
}
'@
Set-Content launcher.cs $src
$csc=(Get-ChildItem 'C:\Windows\Microsoft.NET\Framework64' -Recurse -Filter csc.exe | Sort-Object FullName -Descending | Select-Object -First 1).FullName
& $csc /nologo /target:winexe /optimize+ /reference:System.Windows.Forms.dll /reference:System.Web.Extensions.dll /out:"$root/Elder Souls RPG Alpha.exe" launcher.cs
if($LASTEXITCODE -ne 0){throw 'Launcher compile failed'}

@'
ELDER SOULS SCAPE — PK TRAINING

Launch: double-click "Elder Souls RPG Alpha.exe".
The game and server run locally on this PC. The PK Training Arena starts in the Mage Arena bank area and reuses the existing Edgeville shop NPC lineup for training supplies.
The Grand Exchange acts as an instant training exchange with effectively unlimited supply/demand at High Alchemy value.\n\nDUAT GUARDIAN PROTOTYPE\nCustom IDs 29990-29997 are level-1 test equipment. Every account receives one set in inventory and one backup set in bank. The Duat Khopesh is intentionally one-hit lethal in this engineering build.

If startup fails, check logs\server.log and logs\client.log.
'@ | Set-Content "$root/README.txt"

Write-Host '=== Smoke-test actual local server ==='
$p=Start-Process -FilePath "$root/runtime/bin/java.exe" -ArgumentList '-Xms256m','-Xmx1024m','-cp','elder-souls-rpg-alpha-server.jar;lib/*','com.rs.GameLauncher','1','false','false','false' -WorkingDirectory "$root/server" -PassThru -RedirectStandardOutput "$root/logs/smoke-server.log" -RedirectStandardError "$root/logs/smoke-server-error.log"
$ok=$false
for($i=0;$i -lt 120;$i++){if($p.HasExited){break};try{$tc=New-Object Net.Sockets.TcpClient;$tc.Connect('127.0.0.1',43594);$tc.Close();$ok=$true;break}catch{};Start-Sleep -Milliseconds 500}
$gatewayOk=$false
if($ok){
    for($i=0;$i -lt 60;$i++){
        if($p.HasExited){break}
        try{
            $tc=New-Object Net.Sockets.TcpClient
            $tc.Connect('127.0.0.1',7780)
            $tc.Close()
            $gatewayOk=$true
            break
        }catch{}
        Start-Sleep -Milliseconds 250
    }
}
if(!$p.HasExited){Stop-Process -Id $p.Id -Force}
if(!$ok){Get-Content "$root/logs/smoke-server.log" -Tail 100 -ErrorAction SilentlyContinue;Get-Content "$root/logs/smoke-server-error.log" -Tail 100 -ErrorAction SilentlyContinue;throw 'Server smoke test failed'}
if(!$gatewayOk){Get-Content "$root/logs/smoke-server.log" -Tail 100 -ErrorAction SilentlyContinue;Get-Content "$root/logs/smoke-server-error.log" -Tail 100 -ErrorAction SilentlyContinue;throw 'Local controller gateway smoke test failed on port 7780'}
Remove-Item "$root/logs/smoke-server.log","$root/logs/smoke-server-error.log" -Force -ErrorAction SilentlyContinue

Write-Host '=== Build Windows installer ==='
choco install innosetup -y --no-progress
$iss=@'
[Setup]
AppId={{C2F21E7A-1D13-4B9A-AE71-9A7180000001}
AppName=Elder Souls RPG Alpha
AppVersion=0.1.0
AppPublisher=Elder Souls RPG
DefaultDirName={localappdata}\Programs\Elder Souls RPG Alpha
DefaultGroupName=Elder Souls RPG Alpha
OutputDir=output
OutputBaseFilename=Elder-Souls-RPG-Alpha-Setup
Compression=lzma2/max
SolidCompression=yes
PrivilegesRequired=lowest
WizardStyle=modern
UninstallDisplayName=Elder Souls RPG Alpha
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible

[Files]
Source: "dist\Elder Souls RPG Alpha 718\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\Elder Souls RPG Alpha"; Filename: "{app}\Elder Souls RPG Alpha.exe"; WorkingDir: "{app}"
Name: "{autodesktop}\Elder Souls RPG Alpha"; Filename: "{app}\Elder Souls RPG Alpha.exe"; WorkingDir: "{app}"

[Run]
Filename: "{app}\Elder Souls RPG Alpha.exe"; Description: "Launch Elder Souls RPG Alpha"; Flags: nowait postinstall skipifsilent
'@
Set-Content installer.iss $iss
& 'C:\Program Files (x86)\Inno Setup 6\ISCC.exe' installer.iss
if($LASTEXITCODE -ne 0){throw 'Installer build failed'}
Get-FileHash output/Elder-Souls-RPG-Alpha-Setup.exe -Algorithm SHA256 | Format-List | Out-File output/SHA256.txt

Write-Host '=== Publish Elder Souls RPG Alpha 0.1.0 ==='
if(-not $env:GH_TOKEN){throw 'GH_TOKEN is required to publish release'}
$tag='elder-souls-rpg-alpha-v0.1.0'
gh release delete $tag --yes 2>$null
$global:LASTEXITCODE=0
gh release create $tag 'output/Elder-Souls-RPG-Alpha-Setup.exe' 'output/SHA256.txt' --title 'Elder Souls RPG Alpha 0.1.0' --notes 'Elder Souls RPG Alpha begins here. Self-contained local 718 client/server build with normalized Elder Souls branding and filesystem paths, bundled runtime/cache, training hub, custom prototype equipment, and local controller gateway.'
if($LASTEXITCODE -ne 0){throw 'GitHub release publish failed'}

Write-Host 'BUILD COMPLETE: output/Elder-Souls-RPG-Alpha-Setup.exe'
