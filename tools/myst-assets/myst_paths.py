"""Resolve directory containing myst.obj / myst.mob / myst.zon / myst.wld."""

from __future__ import annotations

import os
from pathlib import Path

REQUIRED_FILES = (
    "myst.zon",
    "myst.obj",
    "myst.mob",
    "myst.wld",
    "myst.shp",
    "myst.spe",
)


def repo_root() -> Path:
    return Path(__file__).resolve().parents[2]


def _has_myst_lib(path: Path) -> bool:
    return path.is_dir() and all((path / name).is_file() for name in REQUIRED_FILES)


def candidate_lib_dirs() -> list[Path]:
    root = repo_root()
    tool_dir = Path(__file__).resolve().parent
    candidates = [
        Path(os.environ["MYST_LIB_DIR"]) if os.environ.get("MYST_LIB_DIR") else None,
        root / "mudroot" / "lib",
        root,
        root / "sirio_dockers" / "mudroot" / "lib",
        tool_dir.parent / "mudroot" / "lib",
    ]
    seen: set[Path] = set()
    ordered: list[Path] = []
    for path in candidates:
        if path is None:
            continue
        resolved = path.resolve()
        if resolved in seen:
            continue
        seen.add(resolved)
        ordered.append(resolved)
    return ordered


def resolve_lib_dir(explicit: Path | None = None) -> Path:
    if explicit is not None:
        lib_dir = explicit.resolve()
        if not _has_myst_lib(lib_dir):
            missing = [name for name in REQUIRED_FILES if not (lib_dir / name).is_file()]
            raise FileNotFoundError(
                f"Directory asset non valida: {lib_dir}\n"
                f"File mancanti: {', '.join(missing)}"
            )
        return lib_dir

    for path in candidate_lib_dirs():
        if _has_myst_lib(path):
            return path

    searched = "\n".join(f"  - {path}" for path in candidate_lib_dirs())
    raise FileNotFoundError(
        "Impossibile trovare i file Myst (myst.zon, myst.obj, myst.mob, myst.wld, ...).\n"
        f"Percorsi controllati:\n{searched}\n\n"
        "Suggerimenti:\n"
        "  - sul branch mudlet i file sono spesso nella root del repository\n"
        "  - in sviluppo locale possono essere in mudroot/lib/\n"
        "  - imposta MYST_LIB_DIR=/percorso/alla/directory\n"
        "  - oppure: python import_db.py --lib-dir /percorso/alla/directory"
    )
