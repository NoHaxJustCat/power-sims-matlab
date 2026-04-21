function [cell_params, panel_config] = cubesat_simple()




% ── Cell electrical parameters (BOL, AM0, 28°C) ─────────────────────────
% Cell:      AzurSpace TJ 3G30-Advanced (4x8)
% Datasheet: https://www.azurspace.com/media/uploads/file_links/file/bdb_00010891-01-00_tj3g30-advanced_4x8.pdf


% rough estimate for fluence (SPENVIS would be better, but this is just a conservative guess)

% Total trapped electron fluence from SPENVIS for 2 years
mission_fluence  = 3.706e+12; % [e/cm²]
fluence_table = [0, 5e13, 2.5e14, 5e14, 1e15, 1e16];

% Cell values only (not CIC)
Vmp_table = [2411, 2336, 2298, 2262, 2230, 2127] * 1e-3;  % [V]
Imp_table = [504,  501,  500,  498,  484,  360 ] * 1e-3;  % [A]

Vmp_eol = interp1(fluence_table, Vmp_table, mission_fluence, 'pchip');
Imp_eol = interp1(fluence_table, Imp_table, mission_fluence, 'pchip');

% Typical temperature coefficients vs fluence (BOL, 2.5e14, 5e14, 1e15)
fluence_tc_table = [0, 2.5e14, 5e14, 1e15];
dVdT_table = [-6.7, -6.8, -7.1, -7.2] * 1e-3;  % [V/degC]
dIdT_table = [ 0.24, 0.20, 0.24, 0.28] * 1e-3; % [A/degC]

dVdT_eol = interp1(fluence_tc_table, dVdT_table, mission_fluence, 'pchip', 'extrap');
dIdT_eol = interp1(fluence_tc_table, dIdT_table, mission_fluence, 'pchip', 'extrap');

cell_params.Vmp0 = Vmp_eol;   % already EOL
cell_params.Imp0 = Imp_eol;   % already EOL
cell_params.LDEF = 1.0;       % radiation already encoded above
                               % keep LDEF for other degradation if needed
% cell_params.Vmp0 = 2.411;       % MPP voltage              [V]
% cell_params.Imp0 = 0.504;       % MPP current              [A]
cell_params.dVdT = dVdT_eol;    % Vmp temperature coeff    [V/°C]
cell_params.dIdT = dIdT_eol;    % Imp temperature coeff    [A/°C]
cell_params.Tref = 28;          % Reference temperature    [°C]
cell_params.G0   = 1367;        % Reference irradiance     [W/m²]

cell_params.alpha_cell  = 0.60;   % Solar absorptance, cell   [-]
cell_params.eps_cell    = 0.89;   % IR emissivity if cover glass, taken from lecture materials (AE4901)       [-]

% ── Face geometry ────────────────────────────────────────────────────────
% 2U CDS dimensions SPF 3.8
A_side = 100e-3 * 227e-3;    % ±X, ±Y face area   [m²]
A_top  = 100e-3 * 100e-3;      % ±Z face area        [m²]

% Azur Space 3G30C cell area
A_1cell = 30.18e-4;             % single cell area   [m²]
n_cells_per_face = 2;

% ── Panel configuration ──────────────────────────────────────────────────
face_labels   = {'+X',        '-X',        '+Y',        '-Y',        '+Z',       '-Z'      };
n_cells_vec   = [  2,           2,           2,           2,           2,          0        ];
n_strings_vec = [  2,           2,           1,           2,           1,          0        ];
face_area_vec = [A_side,       A_side,       A_side,       A_side,       A_top,       A_top       ];
A_cell_vec    = face_area_vec .* n_cells_vec;
eta_wiring    = 0.98;

panel_config = struct([]);
for i = 1:numel(face_labels)
    panel_config(i).face       = face_labels{i};
    panel_config(i).n_cells    = n_cells_vec(i);
    panel_config(i).n_strings  = n_strings_vec(i);
    panel_config(i).eta_wiring = eta_wiring;
    panel_config(i).A_cell     = A_cell_vec(i);
end

end