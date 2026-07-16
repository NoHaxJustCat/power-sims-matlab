"""Battery / energy-budget checks for the temporary-vs-continuous tumbling
question (Section 5 of the ESA review response).

The reviewer's top-level conclusion is that this distinction has to
structure the whole feasibility analysis:

  * TEMPORARY tumbling (only during de-tumble / safe-mode, then a nominal
    controlled attitude): size the battery against worst-case barbecue-roll
    power during the (short) tumbling phase, then separately check the
    energy budget under the nominal attitude.
  * CONTINUOUS tumbling (no detumble, tumbling throughout nominal ops):
    size the whole power budget against the worst-case barbecue-roll,
    eclipse-inclusive average power -- which may show the design doesn't
    close, and the analysis needs to say so plainly rather than hide it in
    an average number.

All P_load_w / battery_capacity_wh / duration values here are placeholders
(see constants.py) until EPS/ADCS provide real numbers -- treat the
pass/fail verdicts as illustrative of the *method*, not as a real
feasibility sign-off.
"""
from dataclasses import dataclass


@dataclass
class TemporaryTumblingResult:
    P_gen_w: float
    P_load_w: float
    net_power_w: float
    duration_s: float
    energy_delta_wh: float
    initial_soc: float
    final_soc: float
    dod_reached: float
    dod_limit: float
    battery_survives: bool


def temporary_tumbling_budget(
    P_gen_worst_w: float,
    P_load_w: float,
    battery_capacity_wh: float,
    dod_limit: float,
    initial_soc: float,
    duration_s: float,
) -> TemporaryTumblingResult:
    """Depth-of-discharge check across the (worst-case-power) de-tumble phase.

    Uses the worst-case, not average, barbecue-roll power, per the review:
    the battery has to survive the single worst continuous stretch, not
    just the phase-averaged deficit.
    """
    net_power_w = P_gen_worst_w - P_load_w
    energy_delta_wh = net_power_w * duration_s / 3600.0

    final_soc = initial_soc + energy_delta_wh / battery_capacity_wh
    dod_reached = max(0.0, initial_soc - final_soc)
    survives = (final_soc >= (1.0 - dod_limit)) and (final_soc >= 0.0)

    return TemporaryTumblingResult(
        P_gen_worst_w, P_load_w, net_power_w, duration_s, energy_delta_wh,
        initial_soc, final_soc, dod_reached, dod_limit, survives,
    )


@dataclass
class OrbitAverageBudgetResult:
    P_gen_w: float
    P_load_w: float
    margin_w: float
    feasible: bool


def orbit_average_budget(P_gen_w: float, P_load_w: float) -> OrbitAverageBudgetResult:
    """Simple positive-margin check: does average generation cover average load?

    Used both for the nominal (post-detumble) attitude in the temporary-
    tumbling case, and for the continuous-tumbling worst-case-average case.
    """
    margin_w = P_gen_w - P_load_w
    return OrbitAverageBudgetResult(P_gen_w, P_load_w, margin_w, margin_w >= 0.0)
