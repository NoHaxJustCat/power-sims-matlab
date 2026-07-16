# DVS Solar Power Generation Simulation — Python port

Python re-implementation of the MATLAB simulation in `../lib` and `../main_point.m`
/ `../main_axis.m`, extended to address the ESA independent expert's review
comments on the Solar Power Generation report. Code only — the written report
is not touched here.

## Running it

```
pip install -r requirements.txt
python run_report.py      # console summary for all four configs (A-D)
python plot_report.py     # optional: writes results/barbecue_roll_sweep.png, results/eclipse_fraction.png
```

No MATLAB/scipy dependency — PCHIP interpolation for the EOL fluence tables
is reimplemented in `power_sim/interpolation.py` (numpy only) since scipy
isn't installed in this environment; only numpy (+ matplotlib for the
optional plots) are required.

## What changed vs. the MATLAB source, and why

### 1. Barbecue-roll averaging (new), full-tumbling kept for comparison
`power_sim/barbecue_roll.py` adds single-axis-rotation averaging,
parameterized by roll axis and `beta_roll` (angle between roll axis and sun
direction). For a given axis/beta_roll it numerically averages the reused
per-attitude power model (`solar_power.py`, physics unchanged) over one full
spin, `cos(theta)`-clipped at zero per face — no hardcoded `beta_roll = 90°`
special case.

`beta_roll` is swept 0–90° for **each of the three body axes** (X, Y, Z),
since we don't have ADCS confirmation of which axis DVS will actually spin
about. The worst case across axis and beta_roll is reported per
configuration (A–D).

**Finding, verified numerically, not assumed:** the worst case is
*not* `beta_roll = 90°`. For every configuration the minimum average power
occurs at **`beta_roll = 0°`** (roll axis pointed straight at the sun — only
the two axis-aligned faces are ever lit, and if that pair happens to be a
2-cell face, that beats out the 90° case badly). The *maximum* also isn't at
90°; it peaks somewhere around 55–70° depending on axis and configuration.
See `results/barbecue_roll_sweep.png` after running `plot_report.py`.

The legacy full-tumbling ("Geometric Averaging Method", full random 3D
sphere sampling, `power_sim/full_tumbling.py`) is kept side-by-side, not
replaced, so the two methods can be directly compared. With `eta_mppt=1.0`
and the original instantaneous-thermal model it reproduces the old report's
Config A numbers exactly (Min 2.057 / Max 6.880 / Avg 5.529 W — run
`run_report.py` and check the "Legacy full-tumbling" line).

**Open question (flagged, not assumed):** which body axis DVS will actually
spin about — or whether it's genuinely unconstrained — needs ADCS sign-off.
Until then, treat the worst-axis result as the conservative sizing case.

### 2. Eclipse modeling (new)
`power_sim/eclipse.py` adds a standard cylindrical (no-penumbra) Earth-shadow
eclipse-fraction model for a circular orbit, as a function of the **orbital**
beta angle `beta_orbit` (angle between orbit plane and sun vector — distinct
from the **attitude** `beta_roll` above; the names are deliberately
different to avoid conflating the two).

```
f_eclipse(beta_orbit) = (1/pi) * arccos( sqrt(1-(R_E/r)^2) / cos(beta_orbit) )
```

For the 600 km/97° (non-sun-synchronous) orbit this gives a worst case at
`beta_orbit = 0°`: eclipse fraction ≈ **0.367** (orbit period ≈ 96.7 min,
so ≈ 35.5 min of eclipse per orbit) — this matches the ≈37% the reviewer's
own back-of-envelope check implied. Eclipse-free above `beta_orbit ≈ 66°`.
Because the orbit is non-SSO, `beta_orbit` drifts through the full 0–90°
range over the mission life rather than holding a favorable value, so the
worst case has to be carried in the budget, not treated as a rare event.

`run_report.py` reports both the sunlit-only average and the
`(1 - eclipse_fraction)`-scaled full-orbit average for the worst-case
barbecue-roll condition.

### 3. Explicit MPPT efficiency (new)
`solar_power_output()` (`power_sim/solar_power.py`) now takes `eta_mppt`,
multiplied in alongside the existing `eta_wiring` (`P_face = Vmp*Imp*n_cells
*n_strings*eta_wiring*eta_mppt`), instead of implicitly assuming a
100%-efficient tracker. Default **0.875** (`power_sim/constants.py`),
matching the reviewer's own check.

**TBC — confirm against the actual EPS/PCU datasheet.** 0.875 is the
reviewer's assumed value, not a DVS-hardware-specific number.

### 4. Thermal model: fixed worst-case temperature (Option B)
Rather than build a transient lumped-capacitance thermal solver, the new
barbecue-roll/continuous-tumbling numbers use a **fixed worst-case cell
temperature of 60°C** (`FIXED_CELL_TEMP_C_DEFAULT`, `power_sim/constants.py`)
for every illuminated face, per the reviewer's own expectation for CubeSat
arrays under continuous roll motion (no face dwells long enough to reach the
old model's ~84°C instantaneous radiative equilibrium).

The original instantaneous per-attitude radiative-equilibrium model is
*not* deleted — it's still available as `thermal_mode='instantaneous'` in
`solar_power_output()` / `full_tumbling_average()`, used for the
legacy-method regression check against the old report. `thermal_mode='fixed'`
is what the new barbecue-roll functions use by default.

**Preserved (not fixed) quirk from the MATLAB source:** the thermal-balance
area for each face is `face_area * n_cells`, which does *not* multiply by
`n_strings` — so it under-counts the absorbing/emitting area on faces with
`n_strings > 1` relative to the number of cells actually generating power on
that face. This is inherited from `lib/dvs_sat_*.m` for a faithful port; it
mostly stops mattering once you're on the fixed-temperature thermal mode,
but is worth knowing about if you revive the instantaneous-thermal path.

### 5. Temporary vs. continuous tumbling (new)
`run_report.py` has a top-level `TUMBLING_MODE` switch (`'continuous'` or
`'temporary'`), and `power_sim/battery.py` implements both budget checks:

* **Temporary** (tumbling only during de-tumble/safe-mode):
  `temporary_tumbling_budget()` checks depth-of-discharge across the
  de-tumble phase using the **worst-case** (not average) barbecue-roll,
  eclipse-inclusive power, then `orbit_average_budget()` separately checks
  the nominal (post-detumble) attitude — currently using the legacy
  random-tumbling mean as an explicit **placeholder** profile, since we
  don't have a real nominal pointing profile yet.
* **Continuous** (tumbling throughout nominal ops): sizes the whole budget
  against the worst-case barbecue-roll, eclipse-inclusive **average** power,
  and prints a plain CLOSES/DOES NOT CLOSE verdict rather than burying it in
  an average number.

Currently defaults to `'continuous'` (the more conservative assumption) —
**this needs ADCS/systems confirmation**, not a code default. With
`'continuous'` and the placeholder 3 W nominal load, the budget does **not
close** for any of the four configurations (worst-case orbit-average power
≈1.2 W vs. a 3 W placeholder load) — treat the *method* as validated, the
verdict itself as illustrative until real load numbers go in.

## Placeholder values (flagged `_PLACEHOLDER` in `power_sim/constants.py`)

None of these are real DVS hardware/CONOPS numbers — they only exist so the
battery/energy-budget code is runnable end-to-end:

| Constant | Placeholder value | Needed from |
|---|---|---|
| `BATTERY_CAPACITY_WH_PLACEHOLDER` | 10.0 Wh | EPS |
| `BATTERY_DOD_LIMIT_PLACEHOLDER` | 0.40 | EPS / battery datasheet |
| `BATTERY_INITIAL_SOC_PLACEHOLDER` | 1.00 | CONOPS |
| `P_LOAD_TUMBLE_W_PLACEHOLDER` | 2.0 W | EPS / systems (safe-mode bus load) |
| `P_LOAD_NOMINAL_W_PLACEHOLDER` | 3.0 W | EPS / systems (nominal bus load) |
| `DETUMBLE_DURATION_S_PLACEHOLDER` | 3 h | ADCS (worst-case detumble time) |

## Open questions (flagged to the user, not silently assumed)

1. **Roll axis**: is there a preferred/likely spin axis from the ADCS
   design, or is it genuinely unconstrained? Currently reported as a
   worst-case sweep over X/Y/Z.
2. **Temporary vs. continuous tumbling**: which applies to DVS's actual
   CONOPS? Drives which analysis in Section 5 is the primary feasibility
   sizing case. Currently defaulted to `'continuous'` in `run_report.py`.
3. The reviewer's "Section 3.3" (continuous tumbling) doesn't appear in the
   report as currently held — may be a different document (e.g. an
   ADCS/attitude report) that should be cross-checked for consistency.
4. Real MPPT/PCU hardware and its datasheet efficiency, if different from
   the 0.875 placeholder.
5. Real battery capacity, bus loads, and de-tumble duration (table above).

## Module map

| File | Purpose |
|---|---|
| `power_sim/constants.py` | Physical constants + flagged placeholder/TBC parameters |
| `power_sim/interpolation.py` | Dependency-free PCHIP (replaces MATLAB `interp1(...,'pchip')`) |
| `power_sim/cell_params.py` | AZUR SPACE TJ 3G30-Advanced EOL/BOL electrical parameters |
| `power_sim/panel_configs.py` | Configs A–D face geometry (ported from `lib/dvs_sat_a.m`..`d.m`) |
| `power_sim/solar_power.py` | Per-attitude power/temperature model (ported from `lib/solar_power_output.m`) + `eta_mppt` + fixed-temperature thermal mode |
| `power_sim/eclipse.py` | Orbital eclipse-fraction model (new) |
| `power_sim/barbecue_roll.py` | Barbecue-roll averaging + beta_roll/axis sweep (new) |
| `power_sim/full_tumbling.py` | Legacy full random-3D-tumbling averaging (ported, kept for comparison) |
| `power_sim/battery.py` | Temporary/continuous tumbling battery & energy-budget checks (new) |
| `run_report.py` | Main driver — console summary for all four configs |
| `plot_report.py` | Optional plots (barbecue-roll sweep, eclipse fraction vs beta_orbit) |
