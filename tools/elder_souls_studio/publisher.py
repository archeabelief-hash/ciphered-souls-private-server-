from __future__ import annotations
import json, os, shutil, struct, subprocess, tempfile, time, sys
from pathlib import Path

ROOT = Path(getattr(sys, "_MEIPASS", Path(__file__).resolve().parent))
USER_HOME = Path(os.environ.get("LOCALAPPDATA", Path.home())) / "ElderSoulsContentStudio"
WORKSPACE = USER_HOME / "workspace"
BACKUPS = WORKSPACE / "backups"
EXTRACTED = WORKSPACE / "extracted"
CACHE_TOOLS = ROOT / "cache_tools"

class Buf:
    def __init__(self): self.b = bytearray()
    def u8(self,n): self.b.append(int(n)&0xff)
    def u16(self,n): self.b += struct.pack(">H", int(n)&0xffff)
    def i32(self,n): self.b += struct.pack(">i", int(n))
    def string(self,s): self.b += str(s).encode("cp1252", errors="replace") + b"\x00"
    def bigsmart(self,n):
        n=int(n)
        if n >= 32767: self.i32(n - 2147483648)
        else: self.u16(n if n >= 0 else 32767)
    def done(self):
        self.u8(0)
        return bytes(self.b)

def _ints(v):
    if v is None: return []
    if isinstance(v,list): return [int(x) for x in v]
    if isinstance(v,str): return [int(x.strip()) for x in v.split(",") if x.strip()]
    return [int(v)]

def encode_item(a):
    g=a.get("game_data",{}); b=Buf()
    model_id=int(g.get("model_id",g.get("modelId",0)))
    if model_id: b.u8(1); b.bigsmart(model_id)
    if a.get("name"): b.u8(2); b.string(a["name"])
    for op,key in [(4,"model_zoom"),(5,"rotation_x"),(6,"rotation_y"),(7,"offset_x"),(8,"offset_y")]:
        if key in g: b.u8(op); b.u16(int(g[key]))
    if g.get("stackable") is True: b.u8(11)
    if "value" in g: b.u8(12); b.i32(g["value"])
    if "equip_slot" in g: b.u8(13); b.u8(g["equip_slot"])
    if "equip_type" in g: b.u8(14); b.u8(g["equip_type"])
    if g.get("members") is True: b.u8(16)
    for op,key in [(23,"male_model_1"),(24,"male_model_2"),(25,"female_model_1"),(26,"female_model_2"),(78,"male_model_3"),(79,"female_model_3")]:
        if key in g: b.u8(op); b.bigsmart(g[key])
    opts=g.get("inventory_options")
    if opts is not None:
        if isinstance(opts,str): opts=[x.strip() for x in opts.split(",")]
        for i,opt in enumerate(opts[:5]):
            b.u8(35+i); b.string(opt or "Hidden")
    frm,to=_ints(g.get("recolor_from")),_ints(g.get("recolor_to"))
    if frm and len(frm)==len(to):
        b.u8(40); b.u8(len(frm))
        for x,y in zip(frm,to): b.u16(x); b.u16(y)
    return b.done()

def encode_npc(a):
    g=a.get("game_data",{}); b=Buf()
    models=_ints(g.get("model_ids",g.get("model_id")))
    if models:
        b.u8(1); b.u8(len(models))
        for x in models: b.bigsmart(x)
    if a.get("name"): b.u8(2); b.string(a["name"])
    if "size" in g: b.u8(12); b.u8(g["size"])
    opts=g.get("options")
    if opts is not None:
        if isinstance(opts,str): opts=[x.strip() for x in opts.split(",")]
        for i,opt in enumerate(opts[:5]):
            b.u8(30+i); b.string(opt or "Hidden")
    if "combat_level" in g: b.u8(95); b.u16(g["combat_level"])
    if g.get("visible_on_map") is False: b.u8(93)
    if "render_emote" in g: b.u8(127); b.u16(g["render_emote"])
    frm,to=_ints(g.get("recolor_from")),_ints(g.get("recolor_to"))
    if frm and len(frm)==len(to):
        b.u8(40); b.u8(len(frm))
        for x,y in zip(frm,to): b.u16(x); b.u16(y)
    return b.done()

def encode_object(a):
    g=a.get("game_data",{}); b=Buf()
    models=_ints(g.get("model_ids",g.get("model_id")))
    if models:
        b.u8(5); b.u8(len(models))
        for x in models: b.bigsmart(x)
    if a.get("name"): b.u8(2); b.string(a["name"])
    if "size_x" in g: b.u8(14); b.u8(g["size_x"])
    if "size_y" in g: b.u8(15); b.u8(g["size_y"])
    opts=g.get("options")
    if opts is not None:
        if isinstance(opts,str): opts=[x.strip() for x in opts.split(",")]
        for i,opt in enumerate(opts[:5]):
            b.u8(30+i); b.string(opt or "Hidden")
    if "animation_id" in g: b.u8(24); b.bigsmart(g["animation_id"])
    if g.get("no_clip") is True: b.u8(17)
    frm,to=_ints(g.get("recolor_from")),_ints(g.get("recolor_to"))
    if frm and len(frm)==len(to):
        b.u8(40); b.u8(len(frm))
        for x,y in zip(frm,to): b.u16(x); b.u16(y)
    return b.done()

def coords(asset_type, asset_id):
    i=int(asset_id)
    if asset_type=="item": return 19, i>>8, i&0xff
    if asset_type=="npc": return 18, i>>7, i&0x7f
    if asset_type=="object": return 16, i>>8, i&0xff
    if asset_type=="animation": return 20, i>>7, i&0x7f
    if asset_type=="interface": return 3, i, 0
    if asset_type=="model": return 7, i, 0
    raise ValueError("Unsupported direct-cache asset type: "+asset_type)

def find_java(settings):
    for p in [settings.get("java_path",""), ROOT/"runtime"/"jre8"/"bin"/"java.exe", ROOT.parent.parent/"launcher"/"runtime"/"jre8"/"bin"/"java.exe", shutil.which("java") or ""]:
        if p and Path(p).exists(): return str(p)
    raise FileNotFoundError("Java was not found. Configure java_path.")

def find_helper(settings):
    for p in [settings.get("cache_helper_classpath",""), CACHE_TOOLS/"bin"]:
        if p and Path(p).exists(): return str(p)
    raise FileNotFoundError("Cache helper is not compiled. Run cache_tools/build_cache_tools.bat.")

def find_filestore(settings):
    for p in [settings.get("filestore_jar",""),
              ROOT/"runtime"/"FileStore.jar", ROOT.parent.parent/"launcher"/"runtime"/"client"/"libs"/"FileStore-1.0.0.jar",
              ROOT.parent.parent/"launcher"/"runtime"/"server"/"data"/"mavenDependencies"/"FileStore.jar",
              CACHE_TOOLS/"FileStore.jar"]:
        if p and Path(p).exists(): return str(p)
    raise FileNotFoundError("FileStore.jar was not found.")

def cache_dir(settings):
    p=Path(settings.get("cache_dir",""))
    if not p.exists() or not (p/"main_file_cache.dat2").exists():
        raise FileNotFoundError("Configure cache_dir to the folder containing main_file_cache.dat2.")
    return p

def helper(settings,*args):
    cp=os.pathsep.join([find_helper(settings),find_filestore(settings)])
    cmd=[find_java(settings),"-cp",cp,"eldersouls.cache.CacheInject",*map(str,args)]
    p=subprocess.run(cmd,capture_output=True,text=True)
    if p.returncode:
        raise RuntimeError((p.stderr or p.stdout).strip())
    return (p.stdout or "").strip()

def read_cache(settings,index,archive,file_id):
    with tempfile.NamedTemporaryFile(delete=False,suffix=".bin") as tmp:
        out=tmp.name
    try:
        helper(settings,"read",cache_dir(settings),index,archive,file_id,out)
        return Path(out).read_bytes()
    finally:
        try: os.unlink(out)
        except OSError: pass

def put_cache(settings,index,archive,file_id,data):
    with tempfile.NamedTemporaryFile(delete=False,suffix=".bin") as tmp:
        tmp.write(data); src=tmp.name
    try:
        return helper(settings,"put",cache_dir(settings),index,archive,file_id,src)
    finally:
        try: os.unlink(src)
        except OSError: pass

def backup_target(asset,settings):
    index,archive,file_id=coords(asset["asset_type"],asset["asset_id"])
    try: raw=read_cache(settings,index,archive,file_id)
    except Exception: return None
    BACKUPS.mkdir(parents=True,exist_ok=True)
    stamp=time.strftime("%Y%m%d-%H%M%S")
    p=BACKUPS/f'{asset["asset_type"]}_{asset["asset_id"]}_{stamp}.bin'
    p.write_bytes(raw)
    meta=p.with_suffix(".json")
    meta.write_text(json.dumps({"index":index,"archive":archive,"file":file_id,"asset_type":asset["asset_type"],"asset_id":asset["asset_id"]},indent=2))
    return p

def latest_backup(asset):
    if not BACKUPS.exists(): return None
    files=sorted(BACKUPS.glob(f'{asset["asset_type"]}_{asset["asset_id"]}_*.bin'))
    return files[-1] if files else None

def restore_latest(asset,settings):
    p=latest_backup(asset)
    if not p: raise FileNotFoundError("No backup exists for this asset.")
    meta=json.loads(p.with_suffix(".json").read_text())
    return put_cache(settings,meta["index"],meta["archive"],meta["file"],p.read_bytes())

def clone_base_bytes(asset,settings):
    base=asset.get("game_data",{}).get("base_id")
    if base is None: return None
    index,archive,file_id=coords(asset["asset_type"],int(base))
    return read_cache(settings,index,archive,file_id)

def target_data(asset,settings):
    t=asset["asset_type"]
    if t in ("model","animation","interface","raw_cache"):
        src=Path(asset.get("source_file",""))
        if not src.exists(): raise FileNotFoundError("Model source_file does not exist.")
        if t=="model" and src.suffix.lower() not in (".dat",".ob2"): raise ValueError("Export the model as .dat/.ob2 first.")
        return src.read_bytes()
    enc={"item":encode_item,"npc":encode_npc,"object":encode_object}.get(t)
    if not enc: raise ValueError("Direct publishing is implemented for model, item, npc and object.")
    patch=enc(asset)
    base=clone_base_bytes(asset,settings)
    if base:
        while base.endswith(b"\x00"): base=base[:-1]
        return base + patch
    return patch

def publish(asset,settings):
    if asset["asset_type"]=="raw_cache":
        g=asset.get("game_data",{})
        index=int(g["index"]); archive=int(g["archive"]); file_id=int(g.get("file",0))
        try:
            raw=read_cache(settings,index,archive,file_id)
            BACKUPS.mkdir(parents=True,exist_ok=True)
            stamp=time.strftime("%Y%m%d-%H%M%S")
            (BACKUPS/f'raw_{index}_{archive}_{file_id}_{stamp}.bin').write_bytes(raw)
        except Exception:
            pass
        return put_cache(settings,index,archive,file_id,target_data(asset,settings))
    index,archive,file_id=coords(asset["asset_type"],asset["asset_id"])
    backup_target(asset,settings)
    return put_cache(settings,index,archive,file_id,target_data(asset,settings))

def exact_clone(asset_type,source_id,target_id,settings):
    index,sa,sf=coords(asset_type,source_id)
    _,da,df=coords(asset_type,target_id)
    return helper(settings,"clone",cache_dir(settings),index,sa,sf,da,df)

def next_cache_id(asset_type,settings):
    index,_,_=coords(asset_type,0)
    out=helper(settings,"last",cache_dir(settings),index).strip().splitlines()[-1]
    archive,file_id=[int(x) for x in out.split(",")]
    if asset_type=="item": return archive*256+file_id+1
    if asset_type in ("npc","animation"): return archive*128+file_id+1
    if asset_type=="object": return archive*256+file_id+1
    if asset_type in ("model","interface"): return archive+1
    raise ValueError(asset_type)

def extract_model(model_id,settings):
    EXTRACTED.mkdir(parents=True,exist_ok=True)
    index,archive,file_id=coords("model",model_id)
    data=read_cache(settings,index,archive,file_id)
    p=EXTRACTED/f"{model_id}.ob2"
    p.write_bytes(data)
    return p
