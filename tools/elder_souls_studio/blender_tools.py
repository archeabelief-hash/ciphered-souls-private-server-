from __future__ import annotations
import os, shutil, subprocess, sys, tempfile, urllib.request, zipfile
from pathlib import Path

ROOT=Path(getattr(sys, "_MEIPASS", Path(__file__).resolve().parent))
USER_HOME=Path(os.environ.get("LOCALAPPDATA", Path.home()))/"ElderSoulsContentStudio"
THIRD=USER_HOME/"third_party"
OB2=THIRD/"ob2blender"

def find_blender(settings=None):
    settings=settings or {}
    p=settings.get("blender_path","")
    if p and Path(p).exists(): return Path(p)
    hit=shutil.which("blender")
    if hit: return Path(hit)
    guesses=[
        Path(r"C:\Program Files\Blender Foundation\Blender 4.5\blender.exe"),
        Path(r"C:\Program Files\Blender Foundation\Blender 4.4\blender.exe"),
        Path(r"C:\Program Files\Blender Foundation\Blender 4.3\blender.exe"),
    ]
    for g in guesses:
        if g.exists(): return g
    raise FileNotFoundError("Blender 4.5+ was not found.")

def ensure_ob2blender(settings=None):
    blender=find_blender(settings)
    if not OB2.exists():
        THIRD.mkdir(parents=True, exist_ok=True)
        url="https://github.com/stone-temple-pilot/ob2blender/archive/refs/heads/main.zip"
        with tempfile.TemporaryDirectory() as td:
            z=Path(td)/"ob2blender.zip"
            urllib.request.urlretrieve(url,z)
            with zipfile.ZipFile(z,"r") as arc:
                arc.extractall(td)
            src=next(Path(td).glob("ob2blender-*"))
            shutil.copytree(src,OB2)
    appdata=Path(os.environ.get("APPDATA",Path.home()))
    addon_root=appdata/"Blender Foundation"/"Blender"/"4.5"/"scripts"/"addons"
    addon_root.mkdir(parents=True,exist_ok=True)
    dest=addon_root/"ob2blender"
    if dest.exists(): shutil.rmtree(dest)
    shutil.copytree(OB2,dest,ignore=shutil.ignore_patterns(".git"))
    expr="import bpy; bpy.ops.preferences.addon_enable(module='ob2blender'); bpy.ops.wm.save_userpref()"
    subprocess.check_call([str(blender),"--background","--python-expr",expr])
    return dest

def open_model(path,settings=None):
    blender=find_blender(settings)
    path=Path(path).resolve()
    if path.suffix.lower()==".blend":
        subprocess.Popen([str(blender),str(path)])
        return
    ensure_ob2blender(settings)
    expr="import bpy; bpy.ops.import.model(filepath=r'''%s''')" % str(path)
    subprocess.Popen([str(blender),"--python-expr",expr])
