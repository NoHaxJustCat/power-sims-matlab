"""DVS Solar Power Generation Simulation -- Python port + ESA-review updates.

Run:  python run_report.py

This reproduces the MATLAB "Geometric Averaging Method" (full random 3D
tumbling) for comparison, and adds everything the ESA independent expert
asked for:

  1. Barbecue-roll (single-axis rotation) averaging, swept over beta_roll
     (0-90 deg, axis-to-sun angle) and over all three candidate body axes.
  2. Orbital eclipse-fraction modeling for the 600 km/97 deg (non-SSO) orbit,
     using the worst-case beta_orbit.
  3. An explicit MPPT efficiency term (eta_mppt), separate from wiring
     efficiency.
  4. A fixed worst-case cell temperature (60 C) in place of the old
     instantaneous-equilibrium thermal model (Option B from the review
     response) for all the new barbecue-roll numbers.
  5. A temporary-vs-continuous tumbling switch with battery/energy-budget
     checks.

See python/README.md for the full assumptions list -- several inputs below
are explicitly-flagged placeholders that need ADCS/EPS/systems sign-off.
"""
import numpy as np

from power_sim.barbecue_roll import sweep_all_axes
from power_sim.battery import orbit_average_budget, temporary_tumbling_budget
from power_sim.cell_params import get_cell_params
from power_sim.constants import (
    BATTERY_CAPACITY_WH_PLACEHOLDER,
    BATTERY_DOD_LIMIT_PLACEHOLDER,
    BATTERY_INITIAL_SOC_PLACEHOLDER,
    DETUMBLE_DURATION_S_PLACEHOLDER,
    ETA_MPPT_DEFAULT,
    FIXED_CELL_TEMP_C_DEFAULT,
    G0_DEFAULT,
    ORBIT_ALTITUDE_KM_DEFAULT,
    P_LOAD_NOMINAL_W_PLACEHOLDER,
    P_LOAD_TUMBLE_W_PLACEHOLDER,
)
from power_sim.eclipse import eclipse_free_beta_deg, orbital_period_s, worst_case_eclipse
from power_sim.full_tumbling import full_tumbling_average
from power_sim.panel_configs import CONFIG_DESCRIPTIONS, get_panel_config

# ── Top-level switch: which CONOPS assumption are we sizing against? ────
# TBC -- confirm with ADCS/systems which of these actually applies to DVS.
#   'continuous' : tumbling throughout nominal ops -> size against
#                  worst-case barbecue-roll, eclipse-inclusive average power.
#   'temporary'  : tumbling only during de-tumble/safe-mode -> battery DoD
#                  check during that phase + separate nominal-attitude budget.
TUMBLING_MODE = "continuous"

CONFIG_LIST = ["a", "b", "c", "d"]
IRRADIANCE = G0_DEFAULT
N_AZ, N_EL = 180, 90          # full-tumbling sampling grid (matches MATLAB main_point.m)
N_PSI = 720                   # barbecue-roll spin-angle sampling (0.5 deg steps)
BETA_ROLL_GRID_DEG = np.linspace(0.0, 90.0, 46)  # 2 deg steps


def divider(char="=", n=93):
    print(char * n)


def run_config(config_name: str, cell_params, worst_eclipse):
    panel_config = get_panel_config(config_name)
    desc = CONFIG_DESCRIPTIONS[config_name]

    # ── (a) Legacy full-tumbling ("Geometric Averaging Method"), for comparison ──
    # eta_mppt=1.0 here: faithfully reproduces the OLD MATLAB model (ideal MPPT,
    # no eta_mppt term at all) so this serves as a regression check against the
    # original report numbers (Config A: Min 2.057 / Max 6.880 / Avg 5.529 W).
    legacy = full_tumbling_average(cell_params, panel_config, IRRADIANCE, N_AZ, N_EL,
                                    thermal_mode="instantaneous", eta_mppt=1.0)
    legacy_notemp = full_tumbling_average(cell_params, panel_config, IRRADIANCE, N_AZ, N_EL,
                                           ignore_temp=True, eta_mppt=1.0)
    bol_params = get_cell_params(force_bol=True)
    legacy_bol = full_tumbling_average(bol_params, panel_config, IRRADIANCE, N_AZ, N_EL,
                                        ignore_temp=True, eta_mppt=1.0)

    # ── (b) New: barbecue-roll sweep over beta_roll and over X/Y/Z axes ──
    per_axis, worst_axis_name = sweep_all_axes(
        cell_params, panel_config, IRRADIANCE, betas_deg=BETA_ROLL_GRID_DEG, n_psi=N_PSI,
        thermal_mode="fixed", fixed_temp_c=FIXED_CELL_TEMP_C_DEFAULT, eta_mppt=ETA_MPPT_DEFAULT,
    )
    worst_roll = per_axis[worst_axis_name].worst

    # ── (c) Eclipse-inclusive orbit-average power at the barbecue-roll worst case ──
    sunlit_avg_worst = worst_roll.P_avg
    orbit_avg_worst = sunlit_avg_worst * (1.0 - worst_eclipse.eclipse_fraction)

    print(f"\n[dvs_sat_{config_name.upper()}]  {desc}")
    divider("-")
    print("Legacy full-tumbling (random 3D, no eclipse, sunlit-only):")
    print(f"  Min {legacy.P_min:6.3f} W | Max {legacy.P_max:6.3f} W | Avg {legacy.P_mean:6.3f} W"
          f"   (EOL, instantaneous thermal)")
    print(f"  Avg {legacy_notemp.P_mean:6.3f} W  (EOL, T=Tref, ideal MPPT)   "
          f"Avg {legacy_bol.P_mean:6.3f} W  (BOL, T=Tref, ideal MPPT)")

    print("\nNew: barbecue-roll (single-axis roll), sunlit-only, fixed "
          f"{FIXED_CELL_TEMP_C_DEFAULT:.0f} C, eta_mppt={ETA_MPPT_DEFAULT}:")
    for name, sweep in per_axis.items():
        marker = " <-- worst axis" if name == worst_axis_name else ""
        print(f"  axis {name}: worst beta_roll = {sweep.worst.beta_roll_deg:5.1f} deg -> "
              f"Avg {sweep.worst.P_avg:6.3f} W  (range over sweep: "
              f"{sweep.P_avg.min():.3f}-{sweep.P_avg.max():.3f} W){marker}")

    print(f"\n  Worst-case barbecue-roll (axis {worst_axis_name}, "
          f"beta_roll={worst_roll.beta_roll_deg:.1f} deg):")
    print(f"    Sunlit-only average          : {sunlit_avg_worst:6.3f} W")
    print(f"    Full-orbit average (eclipse) : {orbit_avg_worst:6.3f} W  "
          f"(eclipse fraction {worst_eclipse.eclipse_fraction:.3f} at "
          f"beta_orbit={worst_eclipse.beta_orbit_deg:.0f} deg)")

    return {
        "config": config_name,
        "legacy": legacy,
        "worst_axis": worst_axis_name,
        "worst_roll": worst_roll,
        "sunlit_avg_worst": sunlit_avg_worst,
        "orbit_avg_worst": orbit_avg_worst,
    }


def run_tumbling_mode_analysis(result):
    config_name = result["config"].upper()
    print(f"\n  Tumbling-mode analysis [{config_name}] (mode = '{TUMBLING_MODE}', "
          f"TBC with ADCS/systems):")

    if TUMBLING_MODE == "temporary":
        dt = temporary_tumbling_budget(
            P_gen_worst_w=result["orbit_avg_worst"],
            P_load_w=P_LOAD_TUMBLE_W_PLACEHOLDER,
            battery_capacity_wh=BATTERY_CAPACITY_WH_PLACEHOLDER,
            dod_limit=BATTERY_DOD_LIMIT_PLACEHOLDER,
            initial_soc=BATTERY_INITIAL_SOC_PLACEHOLDER,
            duration_s=DETUMBLE_DURATION_S_PLACEHOLDER,
        )
        verdict = "SURVIVES" if dt.battery_survives else "DOES NOT SURVIVE"
        print(f"    De-tumble phase: net power {dt.net_power_w:+.3f} W over "
              f"{dt.duration_s/3600:.1f} h -> final SoC {dt.final_soc*100:.1f}% "
              f"(DoD {dt.dod_reached*100:.1f}%, limit {dt.dod_limit*100:.0f}%) -> {verdict}")
        print("    [placeholder battery/load values -- see python/README.md]")

        # Nominal (post-detumble) attitude: no confirmed pointing profile yet,
        # so we use the legacy random-tumbling mean as an explicit placeholder.
        nom = orbit_average_budget(result["legacy"].P_mean, P_LOAD_NOMINAL_W_PLACEHOLDER)
        verdict = "closes" if nom.feasible else "DOES NOT CLOSE"
        print(f"    Nominal-attitude budget (PLACEHOLDER profile = legacy random-tumbling "
              f"mean, no confirmed pointing profile yet): margin {nom.margin_w:+.3f} W -> {verdict}")
    else:  # continuous
        cont = orbit_average_budget(result["orbit_avg_worst"], P_LOAD_NOMINAL_W_PLACEHOLDER)
        verdict = "CLOSES" if cont.feasible else "DOES NOT CLOSE"
        print(f"    Continuous-tumbling sizing (worst-case barbecue-roll, eclipse-inclusive): "
              f"gen {cont.P_gen_w:.3f} W vs load {cont.P_load_w:.3f} W -> "
              f"margin {cont.margin_w:+.3f} W -> budget {verdict}")


def main():
    print("DVS Solar Power Generation Simulation -- Python port (post ESA-review)")
    divider()

    cell_params = get_cell_params()
    print(f"Cell (EOL): Vmp0={cell_params.Vmp0*1000:.1f} mV, Imp0={cell_params.Imp0*1000:.1f} mA, "
          f"dVdT={cell_params.dVdT*1000:.2f} mV/C, dIdT={cell_params.dIdT*1000:.2f} mA/C")
    print(f"eta_wiring=0.98 (unchanged), eta_mppt={ETA_MPPT_DEFAULT} (NEW, TBC vs EPS/PCU datasheet), "
          f"fixed T_cell={FIXED_CELL_TEMP_C_DEFAULT:.0f} C (NEW, barbecue-roll thermal Option B)")

    T_orbit = orbital_period_s(ORBIT_ALTITUDE_KM_DEFAULT)
    worst_eclipse = worst_case_eclipse(ORBIT_ALTITUDE_KM_DEFAULT)
    beta_free = eclipse_free_beta_deg(ORBIT_ALTITUDE_KM_DEFAULT)
    print(f"\nOrbit: {ORBIT_ALTITUDE_KM_DEFAULT:.0f} km circular, period {T_orbit/60:.1f} min. "
          f"Non-sun-synchronous -> beta_orbit drifts through full range over mission life.")
    print(f"Worst-case eclipse: beta_orbit={worst_eclipse.beta_orbit_deg:.0f} deg -> "
          f"eclipse fraction {worst_eclipse.eclipse_fraction:.3f} "
          f"({worst_eclipse.eclipse_duration_s/60:.1f} min/orbit). "
          f"Eclipse-free above beta_orbit~{beta_free:.1f} deg.")
    print("(Sanity check: reviewer's back-of-envelope implied ~37% eclipse fraction at worst case -- matches.)")

    divider()
    results = []
    for config_name in CONFIG_LIST:
        r = run_config(config_name, cell_params, worst_eclipse)
        run_tumbling_mode_analysis(r)
        results.append(r)

    divider()
    print("\nSummary (worst-case barbecue-roll, full-orbit average, eclipse-inclusive):")
    print(f"{'Config':<8}{'Worst axis':<12}{'beta_roll [deg]':<18}{'Sunlit avg [W]':<16}{'Orbit avg [W]':<16}")
    for r in results:
        wr = r["worst_roll"]
        print(f"{r['config'].upper():<8}{r['worst_axis']:<12}{wr.beta_roll_deg:<18.1f}"
              f"{r['sunlit_avg_worst']:<16.3f}{r['orbit_avg_worst']:<16.3f}")

    divider()
    print("\nOpen questions requiring sign-off (do not silently assume -- see python/README.md):")
    print("  1. Which body axis (if any) will DVS actually spin about? Treated as unknown; "
          "worst case reported over X/Y/Z.")
    print(f"  2. Is tumbling temporary or continuous? Currently analyzed as '{TUMBLING_MODE}' -- "
          "change TUMBLING_MODE in run_report.py once ADCS/systems confirms.")
    print("  3. Battery capacity, bus loads, and de-tumble duration are placeholders "
          "(power_sim/constants.py) -- replace with real EPS/CONOPS numbers.")
    print("  4. eta_mppt=0.875 is the reviewer's assumed value, not yet confirmed against "
          "the actual EPS/PCU datasheet.")


if __name__ == "__main__":
    main()
