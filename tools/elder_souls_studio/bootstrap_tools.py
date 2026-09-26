from __future__ import annotations
import shutil
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parent
THIRD = ROOT / "third_party"

TOOLS = {
    "RuneBlend": "https://github.com/tamateea/RuneBlend.git",
    "ob2blender": "https://github.com/stone-temple-pilot/ob2blender.git",
}

def run(cmd):
    print(">", " ".join(map(str, cmd)))
    subprocess.check_call(cmd)

def main():
    if not shutil.which("git"):
        raise SystemExit("Git is required. Install Git for Windows, then run this again.")
    THIRD.mkdir(exist_ok=True)
    for name, url in TOOLS.items():
        target = THIRD / name
        if target.exists():
            print(f"{name}: already installed")
            continue
        run(["git", "clone", "--depth", "1", url, str(target)])
    print("\nOptional GPL tools installed separately under third_party/.")
    print("Run run_studio.bat to start Elder Souls Content Studio.")

if __name__ == "__main__":
    main()
