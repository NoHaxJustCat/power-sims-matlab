"""Panel/face geometry for the four DVS cell layouts, ported from
lib/dvs_sat_a.m, dvs_sat_b.m, dvs_sat_c.m, dvs_sat_d.m.

  A: nominal, all 6 faces populated (20 cells: 4 per +-X/+-Y, 2 per +-Z)
  B: two +Y cells removed (n_strings on +Y dropped from 2 to 1)
  C: two -Z cells removed (-Z face zeroed out)
  D: both of the above (two +Y and two -Z cells removed)

n_cells = cells per string, n_strings = parallel strings on that face, so
the number of active cells on a face is n_cells * n_strings (this matches
lib/solar_power_output.m: P_face uses n_cells * n_strings).

NOTE (ported quirk, not a new bug): the MATLAB source computes each face's
thermal area as `face_area * n_cells` -- it does NOT multiply by
n_strings. So the thermal model's absorbing/emitting area under-counts
faces with n_strings > 1 relative to the number of cells actually
generating power on that face. This is preserved here for a faithful port
(it mostly stops mattering once you switch to the fixed-temperature
thermal mode used for the barbecue-roll analysis -- see solar_power.py).
"""
from dataclasses import dataclass, replace
from typing import List

from .constants import ETA_WIRING_DEFAULT

# 2U CubeSat Structure (SPF 3.8) dimensions
_A_SIDE_M2 = 100e-3 * 227e-3   # +-X, +-Y face area [m^2]
_A_TOP_M2 = 100e-3 * 100e-3    # +-Z face area [m^2]
_A_1CELL_M2 = 30.18e-4         # single AZUR SPACE 3G30 cell area [m^2]

FACE_NORMALS = {
    "+X": (1.0, 0.0, 0.0),
    "-X": (-1.0, 0.0, 0.0),
    "+Y": (0.0, 1.0, 0.0),
    "-Y": (0.0, -1.0, 0.0),
    "+Z": (0.0, 0.0, 1.0),
    "-Z": (0.0, 0.0, -1.0),
}

_FACE_ORDER = ["+X", "-X", "+Y", "-Y", "+Z", "-Z"]
_FACE_AREA = {f: (_A_SIDE_M2 if f in ("+X", "-X", "+Y", "-Y") else _A_TOP_M2) for f in _FACE_ORDER}


@dataclass
class PanelFace:
    face: str
    n_cells: int
    n_strings: int
    A_cell: float          # thermal area used for the face [m^2] (see module note)
    eta_wiring: float = ETA_WIRING_DEFAULT
    shadowing: float = 1.0


def _build(n_cells_vec, n_strings_vec) -> List[PanelFace]:
    faces = []
    for face, n_cells, n_strings in zip(_FACE_ORDER, n_cells_vec, n_strings_vec):
        A_cell = _FACE_AREA[face] * n_cells
        faces.append(PanelFace(face=face, n_cells=n_cells, n_strings=n_strings, A_cell=A_cell))
    return faces


def dvs_sat_a() -> List[PanelFace]:
    """Nominal: all faces populated, 20 cells total (4/side face, 2/end cap)."""
    return _build(n_cells_vec=[2, 2, 2, 2, 2, 2], n_strings_vec=[2, 2, 2, 2, 1, 1])


def dvs_sat_b() -> List[PanelFace]:
    """Two +Y cells removed."""
    return _build(n_cells_vec=[2, 2, 2, 2, 2, 2], n_strings_vec=[2, 2, 1, 2, 1, 1])


def dvs_sat_c() -> List[PanelFace]:
    """Two -Z cells removed."""
    return _build(n_cells_vec=[2, 2, 2, 2, 2, 0], n_strings_vec=[2, 2, 2, 2, 1, 0])


def dvs_sat_d() -> List[PanelFace]:
    """Two +Y and two -Z cells removed."""
    return _build(n_cells_vec=[2, 2, 2, 2, 2, 0], n_strings_vec=[2, 2, 1, 2, 1, 0])


_CONFIGS = {"a": dvs_sat_a, "b": dvs_sat_b, "c": dvs_sat_c, "d": dvs_sat_d}

CONFIG_DESCRIPTIONS = {
    "a": "Nominal configuration (all panels, 20 cells)",
    "b": "Two +Y cells removed",
    "c": "Two -Z cells removed",
    "d": "Two +Y and two -Z cells removed",
}


def get_panel_config(name: str) -> List[PanelFace]:
    key = name.strip().lower()
    if key not in _CONFIGS:
        raise ValueError(f"Unknown DVS config {name!r}; expected one of {sorted(_CONFIGS)}")
    return [replace(f) for f in _CONFIGS[key]()]
