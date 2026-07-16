"""Generate summary plots for the barbecue-roll sweep and eclipse-fraction
model. Optional -- run_report.py's console output is the primary deliverable.

Run:  python plot_report.py
Output: python/results/barbecue_roll_sweep.png, python/results/eclipse_fraction.png
"""
import os

import matplotlib.pyplot as plt
import numpy as np

from power_sim.barbecue_roll import sweep_all_axes
from power_sim.cell_params import get_cell_params
from power_sim.constants import ETA_MPPT_DEFAULT, FIXED_CELL_TEMP_C_DEFAULT, G0_DEFAULT, ORBIT_ALTITUDE_KM_DEFAULT
from power_sim.eclipse import eclipse_fraction
from power_sim.panel_configs import CONFIG_DESCRIPTIONS, get_panel_config

OUT_DIR = os.path.join(os.path.dirname(__file__), "results")
os.makedirs(OUT_DIR, exist_ok=True)

CONFIG_LIST = ["a", "b", "c", "d"]
BETA_ROLL_GRID_DEG = np.linspace(0.0, 90.0, 46)


def plot_barbecue_sweep():
    cell_params = get_cell_params()
    fig, axes = plt.subplots(2, 2, figsize=(11, 8), sharex=True, sharey=True)

    for ax, config_name in zip(axes.flat, CONFIG_LIST):
        panel_config = get_panel_config(config_name)
        per_axis, worst_axis_name = sweep_all_axes(
            cell_params, panel_config, G0_DEFAULT, betas_deg=BETA_ROLL_GRID_DEG,
            thermal_mode="fixed", fixed_temp_c=FIXED_CELL_TEMP_C_DEFAULT, eta_mppt=ETA_MPPT_DEFAULT,
        )
        for name, sweep in per_axis.items():
            style = "-o" if name == worst_axis_name else "--"
            ax.plot(sweep.betas_deg, sweep.P_avg, style, markersize=3, label=f"axis {name}")
        ax.set_title(f"{config_name.upper()}: {CONFIG_DESCRIPTIONS[config_name]}")
        ax.grid(True, alpha=0.3)
        ax.legend(fontsize=8)

    for ax in axes[-1, :]:
        ax.set_xlabel("beta_roll [deg] (roll axis to sun)")
    for ax in axes[:, 0]:
        ax.set_ylabel("Sunlit-only average power [W]")

    fig.suptitle(f"Barbecue-roll average power vs beta_roll (fixed {FIXED_CELL_TEMP_C_DEFAULT:.0f} C, "
                 f"eta_mppt={ETA_MPPT_DEFAULT}) -- worst case is NOT always beta_roll=90 deg")
    fig.tight_layout()
    out_path = os.path.join(OUT_DIR, "barbecue_roll_sweep.png")
    fig.savefig(out_path, dpi=150)
    print(f"Saved {out_path}")


def plot_eclipse_fraction():
    betas = np.linspace(0, 90, 181)
    fracs = [eclipse_fraction(b, ORBIT_ALTITUDE_KM_DEFAULT) for b in betas]

    fig, ax = plt.subplots(figsize=(7, 5))
    ax.plot(betas, fracs, "-")
    ax.set_xlabel("beta_orbit [deg] (orbit plane to sun)")
    ax.set_ylabel("Eclipse fraction of orbital period [-]")
    ax.set_title(f"Eclipse fraction vs beta_orbit, {ORBIT_ALTITUDE_KM_DEFAULT:.0f} km circular orbit\n"
                 "(non-SSO -> beta_orbit drifts through this full range over mission life)")
    ax.grid(True, alpha=0.3)
    fig.tight_layout()
    out_path = os.path.join(OUT_DIR, "eclipse_fraction.png")
    fig.savefig(out_path, dpi=150)
    print(f"Saved {out_path}")


if __name__ == "__main__":
    plot_barbecue_sweep()
    plot_eclipse_fraction()
