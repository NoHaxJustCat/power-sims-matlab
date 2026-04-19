function [cell_params, panel_config] = cubesat_simple()
%CUBESAT_SIMPLE  Parameters for a simple 1U CubeSat with 2x Azur Space 3G30C
%                cells per face, all 6 faces active.
%
%  Cell:    Azur Space 3G30C, 40x80 mm, A = 30.18 cm²
%  Frame:   1U CubeSat, Al 6061
%  Layout:  2 cells per face, 1 string per face

% ── Cell electrical parameters (BOL, AM0, 28°C) ─────────────────────────
cell_params.Vmp0 = 2.411;       % MPP voltage              [V]
cell_params.Imp0 = 0.504;       % MPP current              [A]
cell_params.dVdT = -6.7e-3;    % Vmp temperature coeff    [V/°C]
cell_params.dIdT =  0.24e-3;   % Imp temperature coeff    [A/°C]
cell_params.Tref = 28;          % Reference temperature    [°C]
cell_params.LDEF = 0.95;        % Lifetime degradation     [-]
cell_params.G0   = 1367;        % Reference irradiance     [W/m²]

% ── Optical properties ───────────────────────────────────────────────────
% Azur Space 3G30C
cell_params.alpha_cell  = 0.91;   % Solar absorptance, cell   [-]
cell_params.eps_cell    = 0.85;   % IR emissivity, cell       [-]

% ── Face geometry ────────────────────────────────────────────────────────
% 1U CDS dimensions
A_side = 100e-3 * 113.5e-3;    % ±X, ±Y face area   [m²]
A_top  = 100e-3 * 100e-3;      % ±Z face area        [m²]

% Azur Space 3G30C cell area
A_1cell = 30.18e-4;             % single cell area   [m²]
n_cells_per_face = 2;

A_cell_side  = n_cells_per_face * A_1cell;
A_cell_top   = n_cells_per_face * A_1cell;

% ── Panel configuration ──────────────────────────────────────────────────
face_labels   = {'+X',        '-X',        '+Y',        '-Y',        '+Z',       '-Z'      };
n_cells_vec   = [  2,           2,           2,           2,           2,          2        ];
n_strings_vec = [  1,           1,           1,           1,           1,          1        ];
A_cell_vec    = [A_cell_side,  A_cell_side,  A_cell_side,  A_cell_side,  A_cell_top,  A_cell_top  ];
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