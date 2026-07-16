"""AZUR SPACE TJ 3G30-Advanced III-V triple-junction cell electrical/optical
parameters, ported from lib/dvs_sat_a.m..dvs_sat_d.m (identical cell block
in all four MATLAB config files).

Datasheet: https://www.azurspace.com/media/uploads/file_links/file/bdb_00010891-01-00_tj3g30-advanced_4x8.pdf
"""
from dataclasses import dataclass

from .constants import G0_DEFAULT
from .interpolation import pchip_eval

# Total trapped-electron fluence from SPENVIS for the 2-year mission
# (rough conservative estimate -- SPENVIS run would be more accurate).
MISSION_FLUENCE_DEFAULT = 3.706e12  # [e/cm^2]

_FLUENCE_TABLE = [0, 5e13, 2.5e14, 5e14, 1e15, 1e16]
_VMP_TABLE_V = [2411e-3, 2336e-3, 2298e-3, 2262e-3, 2230e-3, 2127e-3]
_IMP_TABLE_A = [504e-3, 501e-3, 500e-3, 498e-3, 484e-3, 360e-3]

_FLUENCE_TC_TABLE = [0, 2.5e14, 5e14, 1e15]
_DVDT_TABLE_V_C = [-6.7e-3, -6.8e-3, -7.1e-3, -7.2e-3]
_DIDT_TABLE_A_C = [0.24e-3, 0.20e-3, 0.24e-3, 0.28e-3]

VMP0_BOL_V = 2.411
IMP0_BOL_A = 0.504
DVDT_BOL_V_C = -6.7e-3
DIDT_BOL_A_C = 0.24e-3

TREF_C = 28.0
ALPHA_CELL = 0.60   # solar absorptance, cell + coverglass [-]
EPS_CELL = 0.89     # IR emissivity, coverglass [-] (AE4901 lecture material)


@dataclass
class CellParams:
    Vmp0: float          # MPP voltage at Tref, given fluence [V]
    Imp0: float          # MPP current at Tref, given fluence [A]
    dVdT: float          # Vmp temperature coefficient [V/C]
    dIdT: float          # Imp temperature coefficient [A/C]
    Tref: float = TREF_C
    LDEF: float = 1.0    # extra lifetime-degradation factor (radiation already in Vmp0/Imp0)
    G0: float = G0_DEFAULT
    alpha_cell: float = ALPHA_CELL
    eps_cell: float = EPS_CELL


def get_cell_params(mission_fluence=MISSION_FLUENCE_DEFAULT, force_bol=False):
    """End-of-life (default) or beginning-of-life cell electrical parameters.

    mission_fluence < 0 disables the EOL correction (LDEF-only degradation is
    not modeled here since it's folded into Vmp0/Imp0, matching the MATLAB
    source's `LDEF = 1.0  % radiation already encoded above`).
    """
    if force_bol:
        return CellParams(Vmp0=VMP0_BOL_V, Imp0=IMP0_BOL_A,
                           dVdT=DVDT_BOL_V_C, dIdT=DIDT_BOL_A_C)

    vmp0 = pchip_eval(_FLUENCE_TABLE, _VMP_TABLE_V, mission_fluence)
    imp0 = pchip_eval(_FLUENCE_TABLE, _IMP_TABLE_A, mission_fluence)
    dvdt = pchip_eval(_FLUENCE_TC_TABLE, _DVDT_TABLE_V_C, mission_fluence)
    didt = pchip_eval(_FLUENCE_TC_TABLE, _DIDT_TABLE_A_C, mission_fluence)

    return CellParams(Vmp0=vmp0, Imp0=imp0, dVdT=dvdt, dIdT=didt)
