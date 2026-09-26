from __future__ import annotations

import json
import os
import shutil
import subprocess
import sys
from blender_tools import open_model as open_in_blender, ensure_ob2blender
import tkinter as tk
from publisher import (
    publish as publish_to_cache,
    exact_clone,
    restore_latest,
    next_cache_id,
    extract_model,
)
from dataclasses import dataclass, asdict, field
from pathlib import Path
from tkinter import filedialog, messagebox, ttk
from typing import Any

APP_NAME = "Elder Souls Content Studio"
VERSION = "0.1.0"
ROOT = Path(getattr(sys, "_MEIPASS", Path(__file__).resolve().parent))
USER_HOME = Path(os.environ.get("LOCALAPPDATA", Path.home())) / "ElderSoulsContentStudio"
WORKSPACE = USER_HOME / "workspace"
ASSETS_DIR = WORKSPACE / "assets"
EXPORTS_DIR = WORKSPACE / "exports"
SETTINGS_FILE = WORKSPACE / "settings.json"

def detect_elder_souls_cache() -> str:
    local = Path(os.environ.get("LOCALAPPDATA", Path.home() / "AppData" / "Local"))
    candidates = [
        local / "Programs" / "Elder Souls RPG Alpha" / "server" / "data" / "cache",
        local / "Programs" / "Elder Souls Scape PK Training" / "server" / "data" / "cache",
    ]
    for path in candidates:
        if (path / "main_file_cache.dat2").exists():
            return str(path)
    return ""

ASSET_TYPES = [
    "model", "item", "npc", "object", "animation",
    "interface", "map_region", "audio", "lore", "raw_cache"
]

TYPE_TEMPLATES = {
    "item": {
        "model_id": 0, "model_zoom": 2000, "rotation_x": 0, "rotation_y": 0,
        "offset_x": 0, "offset_y": 0, "value": 1, "stackable": False,
        "members": False, "inventory_options": ["Wear", "", "", "", "Drop"],
        "equip_slot": -1, "equip_type": -1,
        "male_model_1": -1, "male_model_2": -1, "female_model_1": -1, "female_model_2": -1,
        "recolor_from": [], "recolor_to": []
    },
    "npc": {
        "model_ids": [], "size": 1, "combat_level": 1,
        "options": ["Talk-to", "Attack", "", "", "Examine"],
        "visible_on_map": True, "render_emote": -1,
        "recolor_from": [], "recolor_to": []
    },
    "object": {
        "model_ids": [], "size_x": 1, "size_y": 1,
        "options": ["Use", "", "", "", "Examine"], "animation_id": -1,
        "no_clip": False, "recolor_from": [], "recolor_to": []
    },
    "model": {},
    "animation": {},
    "interface": {"component_id": 0},
    "map_region": {"index": 5, "archive": 0, "file": 0},
    "audio": {"index": 4, "archive": 0, "file": 0},
    "lore": {},
    "raw_cache": {"index": 0, "archive": 0, "file": 0},
}

@dataclass
class ModelMeta:
    integer_grid: bool = True
    vertex_color_mode: str = "HSL16/RGB15"
    face_priority: int = 0
    face_alpha: int = 0
    vertex_group: int = 0
    face_group: int = 0

@dataclass
class Asset:
    asset_id: int
    name: str
    asset_type: str
    source_file: str = ""
    description: str = ""
    model: ModelMeta = field(default_factory=ModelMeta)
    tags: list[str] = field(default_factory=list)
    game_data: dict[str, Any] = field(default_factory=dict)

class Store:
    def __init__(self):
        for p in (WORKSPACE, ASSETS_DIR, EXPORTS_DIR):
            p.mkdir(parents=True, exist_ok=True)
        detected_cache = detect_elder_souls_cache()
        if not SETTINGS_FILE.exists():
            self.save_settings({
                "blender_path": "",
                "game_export_dir": str(EXPORTS_DIR),
                "cache_dir": detected_cache,
                "filestore_jar": "",
                "java_path": "",
                "cache_helper_classpath": str(ROOT / "cache_tools" / "bin"),
            })
        elif detected_cache:
            current = self.settings()
            configured = Path(current.get("cache_dir", "")) if current.get("cache_dir") else None
            if not configured or not (configured / "main_file_cache.dat2").exists():
                current["cache_dir"] = detected_cache
                self.save_settings(current)

    def settings(self):
        return json.loads(SETTINGS_FILE.read_text(encoding="utf-8"))

    def save_settings(self, data):
        WORKSPACE.mkdir(parents=True, exist_ok=True)
        SETTINGS_FILE.write_text(json.dumps(data, indent=2), encoding="utf-8")

    def asset_path(self, asset: Asset):
        safe = "".join(c if c.isalnum() or c in "-_" else "_" for c in asset.name.strip())
        return ASSETS_DIR / f"{asset.asset_type}_{asset.asset_id}_{safe}.json"

    def save_asset(self, asset: Asset):
        for old in ASSETS_DIR.glob(f"*_{asset.asset_id}_*.json"):
            old.unlink()
        self.asset_path(asset).write_text(json.dumps(asdict(asset), indent=2), encoding="utf-8")

    def load_assets(self):
        out = []
        for path in sorted(ASSETS_DIR.glob("*.json")):
            try:
                data = json.loads(path.read_text(encoding="utf-8"))
                model = ModelMeta(**data.pop("model", {}))
                out.append(Asset(model=model, **data))
            except Exception:
                continue
        return out

    def delete_asset(self, asset_id):
        for path in ASSETS_DIR.glob(f"*_{asset_id}_*.json"):
            path.unlink()

    def export_asset(self, asset: Asset):
        settings = self.settings()
        target = Path(settings.get("game_export_dir") or EXPORTS_DIR)
        target.mkdir(parents=True, exist_ok=True)
        out = target / f"{asset.asset_type}_{asset.asset_id}.esasset.json"
        payload = {
            "format": "elder-souls-asset",
            "version": 1,
            "asset": asdict(asset),
        }
        out.write_text(json.dumps(payload, indent=2), encoding="utf-8")
        return out

def validate_asset(a: Asset):
    errors = []
    if a.asset_id < 0:
        errors.append("Asset ID must be zero or greater.")
    if not a.name.strip():
        errors.append("Name is required.")
    if a.asset_type not in ASSET_TYPES:
        errors.append("Unknown asset type.")
    if a.source_file and not Path(a.source_file).exists():
        errors.append("Source file does not exist.")
    if not 0 <= a.model.face_priority <= 255:
        errors.append("Face priority must be 0-255.")
    if not 0 <= a.model.face_alpha <= 255:
        errors.append("Face alpha must be 0-255.")
    if a.model.vertex_group < 0 or a.model.face_group < 0:
        errors.append("Transformation group IDs cannot be negative.")
    return errors

class Studio(tk.Tk):
    def __init__(self):
        super().__init__()
        self.store = Store()
        self.title(f"{APP_NAME} v{VERSION}")
        self.geometry("1180x720")
        self.minsize(980, 620)
        self.current_id = None
        self._build()
        self.refresh()

    def _build(self):
        toolbar = ttk.Frame(self, padding=8)
        toolbar.pack(fill="x")
        ttk.Label(toolbar, text=APP_NAME, font=("Segoe UI", 15, "bold")).pack(side="left")
        ttk.Button(toolbar, text="New", command=self.new_asset).pack(side="left", padx=(20,4))
        ttk.Button(toolbar, text="Clone Existing", command=self.clone_existing).pack(side="left", padx=4)
        ttk.Button(toolbar, text="Auto ID", command=self.auto_id).pack(side="left", padx=4)
        ttk.Button(toolbar, text="Load Template", command=self.load_template).pack(side="left", padx=4)
        ttk.Button(toolbar, text="Save", command=self.save).pack(side="left", padx=4)
        ttk.Button(toolbar, text="Validate", command=self.validate_current).pack(side="left", padx=4)
        ttk.Button(toolbar, text="Export", command=self.export_current).pack(side="left", padx=4)
        ttk.Button(toolbar, text="Publish to 718 Cache", command=self.publish_cache).pack(side="left", padx=4)
        ttk.Button(toolbar, text="Open in Blender", command=self.open_blender).pack(side="left", padx=4)
        ttk.Button(toolbar, text="Extract Model", command=self.extract_model_dialog).pack(side="left", padx=4)
        ttk.Button(toolbar, text="Restore Backup", command=self.restore_backup).pack(side="left", padx=4)
        ttk.Button(toolbar, text="Install Blender Tools", command=self.install_blender_tools).pack(side="right", padx=4)
        ttk.Button(toolbar, text="Settings", command=self.settings_dialog).pack(side="right")

        main = ttk.Panedwindow(self, orient="horizontal")
        main.pack(fill="both", expand=True, padx=8, pady=(0,8))

        left = ttk.Frame(main, padding=6)
        main.add(left, weight=1)
        ttk.Label(left, text="Assets", font=("Segoe UI", 11, "bold")).pack(anchor="w")
        self.tree = ttk.Treeview(left, columns=("id","type","name"), show="headings", selectmode="browse")
        self.tree.heading("id", text="ID")
        self.tree.heading("type", text="Type")
        self.tree.heading("name", text="Name")
        self.tree.column("id", width=70, anchor="e")
        self.tree.column("type", width=100)
        self.tree.column("name", width=220)
        self.tree.pack(fill="both", expand=True, pady=6)
        self.tree.bind("<<TreeviewSelect>>", self.on_select)
        ttk.Button(left, text="Delete selected", command=self.delete_current).pack(fill="x")

        right = ttk.Frame(main, padding=10)
        main.add(right, weight=3)

        self.vars = {
            "asset_id": tk.StringVar(value="0"),
            "name": tk.StringVar(),
            "asset_type": tk.StringVar(value="model"),
            "source_file": tk.StringVar(),
            "description": tk.StringVar(),
            "face_priority": tk.StringVar(value="0"),
            "face_alpha": tk.StringVar(value="0"),
            "vertex_group": tk.StringVar(value="0"),
            "face_group": tk.StringVar(value="0"),
            "vertex_color_mode": tk.StringVar(value="HSL16/RGB15"),
            "integer_grid": tk.BooleanVar(value=True),
            "tags": tk.StringVar(),
        }

        form = ttk.LabelFrame(right, text="Asset definition", padding=10)
        form.pack(fill="x")
        self.row(form, 0, "Asset ID", ttk.Entry(form, textvariable=self.vars["asset_id"]))
        self.row(form, 1, "Name", ttk.Entry(form, textvariable=self.vars["name"]))
        combo = ttk.Combobox(form, values=ASSET_TYPES, textvariable=self.vars["asset_type"], state="readonly")
        self.row(form, 2, "Type", combo)

        source = ttk.Frame(form)
        ttk.Entry(source, textvariable=self.vars["source_file"]).pack(side="left", fill="x", expand=True)
        ttk.Button(source, text="Browse", command=self.browse_source).pack(side="left", padx=(6,0))
        self.row(form, 3, "Source file", source)
        self.row(form, 4, "Description", ttk.Entry(form, textvariable=self.vars["description"]))
        self.row(form, 5, "Tags", ttk.Entry(form, textvariable=self.vars["tags"]))

        model = ttk.LabelFrame(right, text="RuneScape-style model metadata", padding=10)
        model.pack(fill="x", pady=(10,0))
        self.row(model, 0, "Color encoding", ttk.Combobox(model, values=["HSL16/RGB15","RGB","Vertex RGB"], textvariable=self.vars["vertex_color_mode"], state="readonly"))
        self.row(model, 1, "Face priority", ttk.Entry(model, textvariable=self.vars["face_priority"]))
        self.row(model, 2, "Face alpha", ttk.Entry(model, textvariable=self.vars["face_alpha"]))
        self.row(model, 3, "Vertex group / VSKIN", ttk.Entry(model, textvariable=self.vars["vertex_group"]))
        self.row(model, 4, "Face group / TSKIN", ttk.Entry(model, textvariable=self.vars["face_group"]))
        self.row(model, 5, "Integer-coordinate grid", ttk.Checkbutton(model, variable=self.vars["integer_grid"]))

        data_frame = ttk.LabelFrame(right, text="Game data (JSON)", padding=10)
        data_frame.pack(fill="both", expand=True, pady=(10,0))
        self.game_data = tk.Text(data_frame, height=10, wrap="none", font=("Consolas", 10))
        self.game_data.pack(fill="both", expand=True)
        self.game_data.insert("1.0", "{}")

        self.status = tk.StringVar(value="Ready")
        ttk.Label(self, textvariable=self.status, relief="sunken", anchor="w").pack(fill="x", side="bottom")

    @staticmethod
    def row(parent, r, label, widget):
        ttk.Label(parent, text=label).grid(row=r, column=0, sticky="w", padx=(0,10), pady=4)
        widget.grid(row=r, column=1, sticky="ew", pady=4)
        parent.columnconfigure(1, weight=1)

    def asset_from_form(self):
        try:
            game_data = json.loads(self.game_data.get("1.0", "end").strip() or "{}")
            return Asset(
                asset_id=int(self.vars["asset_id"].get()),
                name=self.vars["name"].get().strip(),
                asset_type=self.vars["asset_type"].get(),
                source_file=self.vars["source_file"].get().strip(),
                description=self.vars["description"].get().strip(),
                tags=[x.strip() for x in self.vars["tags"].get().split(",") if x.strip()],
                model=ModelMeta(
                    integer_grid=bool(self.vars["integer_grid"].get()),
                    vertex_color_mode=self.vars["vertex_color_mode"].get(),
                    face_priority=int(self.vars["face_priority"].get()),
                    face_alpha=int(self.vars["face_alpha"].get()),
                    vertex_group=int(self.vars["vertex_group"].get()),
                    face_group=int(self.vars["face_group"].get()),
                ),
                game_data=game_data,
            )
        except Exception as e:
            raise ValueError(f"Invalid field value: {e}")

    def load_form(self, a: Asset):
        self.current_id = a.asset_id
        for key, value in {
            "asset_id":a.asset_id, "name":a.name, "asset_type":a.asset_type,
            "source_file":a.source_file, "description":a.description,
            "face_priority":a.model.face_priority, "face_alpha":a.model.face_alpha,
            "vertex_group":a.model.vertex_group, "face_group":a.model.face_group,
            "vertex_color_mode":a.model.vertex_color_mode,
            "tags":", ".join(a.tags)
        }.items():
            self.vars[key].set(str(value))
        self.vars["integer_grid"].set(a.model.integer_grid)
        self.game_data.delete("1.0","end")
        self.game_data.insert("1.0", json.dumps(a.game_data, indent=2))

    def new_asset(self):
        used = {a.asset_id for a in self.store.load_assets()}
        new_id = 0
        while new_id in used:
            new_id += 1
        self.load_form(Asset(new_id, "New Asset", "model"))
        self.status.set("New unsaved asset")

    def refresh(self):
        for x in self.tree.get_children():
            self.tree.delete(x)
        for a in self.store.load_assets():
            self.tree.insert("", "end", iid=str(a.asset_id), values=(a.asset_id,a.asset_type,a.name))
        self.status.set(f"{len(self.store.load_assets())} assets loaded")

    def on_select(self, _event=None):
        sel = self.tree.selection()
        if not sel: return
        aid = int(sel[0])
        for a in self.store.load_assets():
            if a.asset_id == aid:
                self.load_form(a)
                break

    def save(self):
        try:
            a = self.asset_from_form()
            errors = validate_asset(a)
            if errors and any("required" in e.lower() or "unknown" in e.lower() for e in errors):
                messagebox.showerror("Cannot save", "\n".join(errors))
                return
            self.store.save_asset(a)
            self.current_id = a.asset_id
            self.refresh()
            self.status.set(f"Saved {a.asset_type} {a.asset_id}: {a.name}")
        except Exception as e:
            messagebox.showerror("Save failed", str(e))

    def validate_current(self):
        try:
            a = self.asset_from_form()
            errors = validate_asset(a)
            if errors:
                messagebox.showwarning("Validation", "\n".join(errors))
            else:
                messagebox.showinfo("Validation", "Asset definition is valid.")
        except Exception as e:
            messagebox.showerror("Validation", str(e))

    def export_current(self):
        try:
            a = self.asset_from_form()
            errors = validate_asset(a)
            if errors:
                messagebox.showwarning("Export blocked", "\n".join(errors))
                return
            self.store.save_asset(a)
            out = self.store.export_asset(a)
            self.status.set(f"Exported: {out}")
            messagebox.showinfo("Export complete", str(out))
        except Exception as e:
            messagebox.showerror("Export failed", str(e))

    def load_template(self):
        typ=self.vars["asset_type"].get()
        data=TYPE_TEMPLATES.get(typ,{})
        self.game_data.delete("1.0","end")
        self.game_data.insert("1.0",json.dumps(data,indent=2))
        self.status.set(f"Loaded {typ} template")

    def clone_existing(self):
        win = tk.Toplevel(self)
        win.title("Clone Existing 718 Asset")
        win.geometry("430x230")
        typ = tk.StringVar(value=self.vars["asset_type"].get() if self.vars["asset_type"].get() in ("item","npc","object","model") else "item")
        source = tk.StringVar()
        target = tk.StringVar()
        frm=ttk.Frame(win,padding=12); frm.pack(fill="both",expand=True)
        ttk.Label(frm,text="Asset type").grid(row=0,column=0,sticky="w",pady=5)
        ttk.Combobox(frm,values=["item","npc","object","model"],textvariable=typ,state="readonly").grid(row=0,column=1,sticky="ew")
        ttk.Label(frm,text="Existing ID").grid(row=1,column=0,sticky="w",pady=5)
        ttk.Entry(frm,textvariable=source).grid(row=1,column=1,sticky="ew")
        ttk.Label(frm,text="New ID").grid(row=2,column=0,sticky="w",pady=5)
        ttk.Entry(frm,textvariable=target).grid(row=2,column=1,sticky="ew")
        frm.columnconfigure(1,weight=1)

        def suggest():
            try: target.set(str(next_cache_id(typ.get(),self.store.settings())))
            except Exception as e: messagebox.showerror("Auto ID failed",str(e),parent=win)
        ttk.Button(frm,text="Suggest ID",command=suggest).grid(row=2,column=2,padx=5)

        def do_clone():
            try:
                src=int(source.get()); dst=int(target.get())
                exact_clone(typ.get(),src,dst,self.store.settings())
                a=Asset(dst,f"Elder Souls {typ.get()} {dst}",typ.get(),game_data={"base_id":src})
                self.load_form(a)
                self.store.save_asset(a)
                self.refresh()
                win.destroy()
                messagebox.showinfo("Clone complete",f"Cloned {typ.get()} {src} to {dst}.\nEdit fields, then Publish to 718 Cache.")
            except Exception as e:
                messagebox.showerror("Clone failed",str(e),parent=win)
        ttk.Button(frm,text="Clone into Elder Souls",command=do_clone).grid(row=3,column=1,sticky="e",pady=18)

    def auto_id(self):
        try:
            typ=self.vars["asset_type"].get()
            if typ not in ("item","npc","object","model","animation","interface"):
                raise ValueError("Auto ID is available for cache-backed asset types.")
            self.vars["asset_id"].set(str(next_cache_id(typ,self.store.settings())))
            self.status.set("Assigned next free cache ID")
        except Exception as e:
            messagebox.showerror("Auto ID failed",str(e))

    def restore_backup(self):
        try:
            a=self.asset_from_form()
            result=restore_latest(asdict(a),self.store.settings())
            self.status.set("Restored latest cache backup")
            messagebox.showinfo("Restore complete",result or "Backup restored.")
        except Exception as e:
            messagebox.showerror("Restore failed",str(e))

    def extract_model_dialog(self):
        win=tk.Toplevel(self); win.title("Extract Cache Model"); win.geometry("390x150")
        mid=tk.StringVar()
        frm=ttk.Frame(win,padding=12); frm.pack(fill="both",expand=True)
        ttk.Label(frm,text="Model ID").grid(row=0,column=0,sticky="w")
        ttk.Entry(frm,textvariable=mid).grid(row=0,column=1,sticky="ew")
        frm.columnconfigure(1,weight=1)
        def go():
            try:
                p=extract_model(int(mid.get()),self.store.settings())
                self.vars["asset_type"].set("model")
                self.vars["asset_id"].set(mid.get())
                self.vars["source_file"].set(str(p))
                win.destroy()
                self.status.set(f"Extracted model {mid.get()}")
                if messagebox.askyesno("Model extracted",f"Saved to:\n{p}\n\nOpen Blender now?"):
                    self.open_blender()
            except Exception as e:
                messagebox.showerror("Extract failed",str(e),parent=win)
        ttk.Button(frm,text="Extract",command=go).grid(row=1,column=1,sticky="e",pady=18)

    def publish_cache(self):
        try:
            a = self.asset_from_form()
            errors = validate_asset(a)
            if errors:
                messagebox.showwarning("Publish blocked", "\n".join(errors))
                return
            self.store.save_asset(a)
            result = publish_to_cache(asdict(a), self.store.settings())
            self.status.set("Published to Elder Souls 718 cache")
            messagebox.showinfo(
                "Elder Souls cache publish complete",
                (result or "Published successfully.") + "\n\nClose and reopen Elder Souls RPG Alpha to load cache changes."
            )
        except Exception as e:
            messagebox.showerror("718 cache publish failed", str(e))

    def browse_source(self):
        path = filedialog.askopenfilename(
            title="Select source asset",
            filetypes=[
                ("3D / game assets","*.blend *.obj *.fbx *.gltf *.glb *.dat *.ob2"),
                ("All files","*.*"),
            ],
        )
        if path:
            self.vars["source_file"].set(path)

    def open_blender(self):
        src = self.vars["source_file"].get().strip()
        try:
            if not src or not Path(src).exists():
                raise FileNotFoundError("Select or extract a model source file first.")
            open_in_blender(src, self.store.settings())
            self.status.set("Blender launched with model")
        except Exception as e:
            messagebox.showerror("Blender launch failed", str(e))

    def install_blender_tools(self):
        try:
            dest=ensure_ob2blender(self.store.settings())
            self.status.set("ob2blender installed")
            messagebox.showinfo("Blender tools ready",f"ob2blender installed to:\n{dest}")
        except Exception as e:
            messagebox.showerror("Blender tools install failed",str(e))

    def delete_current(self):
        sel = self.tree.selection()
        if not sel: return
        aid = int(sel[0])
        if messagebox.askyesno("Delete asset", f"Delete asset {aid}?"):
            self.store.delete_asset(aid)
            self.refresh()

    def settings_dialog(self):
        s = self.store.settings()
        win = tk.Toplevel(self)
        win.title("Studio Settings")
        win.geometry("760x390")
        blender = tk.StringVar(value=s.get("blender_path",""))
        export_dir = tk.StringVar(value=s.get("game_export_dir", str(EXPORTS_DIR)))
        cache_dir = tk.StringVar(value=s.get("cache_dir",""))
        filestore = tk.StringVar(value=s.get("filestore_jar",""))
        java_path = tk.StringVar(value=s.get("java_path",""))

        def pick_blender():
            p = filedialog.askopenfilename(title="Select blender.exe", filetypes=[("Blender","blender.exe"),("All","*.*")])
            if p: blender.set(p)

        def pick_export():
            p = filedialog.askdirectory(title="Choose Elder Souls export directory")
            if p: export_dir.set(p)

        frm = ttk.Frame(win, padding=12); frm.pack(fill="both", expand=True)
        ttk.Label(frm,text="Blender executable").grid(row=0,column=0,sticky="w",pady=6)
        ttk.Entry(frm,textvariable=blender).grid(row=0,column=1,sticky="ew")
        ttk.Button(frm,text="Browse",command=pick_blender).grid(row=0,column=2,padx=6)
        ttk.Label(frm,text="Game export directory").grid(row=1,column=0,sticky="w",pady=6)
        ttk.Entry(frm,textvariable=export_dir).grid(row=1,column=1,sticky="ew")
        ttk.Button(frm,text="Browse",command=pick_export).grid(row=1,column=2,padx=6)

        def pick_cache():
            p = filedialog.askdirectory(title="Choose Elder Souls 718 cache directory")
            if p: cache_dir.set(p)

        def use_installed_game():
            p = detect_elder_souls_cache()
            if not p:
                messagebox.showerror(
                    "Game not found",
                    "Elder Souls RPG Alpha was not found in its standard install folder. Install the game first or choose the cache folder manually.",
                    parent=win,
                )
                return
            cache_dir.set(p)

        def pick_filestore():
            p = filedialog.askopenfilename(title="Select FileStore.jar", filetypes=[("Java archive","*.jar"),("All","*.*")])
            if p: filestore.set(p)

        def pick_java():
            p = filedialog.askopenfilename(title="Select java.exe", filetypes=[("Java","java.exe"),("All","*.*")])
            if p: java_path.set(p)

        ttk.Label(frm,text="Elder Souls 718 cache").grid(row=2,column=0,sticky="w",pady=6)
        ttk.Entry(frm,textvariable=cache_dir).grid(row=2,column=1,sticky="ew")
        cache_buttons = ttk.Frame(frm)
        cache_buttons.grid(row=2,column=2,padx=6)
        ttk.Button(cache_buttons,text="Use Installed Game",command=use_installed_game).pack(side="left")
        ttk.Button(cache_buttons,text="Browse",command=pick_cache).pack(side="left",padx=(5,0))
        ttk.Label(frm,text="FileStore.jar").grid(row=3,column=0,sticky="w",pady=6)
        ttk.Entry(frm,textvariable=filestore).grid(row=3,column=1,sticky="ew")
        ttk.Button(frm,text="Browse",command=pick_filestore).grid(row=3,column=2,padx=6)
        ttk.Label(frm,text="Java executable").grid(row=4,column=0,sticky="w",pady=6)
        ttk.Entry(frm,textvariable=java_path).grid(row=4,column=1,sticky="ew")
        ttk.Button(frm,text="Browse",command=pick_java).grid(row=4,column=2,padx=6)
        frm.columnconfigure(1,weight=1)

        def save_settings():
            self.store.save_settings({
                "blender_path": blender.get().strip(),
                "game_export_dir": export_dir.get().strip(),
                "cache_dir": cache_dir.get().strip(),
                "filestore_jar": filestore.get().strip(),
                "java_path": java_path.get().strip(),
                "cache_helper_classpath": str(ROOT / "cache_tools" / "bin"),
            })
            win.destroy()
            self.status.set("Settings saved")

        ttk.Button(frm,text="Save",command=save_settings).grid(row=5,column=1,sticky="e",pady=15)

if __name__ == "__main__":
    Studio().mainloop()
