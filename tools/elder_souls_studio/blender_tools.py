from __future__ import annotations
import os, shutil, subprocess, sys, tempfile, urllib.request, zipfile, json
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
    version_folder=_blender_version_folder(blender)
    addon_root=appdata/"Blender Foundation"/"Blender"/version_folder/"scripts"/"addons"
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


def _blender_version_folder(blender):
    try:
        expr = "import bpy; print('ELS_BLENDER_VERSION=%d.%d' % (bpy.app.version[0], bpy.app.version[1]))"
        p = subprocess.run([str(blender), "--background", "--python-expr", expr], capture_output=True, text=True, timeout=45)
        for line in (p.stdout or "").splitlines():
            if line.startswith("ELS_BLENDER_VERSION="):
                return line.split("=", 1)[1].strip()
    except Exception:
        pass
    return "4.5"

def render_model_preview(path, output_path, settings=None, recolor_from=None, recolor_to=None, size=360):
    blender = find_blender(settings)
    ensure_ob2blender(settings)
    model_path = Path(path).resolve()
    output_path = Path(output_path).resolve()
    output_path.parent.mkdir(parents=True, exist_ok=True)

    recolor_from = [int(x) for x in (recolor_from or [])]
    recolor_to = [int(x) for x in (recolor_to or [])]
    mapping = dict(zip(recolor_from, recolor_to))

    script = r'''
import bpy, colorsys, json, math, sys
from mathutils import Vector

MODEL = __MODEL__
OUTPUT = __OUTPUT__
SIZE = __SIZE__
RECOLORS = __RECOLORS__

def rgb_to_hsl16(rgb):
    r,g,b = rgb[0], rgb[1], rgb[2]
    h,l,s = colorsys.rgb_to_hls(r,g,b)
    hue=max(0,min(63,int(round(h*63))))
    sat=max(0,min(7,int(round(s*7))))
    light=max(0,min(127,int(round(l*127))))
    return (hue<<10)|(sat<<7)|light

def hsl16_to_rgb(v):
    v=int(v)&0xffff
    h=((v>>10)&63)/63.0
    s=((v>>7)&7)/7.0
    l=(v&127)/127.0
    return colorsys.hls_to_rgb(h,l,s)

bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)

bpy.ops.import.model(filepath=MODEL)
objects=[o for o in bpy.context.scene.objects if o.type=='MESH']
if not objects:
    raise RuntimeError('No mesh was imported from model.')

if RECOLORS:
    for mat in bpy.data.materials:
        try:
            current=rgb_to_hsl16(mat.diffuse_color[:3])
            if str(current) in RECOLORS:
                rgb=hsl16_to_rgb(int(RECOLORS[str(current)]))
                mat.diffuse_color=(rgb[0],rgb[1],rgb[2],1.0)
        except Exception:
            pass

corners=[]
for obj in objects:
    for corner in obj.bound_box:
        corners.append(obj.matrix_world @ Vector(corner))
mins=Vector((min(p.x for p in corners),min(p.y for p in corners),min(p.z for p in corners)))
maxs=Vector((max(p.x for p in corners),max(p.y for p in corners),max(p.z for p in corners)))
center=(mins+maxs)*0.5
extent=max(maxs.x-mins.x,maxs.y-mins.y,maxs.z-mins.z)
if extent <= 0:
    extent=1.0

root=bpy.data.objects.new('ELS_PREVIEW_ROOT',None)
bpy.context.collection.objects.link(root)
for obj in objects:
    obj.parent=root
root.location=-center
scale=3.0/extent
root.scale=(scale,scale,scale)
root.rotation_euler[2]=math.radians(18)

bpy.ops.object.camera_add(location=(4.4,-6.6,3.4))
camera=bpy.context.object
bpy.context.scene.camera=camera
direction=Vector((0,0,0))-camera.location
camera.rotation_euler=direction.to_track_quat('-Z','Y').to_euler()
camera.data.lens=58

scene=bpy.context.scene
scene.render.engine='BLENDER_WORKBENCH'
scene.display.shading.light='STUDIO'
scene.display.shading.color_type='MATERIAL'
scene.display.shading.show_shadows=True
scene.display.shading.show_cavity=True
scene.display.shading.cavity_type='WORLD'
scene.display.shading.show_specular_highlight=True
scene.display.shading.background_type='WORLD'
scene.world.color=(0.025,0.028,0.035)
scene.render.resolution_x=SIZE
scene.render.resolution_y=SIZE
scene.render.resolution_percentage=100
scene.render.image_settings.file_format='PNG'
scene.render.film_transparent=False
scene.render.filepath=OUTPUT
bpy.ops.render.render(write_still=True)
'''
    script = script.replace("__MODEL__", json.dumps(str(model_path)))
    script = script.replace("__OUTPUT__", json.dumps(str(output_path)))
    script = script.replace("__SIZE__", str(int(size)))
    script = script.replace("__RECOLORS__", json.dumps({str(k): int(v) for k,v in mapping.items()}))

    with tempfile.NamedTemporaryFile("w", delete=False, suffix=".py", encoding="utf-8") as tmp:
        tmp.write(script)
        script_path = tmp.name

    try:
        p = subprocess.run(
            [str(blender), "--background", "--python", script_path],
            capture_output=True,
            text=True,
            timeout=180,
        )
        if p.returncode != 0 or not output_path.exists():
            raise RuntimeError((p.stderr or p.stdout or "Blender preview render failed.").strip()[-5000:])
        return output_path
    finally:
        try:
            os.unlink(script_path)
        except OSError:
            pass
