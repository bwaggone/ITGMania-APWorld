#!/usr/bin/env python3
"""
ITGMania-APWorld Release Packaging Script
==========================================
Packages the ITGMania Archipelago World into:
  1. `dist/itgmania.apworld`: Archipelago world package (zip archive with itgmania/ root)
  2. `dist/module.zip`: ITGMania Simply Love client Lua module package

Usage:
  python package.py
  python package.py --clean
  python package.py --version 0.5.3
  python package.py --apworld-only
  python package.py --module-only
  python package.py --output-dir custom_dist
"""

from __future__ import annotations

import argparse
import json
import os
import shutil
import sys
import zipfile
from pathlib import Path

# Directories ignored during packaging
DEFAULT_DIR_EXCLUDES = {
    "__pycache__",
    ".pytest_cache",
    ".git",
    ".github",
    ".vscode",
    ".idea",
    "__MACOSX",
}

# Files ignored during packaging
DEFAULT_FILE_EXCLUDES = {
    ".DS_Store",
    "Thumbs.db",
    ".apignore",
}

# File extensions ignored during packaging
DEFAULT_EXT_EXCLUDES = {
    ".pyc",
    ".pyo",
}


def should_exclude(path: Path, base_dir: Path, include_tests: bool = False) -> bool:
    """Determine whether a given path should be excluded from packaging."""
    rel_path = path.relative_to(base_dir)
    parts = rel_path.parts

    for part in parts:
        if part in DEFAULT_DIR_EXCLUDES:
            return True
        if not include_tests and part in ("test", "tests"):
            return True

    if path.is_file():
        if path.name in DEFAULT_FILE_EXCLUDES:
            return True
        if path.suffix.lower() in DEFAULT_EXT_EXCLUDES:
            return True

    return False


def get_version(repo_root: Path, override_version: str | None = None) -> str:
    """Retrieve version from CLI override or world/archipelago.json."""
    if override_version:
        return override_version.strip()

    manifest_path = repo_root / "world" / "archipelago.json"
    if manifest_path.is_file():
        try:
            with open(manifest_path, "r", encoding="utf-8") as f:
                data = json.load(f)
                if "world_version" in data and data["world_version"]:
                    return str(data["world_version"]).strip()
        except Exception as e:
            print(f"Warning: Failed to read version from {manifest_path}: {e}")

    return "0.0.1"


def build_apworld(
    repo_root: Path,
    output_dir: Path,
    version: str,
    include_tests: bool = False,
) -> Path:
    """Package the world directory into itgmania.apworld."""
    world_dir = repo_root / "world"
    if not world_dir.is_dir():
        raise FileNotFoundError(f"World directory not found at {world_dir}")

    output_path = output_dir / "itgmania.apworld"
    print(f"[*] Building {output_path.name}...")

    # Load and update archipelago.json manifest for APContainer spec
    manifest_path = world_dir / "archipelago.json"
    manifest_data = {}
    if manifest_path.is_file():
        with open(manifest_path, "r", encoding="utf-8") as f:
            manifest_data = json.load(f)

    manifest_data.setdefault("game", "ITGMania")
    manifest_data["world_version"] = version
    manifest_data["version"] = 7
    manifest_data["compatible_version"] = 7
    if "authors" not in manifest_data:
        manifest_data["authors"] = ["bwags", "HeeroJay"]

    manifest_json_str = json.dumps(manifest_data, indent=2)

    count = 0
    with zipfile.ZipFile(output_path, "w", compression=zipfile.ZIP_DEFLATED) as zf:
        for root, dirs, files in os.walk(world_dir):
            root_path = Path(root)
            # Prune excluded directories in-place
            dirs[:] = [
                d
                for d in dirs
                if not should_exclude(root_path / d, world_dir, include_tests)
            ]

            for file_name in files:
                file_path = root_path / file_name
                if should_exclude(file_path, world_dir, include_tests):
                    continue

                rel_path = file_path.relative_to(world_dir)
                arc_name = f"itgmania/{rel_path.as_posix()}"

                if file_name == "archipelago.json" and rel_path == Path(
                    "archipelago.json"
                ):
                    # Write modified manifest containing container version
                    zf.writestr(arc_name, manifest_json_str)
                else:
                    zf.write(file_path, arcname=arc_name)
                count += 1

    size_kb = output_path.stat().st_size / 1024
    print(f"    -> Packaged {count} files into {output_path.name} ({size_kb:.1f} KB)")
    return output_path


def build_module_zip(repo_root: Path, output_dir: Path) -> Path:
    """Package the module directory into module.zip."""
    module_dir = repo_root / "module"
    if not module_dir.is_dir():
        raise FileNotFoundError(f"Module directory not found at {module_dir}")

    output_path = output_dir / "module.zip"
    print(f"[*] Building {output_path.name}...")

    count = 0
    with zipfile.ZipFile(output_path, "w", compression=zipfile.ZIP_DEFLATED) as zf:
        for root, dirs, files in os.walk(module_dir):
            root_path = Path(root)
            dirs[:] = [
                d for d in dirs if not should_exclude(root_path / d, module_dir)
            ]

            for file_name in files:
                file_path = root_path / file_name
                if should_exclude(file_path, module_dir):
                    continue

                rel_path = file_path.relative_to(module_dir)
                arc_name = rel_path.as_posix()
                zf.write(file_path, arcname=arc_name)
                count += 1

    size_kb = output_path.stat().st_size / 1024
    print(f"    -> Packaged {count} files into {output_path.name} ({size_kb:.1f} KB)")
    return output_path


def validate_artifacts(output_dir: Path, check_apworld: bool, check_module: bool) -> bool:
    """Validate that packaged archives conform to required specifications."""
    print("[*] Validating generated packages...")
    all_ok = True

    if check_apworld:
        apworld_path = output_dir / "itgmania.apworld"
        if not apworld_path.is_file():
            print(f"    [FAIL] Missing {apworld_path.name}")
            all_ok = False
        else:
            with zipfile.ZipFile(apworld_path, "r") as zf:
                names = zf.namelist()
                # Check top-level directory prefix
                non_matching = [n for n in names if not n.startswith("itgmania/")]
                if non_matching:
                    print(
                        f"    [FAIL] apworld contains files outside 'itgmania/': {non_matching[:3]}"
                    )
                    all_ok = False
                # Check essential entry points
                if "itgmania/__init__.py" not in names:
                    print("    [FAIL] itgmania/__init__.py missing in apworld")
                    all_ok = False
                if "itgmania/world.py" not in names:
                    print("    [FAIL] itgmania/world.py missing in apworld")
                    all_ok = False
                if "itgmania/archipelago.json" not in names:
                    print("    [FAIL] itgmania/archipelago.json missing in apworld")
                    all_ok = False
                else:
                    manifest = json.loads(
                        zf.read("itgmania/archipelago.json").decode("utf-8")
                    )
                    if manifest.get("game") != "ITGMania":
                        print(f"    [FAIL] Unexpected game in manifest: {manifest.get('game')}")
                        all_ok = False
                    if manifest.get("version") != 7:
                        print("    [FAIL] Missing or invalid container version in manifest")
                        all_ok = False
            if all_ok:
                print(f"    [OK] {apworld_path.name} structure verified successfully.")

    if check_module:
        module_path = output_dir / "module.zip"
        if not module_path.is_file():
            print(f"    [FAIL] Missing {module_path.name}")
            all_ok = False
        else:
            with zipfile.ZipFile(module_path, "r") as zf:
                names = zf.namelist()
                if "archipelago.lua" not in names:
                    print("    [FAIL] archipelago.lua missing in module.zip")
                    all_ok = False
                if "archipelago.ini.example" not in names:
                    print("    [FAIL] archipelago.ini.example missing in module.zip")
                    all_ok = False
                lua_submodules = [n for n in names if n.startswith("Archipelago/") and n.endswith(".lua")]
                if not lua_submodules:
                    print("    [FAIL] No Archipelago/*.lua files found in module.zip")
                    all_ok = False
            if all_ok:
                print(f"    [OK] {module_path.name} structure verified successfully.")

    return all_ok


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Auto-package ITGMania Archipelago World and Module releases."
    )
    parser.add_argument(
        "-o",
        "--output-dir",
        type=Path,
        default=Path("dist"),
        help="Target output directory (default: dist/)",
    )
    parser.add_argument(
        "-v",
        "--version",
        type=str,
        default=None,
        help="Override version string (default: read from world/archipelago.json)",
    )
    parser.add_argument(
        "--clean",
        action="store_true",
        help="Purge the output directory before packaging",
    )
    parser.add_argument(
        "--apworld-only",
        action="store_true",
        help="Build only itgmania.apworld",
    )
    parser.add_argument(
        "--module-only",
        action="store_true",
        help="Build only module.zip",
    )
    parser.add_argument(
        "--include-tests",
        action="store_true",
        help="Include world/test/ in the .apworld package",
    )
    parser.add_argument(
        "--validate-only",
        action="store_true",
        help="Validate existing packaged artifacts without rebuilding",
    )

    args = parser.parse_args()
    repo_root = Path(__file__).resolve().parent
    output_dir = repo_root / args.output_dir

    build_apw = not args.module_only
    build_mod = not args.apworld_only

    if args.validate_only:
        success = validate_artifacts(output_dir, build_apw, build_mod)
        return 0 if success else 1

    if args.clean and output_dir.exists():
        print(f"[*] Cleaning output directory: {output_dir}")
        shutil.rmtree(output_dir)

    output_dir.mkdir(parents=True, exist_ok=True)
    version = get_version(repo_root, args.version)
    print(f"[*] ITGMania-APWorld Release Packaging (Version: {version})")
    print(f"[*] Output directory: {output_dir}")

    if build_apw:
        build_apworld(repo_root, output_dir, version, args.include_tests)

    if build_mod:
        build_module_zip(repo_root, output_dir)

    success = validate_artifacts(output_dir, build_apw, build_mod)
    if success:
        print("\n[+] Release packaging completed successfully!")
        print(f"[+] Output files located at: {output_dir.resolve()}")
        for f in output_dir.iterdir():
            if f.is_file():
                print(f"    - {f.name} ({f.stat().st_size / 1024:.1f} KB)")
        return 0
    else:
        print("\n[-] Validation failed on packaged artifacts.")
        return 1


if __name__ == "__main__":
    sys.exit(main())
