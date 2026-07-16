"""Legacy "Geometric Averaging Method" (full random 3D tumbling), ported from
lib/directional_power_sim.m / lib/eval_power_custom.m.

Sun-incidence directions are sampled over the full unit sphere, uniform in
sin(theta) (elevation) and uniform in phi (azimuth) for equal solid-angle
weighting, and the tumbling-average power is the arithmetic mean of the
instantaneous power over all sampled directions. This assumes true random
3D tumbling with no preferred axis and no eclipse.

Kept (not replaced) per the review response, so it can be directly compared
against the new barbecue-roll averaging in barbecue_roll.py -- the gap
between the two is the whole point the reviewer was raising.
"""
from dataclasses import dataclass
from typing import List

import numpy as np

from .cell_params import CellParams
from .constants import ETA_MPPT_DEFAULT, FIXED_CELL_TEMP_C_DEFAULT
from .panel_configs import PanelFace
from .solar_power import solar_power_output


@dataclass
class TumblingResult:
    P_mean: float
    P_min: float
    P_max: float
    P_flat: np.ndarray


def full_tumbling_average(
    cell_params: CellParams,
    panel_config: List[PanelFace],
    irradiance: float,
    n_az: int = 180,
    n_el: int = 90,
    ignore_temp: bool = False,
    thermal_mode: str = "instantaneous",
    fixed_temp_c: float = FIXED_CELL_TEMP_C_DEFAULT,
    eta_mppt: float = ETA_MPPT_DEFAULT,
) -> TumblingResult:
    phi = np.linspace(0.0, 2 * np.pi * (1 - 1 / n_az), n_az)
    theta = np.arcsin(np.linspace(-1.0, 1.0, n_el))

    cos_t = np.cos(theta)
    sin_t = np.sin(theta)
    cos_p = np.cos(phi)
    sin_p = np.sin(phi)

    P = np.empty(n_el * n_az)
    idx = 0
    for i in range(n_el):
        for j in range(n_az):
            s = np.array([cos_t[i] * cos_p[j], cos_t[i] * sin_p[j], sin_t[i]])
            P[idx], _, _ = solar_power_output(
                s, irradiance, cell_params, panel_config,
                ignore_temp=ignore_temp, thermal_mode=thermal_mode,
                fixed_temp_c=fixed_temp_c, eta_mppt=eta_mppt,
            )
            idx += 1

    return TumblingResult(float(P.mean()), float(P.min()), float(P.max()), P)
