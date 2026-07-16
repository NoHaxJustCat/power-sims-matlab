"""Shared physical constants and default (flagged) engineering parameters.

Anything suffixed _PLACEHOLDER is a stand-in value that has NOT been
confirmed against real hardware/CONOPS data and must be signed off by the
relevant subsystem lead (ADCS, EPS, systems) before being used for a real
sizing decision. See python/README.md for the full assumptions list.
"""

# ── Physical constants ───────────────────────────────────────────────────
SIGMA_SB = 5.670374419e-8       # Stefan-Boltzmann constant [W/(m^2 K^4)]
MU_EARTH_KM3_S2 = 398600.4418   # Earth gravitational parameter [km^3/s^2]
R_EARTH_KM = 6378.137           # Earth mean equatorial radius [km]

# ── Orbit (from the DVS report) ──────────────────────────────────────────
ORBIT_ALTITUDE_KM_DEFAULT = 600.0
ORBIT_INCLINATION_DEG_DEFAULT = 97.0   # non-sun-synchronous -> beta_orbit drifts over full range over life

# ── Solar / cell defaults ────────────────────────────────────────────────
G0_DEFAULT = 1367.0              # Reference (AM0) irradiance [W/m^2]
ETA_WIRING_DEFAULT = 0.98        # Harness/wiring efficiency [-]

# MPPT efficiency: previously implicitly 1.0 (ideal tracker). ESA reviewer's
# back-of-envelope check used 0.875 explicitly, separate from eta_wiring.
# TBC -- confirm against actual EPS/PCU datasheet.
ETA_MPPT_DEFAULT = 0.875

# Fixed worst-case cell temperature used in "fixed" thermal mode (see
# solar_power.py). Reviewer's expectation: CubeSat arrays under continuous
# barbecue-roll motion don't reach the instantaneous radiative-equilibrium
# peak (83.9 C in the old model) because no single face dwells at normal
# incidence long enough to equilibrate; they generally stay below 60 C.
# This is Option B from the review response (fixed worst-case temperature,
# chosen over building a transient lumped-capacitance thermal model).
FIXED_CELL_TEMP_C_DEFAULT = 60.0

# ── Battery / energy-budget placeholders (Section 5 of the review) ──────
# These are NOT real DVS hardware numbers. They exist only so the
# battery/energy-budget functions in battery.py are runnable end-to-end.
# TBC -- replace with actual EPS/battery-pack and CONOPS values before
# using these outputs for any real feasibility decision.
BATTERY_CAPACITY_WH_PLACEHOLDER = 10.0
BATTERY_DOD_LIMIT_PLACEHOLDER = 0.40      # max allowed depth-of-discharge [-]
BATTERY_INITIAL_SOC_PLACEHOLDER = 1.00    # state of charge at deployment [-]
P_LOAD_TUMBLE_W_PLACEHOLDER = 2.0         # bus load during detumble/safe mode [W]
P_LOAD_NOMINAL_W_PLACEHOLDER = 3.0        # bus load during nominal ops [W]
DETUMBLE_DURATION_S_PLACEHOLDER = 3 * 3600.0  # worst-case time to detumble [s]
