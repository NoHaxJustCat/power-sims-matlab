"""Barbecue-roll (single-axis rotation) power averaging (Section 1 of the
ESA review response).

The reviewer's back-of-envelope check assumes the spacecraft spins about a
single body axis with that axis held perpendicular to the sun vector (their
worst-case assumption), so only the four faces "around" the roll axis are
ever illuminated (half-rectified-sinusoid profile, time-average = 1/pi of
peak) while the two faces aligned with the roll axis get ~zero direct sun.

This module generalizes that: for an arbitrary roll axis and an arbitrary
angle beta_roll between the roll axis and the sun direction, it numerically
averages the (reused, unchanged) per-attitude power model over one full
rotation, then sweeps beta_roll from 0 to 90 deg and reports the worst case
-- rather than assuming beta_roll = 90 deg is worst without checking.

Do not confuse beta_roll (this module, attitude-vs-sun angle for a rolling
body) with beta_orbit (eclipse.py, orbit-plane-vs-sun angle).
"""
from dataclasses import dataclass
from typing import List

import numpy as np

from .cell_params import CellParams
from .constants import ETA_MPPT_DEFAULT, FIXED_CELL_TEMP_C_DEFAULT
from .panel_configs import PanelFace
from .solar_power import solar_power_output

AXES = {
    "X": np.array([1.0, 0.0, 0.0]),
    "Y": np.array([0.0, 1.0, 0.0]),
    "Z": np.array([0.0, 0.0, 1.0]),
}


def _reference_frame(axis: np.ndarray):
    """Return (u, v) unit vectors spanning the plane perpendicular to axis."""
    axis = axis / np.linalg.norm(axis)
    helper = np.array([1.0, 0.0, 0.0]) if abs(axis[0]) < 0.9 else np.array([0.0, 1.0, 0.0])
    u = np.cross(axis, helper)
    u = u / np.linalg.norm(u)
    v = np.cross(axis, u)
    return axis, u, v


def sun_path(axis, beta_roll_deg: float, n_psi: int) -> np.ndarray:
    """Sun direction traced in the body frame over one full roll, shape (n_psi, 3).

    In the (rotating) body frame, a sun vector fixed in inertial space
    appears to precess around the roll axis on a cone of half-angle
    beta_roll as the spin angle psi sweeps 0..2*pi. This is the
    body-frame-equivalent way of expressing "spacecraft rotates about
    `axis`, axis makes angle beta_roll with the sun".
    """
    a, u, v = _reference_frame(np.asarray(axis, dtype=float))
    beta = np.radians(beta_roll_deg)
    psi = np.linspace(0.0, 2 * np.pi, n_psi, endpoint=False)
    return (np.cos(beta) * a
            + np.sin(beta) * (np.outer(np.cos(psi), u) + np.outer(np.sin(psi), v)))


@dataclass
class RollResult:
    beta_roll_deg: float
    P_avg: float
    P_min: float
    P_max: float


def barbecue_roll_average(
    axis,
    beta_roll_deg: float,
    cell_params: CellParams,
    panel_config: List[PanelFace],
    irradiance: float,
    n_psi: int = 720,
    thermal_mode: str = "fixed",
    fixed_temp_c: float = FIXED_CELL_TEMP_C_DEFAULT,
    eta_mppt: float = ETA_MPPT_DEFAULT,
) -> RollResult:
    """Average (and min/max) sunlit-only power over one full barbecue-roll rotation."""
    sun_dirs = sun_path(axis, beta_roll_deg, n_psi)
    powers = np.empty(n_psi)
    for i in range(n_psi):
        powers[i], _, _ = solar_power_output(
            sun_dirs[i], irradiance, cell_params, panel_config,
            thermal_mode=thermal_mode, fixed_temp_c=fixed_temp_c, eta_mppt=eta_mppt,
        )
    return RollResult(beta_roll_deg, float(powers.mean()), float(powers.min()), float(powers.max()))


@dataclass
class AxisSweepResult:
    axis_name: str
    betas_deg: np.ndarray
    P_avg: np.ndarray
    worst: RollResult


def sweep_beta_roll(
    axis,
    axis_name: str,
    cell_params: CellParams,
    panel_config: List[PanelFace],
    irradiance: float,
    betas_deg=None,
    n_psi: int = 720,
    thermal_mode: str = "fixed",
    fixed_temp_c: float = FIXED_CELL_TEMP_C_DEFAULT,
    eta_mppt: float = ETA_MPPT_DEFAULT,
) -> AxisSweepResult:
    if betas_deg is None:
        betas_deg = np.linspace(0.0, 90.0, 46)  # 2 deg steps

    results = [
        barbecue_roll_average(axis, b, cell_params, panel_config, irradiance,
                               n_psi=n_psi, thermal_mode=thermal_mode,
                               fixed_temp_c=fixed_temp_c, eta_mppt=eta_mppt)
        for b in betas_deg
    ]
    P_avg = np.array([r.P_avg for r in results])
    i_worst = int(np.argmin(P_avg))
    return AxisSweepResult(axis_name, np.asarray(betas_deg), P_avg, results[i_worst])


def sweep_all_axes(
    cell_params: CellParams,
    panel_config: List[PanelFace],
    irradiance: float,
    betas_deg=None,
    n_psi: int = 720,
    thermal_mode: str = "fixed",
    fixed_temp_c: float = FIXED_CELL_TEMP_C_DEFAULT,
    eta_mppt: float = ETA_MPPT_DEFAULT,
):
    """Sweep beta_roll for each candidate body axis (X, Y, Z) since the actual
    spin axis DVS will settle into is not yet confirmed by ADCS -- treat it
    as a free input and report the worst case across all three.
    """
    per_axis = {
        name: sweep_beta_roll(vec, name, cell_params, panel_config, irradiance,
                               betas_deg=betas_deg, n_psi=n_psi, thermal_mode=thermal_mode,
                               fixed_temp_c=fixed_temp_c, eta_mppt=eta_mppt)
        for name, vec in AXES.items()
    }
    worst_axis_name = min(per_axis, key=lambda k: per_axis[k].worst.P_avg)
    return per_axis, worst_axis_name
