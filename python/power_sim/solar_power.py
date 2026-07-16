"""Per-attitude power/temperature model, ported from lib/solar_power_output.m.

The physics is unchanged from the MATLAB source (per-face effective
irradiance G*cos(theta), temperature-corrected Vmp/Imp, one MPP-tracked
string per face) with two additions requested by the ESA review:

  * eta_mppt: a real (<1) MPPT efficiency, multiplied in alongside
    eta_wiring, instead of assuming an ideal 100%-efficient tracker.
  * thermal_mode='fixed': use a single fixed worst-case cell temperature
    for every illuminated face instead of the MATLAB model's instantaneous
    per-attitude radiative equilibrium (which the reviewer considered
    implausibly high, ~84 C, for a continuously-rolling spacecraft).
    thermal_mode='instantaneous' preserves the original MATLAB behaviour
    for direct comparison / regression-checking against the old report.
"""
from dataclasses import dataclass
from typing import List

import numpy as np

from .cell_params import CellParams
from .constants import ETA_MPPT_DEFAULT, FIXED_CELL_TEMP_C_DEFAULT, SIGMA_SB
from .panel_configs import FACE_NORMALS, PanelFace


@dataclass
class FaceResult:
    face: str
    cosTheta: float
    illuminated: bool
    T_cell_C: float
    Imp: float
    Vmp: float
    Pmp: float
    power: float


def solar_power_output(
    sun_vector,
    irradiance: float,
    cell_params: CellParams,
    panel_config: List[PanelFace],
    ignore_temp: bool = False,
    thermal_mode: str = "instantaneous",
    fixed_temp_c: float = FIXED_CELL_TEMP_C_DEFAULT,
    eta_mppt: float = ETA_MPPT_DEFAULT,
):
    """Total + per-face power for one instantaneous sun direction.

    sun_vector: 3-vector, body frame, need not be normalized.
    thermal_mode: 'instantaneous' (faithful MATLAB port, per-face radiative
        equilibrium) or 'fixed' (use fixed_temp_c for every illuminated face).
    ignore_temp: if True, cells are evaluated at cell_params.Tref (BOL/EOL
        "no temperature effect" sanity-check mode from the original report).
    """
    if thermal_mode not in ("instantaneous", "fixed"):
        raise ValueError("thermal_mode must be 'instantaneous' or 'fixed'")

    sun_hat = np.asarray(sun_vector, dtype=float)
    sun_hat = sun_hat / np.linalg.norm(sun_hat)

    face_power = np.zeros(len(panel_config))
    face_info: List[FaceResult] = []

    for k, pc in enumerate(panel_config):
        n_hat = np.asarray(FACE_NORMALS[pc.face.strip().upper()])
        cosTheta = float(np.dot(n_hat, sun_hat))

        # inactive face (cells physically removed, zero area -> skip thermal
        # balance entirely to avoid a 0/0 in the radiative-equilibrium calc)
        if pc.n_cells == 0 or pc.n_strings == 0:
            face_info.append(FaceResult(pc.face, 0.0, False, cell_params.Tref, 0.0, 0.0, 0.0, 0.0))
            continue

        # ── per-face thermal balance ─────────────────────────────────────
        if thermal_mode == "fixed":
            T_cell = fixed_temp_c if cosTheta > 0 else -273.15
        elif cosTheta > 0:
            Q_abs = cell_params.alpha_cell * pc.A_cell * irradiance * cosTheta
            emit_coeff = cell_params.eps_cell * pc.A_cell
            T_K = (Q_abs / (SIGMA_SB * emit_coeff)) ** 0.25
            T_cell = T_K - 273.15
        else:
            T_cell = -273.15  # cold deep space; face produces no power anyway

        if ignore_temp:
            dT = 0.0
            T_cell = cell_params.Tref
        else:
            dT = T_cell - cell_params.Tref

        Vmp_cell = cell_params.Vmp0 + cell_params.dVdT * dT

        illuminated = cosTheta > 0
        if not illuminated:
            face_info.append(FaceResult(pc.face, cosTheta, False, T_cell, 0.0, Vmp_cell, 0.0, 0.0))
            continue

        G_eff = irradiance * cosTheta
        Imp_cell = cell_params.Imp0 * (G_eff / cell_params.G0) + cell_params.dIdT * dT
        Imp_cell = max(Imp_cell, 0.0)
        Pmp_cell = Vmp_cell * Imp_cell

        P_face = (Pmp_cell * pc.n_cells * pc.n_strings * cell_params.LDEF
                  * pc.shadowing * pc.eta_wiring * eta_mppt)

        face_power[k] = P_face
        face_info.append(FaceResult(pc.face, cosTheta, True, T_cell, Imp_cell, Vmp_cell, Pmp_cell, P_face))

    return float(face_power.sum()), face_power, face_info
