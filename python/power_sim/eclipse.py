"""Orbital eclipse-fraction model (new, Section 2 of the ESA review response).

The DVS orbit (600 km, 97 deg) is NOT sun-synchronous, so unlike an SSO the
orbital beta angle (angle between the orbit plane and the sun vector) drifts
through its full possible range over the mission life instead of holding a
favourable, low-eclipse geometry. This module computes the eclipse fraction
of the orbital period as a function of beta_orbit using the standard
cylindrical (no-penumbra) Earth-shadow model, and finds the worst case.

NOTE: beta_orbit (orbital beta angle, sun-vector-vs-orbit-plane) is a
distinct quantity from beta_roll (attitude beta angle, sun-vector-vs-body
roll-axis) used in barbecue_roll.py. Do not conflate the two.
"""
from dataclasses import dataclass

import numpy as np

from .constants import MU_EARTH_KM3_S2, R_EARTH_KM


def orbital_radius_km(altitude_km: float) -> float:
    return R_EARTH_KM + altitude_km


def orbital_period_s(altitude_km: float) -> float:
    r = orbital_radius_km(altitude_km)
    return 2 * np.pi * np.sqrt(r ** 3 / MU_EARTH_KM3_S2)


def eclipse_free_beta_deg(altitude_km: float) -> float:
    """Beta angle beyond which the cylindrical shadow never intersects the orbit."""
    r = orbital_radius_km(altitude_km)
    ratio = np.sqrt(1.0 - (R_EARTH_KM / r) ** 2)
    return float(np.degrees(np.arccos(ratio)))


def eclipse_fraction(beta_orbit_deg: float, altitude_km: float) -> float:
    """Fraction of the orbital period spent in Earth's cylindrical shadow.

    Standard circular-orbit / cylindrical-shadow result:
        f_eclipse(beta) = (1/pi) * arccos( sqrt(1-(R_E/r)^2) / cos(beta) )
    valid while cos(beta) >= sqrt(1-(R_E/r)^2); zero otherwise (sun-synchronous
    high-beta geometry with no eclipse at all).
    """
    r = orbital_radius_km(altitude_km)
    ratio = np.sqrt(1.0 - (R_EARTH_KM / r) ** 2)
    cos_b = np.cos(np.radians(beta_orbit_deg))
    if cos_b <= 0 or ratio / cos_b > 1.0:
        return 0.0
    return float(np.arccos(ratio / cos_b) / np.pi)


@dataclass
class WorstCaseEclipse:
    beta_orbit_deg: float
    eclipse_fraction: float
    eclipse_duration_s: float
    orbit_period_s: float


def worst_case_eclipse(altitude_km: float, beta_grid_deg=None) -> WorstCaseEclipse:
    """Numerically sweep beta_orbit to find the eclipse-fraction maximum.

    (Analytically f_eclipse is monotonically decreasing in |beta_orbit|, so
    the maximum is at beta_orbit = 0; this sweep exists to *verify* that
    numerically rather than assume it, per the review's "don't hardcode the
    worst case" guidance applied consistently across the whole analysis.)
    """
    if beta_grid_deg is None:
        beta_grid_deg = np.linspace(0.0, 90.0, 901)

    fracs = np.array([eclipse_fraction(b, altitude_km) for b in beta_grid_deg])
    i_worst = int(np.argmax(fracs))
    T = orbital_period_s(altitude_km)

    return WorstCaseEclipse(
        beta_orbit_deg=float(beta_grid_deg[i_worst]),
        eclipse_fraction=float(fracs[i_worst]),
        eclipse_duration_s=float(fracs[i_worst] * T),
        orbit_period_s=T,
    )
