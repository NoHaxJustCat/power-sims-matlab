function [total_power, face_power, face_info] = solar_power_output(sun_vector, irradiance, cell_params, panel_config)
% SOLAR_POWER_OUTPUT  Compute electrical power from body-mounted solar cells
%                     using Maximum Power Point parameters (Vmp, Imp).
%
% Syntax:
%   [total_power, face_power, face_info] = solar_power_output(sun_vector, irradiance, cell_params, panel_config)
%
% -------------------------------------------------------------------------
% Inputs:
%   sun_vector   - [3×1] Sun direction in spacecraft body frame,
%                  pointing FROM spacecraft TOWARD the Sun. Need not be unit.
%
%   irradiance   - Solar irradiance [W/m²]. Use 1367 W/m² (AM0) at 1 AU.
%
%   cell_params  - Struct of solar-cell MPP parameters:
%
%       REQUIRED:
%       .Vmp0    MPP voltage at STC                         [V]
%       .Imp0    MPP current at STC  (total cell current,   [A]
%                NOT current density — read directly from datasheet)
%
%       TEMPERATURE COEFFICIENTS (absolute, per °C):
%       .dVdT    dVmp/dT — typically negative               [V/°C]
%       .dIdT    dImp/dT — typically small positive         [A/°C]
%
%       OPTIONAL:
%       .Tref    Reference temperature for STC              [°C]   default 28
%       .T       Operating cell temperature                 [°C]   default 28
%       .LDEF    Lifetime degradation factor (0–1)          [-]    default 1
%       .G0      Reference irradiance for STC               [W/m²] default 1367
%
%   panel_config - Struct array, one element per active face.
%
%       REQUIRED per face:
%       .face        Label: '+X'|'-X'|'+Y'|'-Y'|'+Z'|'-Z'
%       .n_cells     Cells in series per string             [-]
%       .n_strings   Parallel strings on this face          [-]
%                    Set either to 0 to mark a face as inactive.
%
%       OPTIONAL per face:
%       .normal      Custom outward unit normal [3×1].
%                    If omitted, canonical axis is used.
%       .shadowing   Geometric obscuration factor (0–1)     default 1
%       .eta_wiring  Wiring/harness efficiency  (0–1)       default 1
%
% -------------------------------------------------------------------------
% Outputs:
%   total_power  - Total generated power                   [W]
%   face_power   - [nFaces×1] power per face               [W]
%   face_info    - Struct array with per-face diagnostics:
%                  .face, .cosTheta, .illuminated,
%                  .Imp, .Vmp, .Pmp, .power
%
% -------------------------------------------------------------------------
% Physics model (MPP-based, IEC 60891 two-parameter)
% -------------------------------------------------------------------------
%   1.  cos θ    = dot(n̂, ŝ)
%   2.  G_eff    = G · cos θ                          [W/m²]
%   3.  Imp_cell = Imp0 · (G_eff/G0) + dIdT·(T−Tref)
%                   current scales linearly with irradiance;
%                   temperature shift is additive
%   4.  Vmp_cell = Vmp0 + dVdT·(T−Tref)
%                   voltage shift is temperature-only (irradiance-independent)
%   5.  Pmp_cell = Vmp_cell · Imp_cell                [W per cell]
%   6.  P_face   = Pmp_cell · n_cells · n_strings · LDEF · shadow · eta_wiring
% -------------------------------------------------------------------------

    %% ── 0. Validate required fields ──────────────────────────────────────
    required = {'Vmp0','Imp0','dVdT','dIdT'};
    for r = required
        if ~isfield(cell_params, r{1})
            error('solar_power_output:missingField', ...
                  'cell_params.%s is required.', r{1});
        end
    end

    % Optional fields — defaults match AZUR AM0 standard conditions
    if ~isfield(cell_params,'Tref'), cell_params.Tref = 28;   end
    if ~isfield(cell_params,'T'),    cell_params.T    = 28;   end
    if ~isfield(cell_params,'LDEF'), cell_params.LDEF = 1;    end
    if ~isfield(cell_params,'G0'),   cell_params.G0   = 1367; end

    %% ── 1. Unpack & pre-compute temperature corrections ──────────────────
    Vmp0 = cell_params.Vmp0;
    Imp0 = cell_params.Imp0;
    dVdT = cell_params.dVdT;
    dIdT = cell_params.dIdT;
    dT   = cell_params.T - cell_params.Tref;
    LDEF = cell_params.LDEF;
    G0   = cell_params.G0;

    % Vmp correction is irradiance-independent → pre-compute once
    Vmp_cell = Vmp0 + dVdT * dT;

    %% ── 2. Normalise sun vector & build face-normal lookup ───────────────
    sun_hat = sun_vector(:) / norm(sun_vector);

    face_normals = containers.Map( ...
        {'+X','-X','+Y','-Y','+Z','-Z', ...
         '+ X','- X','+ Y','- Y','+ Z','- Z'}, ...
        {[ 1;0;0],[-1;0;0],[0; 1;0],[0;-1;0],[0;0; 1],[0;0;-1], ...
         [ 1;0;0],[-1;0;0],[0; 1;0],[0;-1;0],[0;0; 1],[0;0;-1]});

    %% ── 3. Loop over faces ───────────────────────────────────────────────
    nFaces     = numel(panel_config);
    face_power = zeros(nFaces, 1);
    face_info  = struct('face',        cell(nFaces,1),          ...
                        'cosTheta',    num2cell(zeros(nFaces,1)), ...
                        'illuminated', num2cell(false(nFaces,1)), ...
                        'Imp',         num2cell(zeros(nFaces,1)), ...
                        'Vmp',         num2cell(zeros(nFaces,1)), ...
                        'Pmp',         num2cell(zeros(nFaces,1)), ...
                        'power',       num2cell(zeros(nFaces,1)));

    for k = 1:nFaces
        pc = panel_config(k);

        face_info(k).face = pc.face;

        % ── a. Skip inactive faces (no cells or no strings) ────────────────
        if pc.n_cells == 0 || pc.n_strings == 0
            face_info(k).cosTheta    = 0;
            face_info(k).illuminated = false;
            face_info(k).Imp         = 0;
            face_info(k).Vmp         = Vmp_cell;
            face_info(k).Pmp         = 0;
            face_info(k).power       = 0;
            continue
        end

        % ── b. Resolve face normal ─────────────────────────────────────────
        if isfield(pc, 'normal') && ~isempty(pc.normal)
            n_hat = pc.normal(:) / norm(pc.normal);
        else
            label = strtrim(upper(pc.face));
            if ~isKey(face_normals, label)
                error('solar_power_output:unknownFace', ...
                      'Face "%s" not recognised. Use +X/-X/+Y/-Y/+Z/-Z.', pc.face);
            end
            n_hat = face_normals(label);
        end

        % ── c. Optional per-face efficiency fields ─────────────────────────
        shadow     = 1;
        eta_wiring = 1;
        if isfield(pc,'shadowing')  && ~isempty(pc.shadowing),  shadow     = pc.shadowing;     end
        if isfield(pc,'eta_wiring') && ~isempty(pc.eta_wiring), eta_wiring = pc.eta_wiring;    end

        % ── d. Angle of incidence ──────────────────────────────────────────
        cosTheta = dot(n_hat, sun_hat);

        face_info(k).cosTheta    = cosTheta;
        face_info(k).illuminated = (cosTheta > 0);

        if cosTheta <= 0
            face_info(k).Imp   = 0;
            face_info(k).Vmp   = Vmp_cell;
            face_info(k).Pmp   = 0;
            face_info(k).power = 0;
            continue
        end

        % ── e. Effective irradiance on face ────────────────────────────────
        G_eff = irradiance * cosTheta;   % [W/m²]

        % ── f. MPP cell model ──────────────────────────────────────────────
        % Imp scales linearly with irradiance; dIdT shift is additive
        Imp_cell = Imp0 * (G_eff / G0) + dIdT * dT;
        Imp_cell = max(Imp_cell, 0);        % physical clamp — cannot go negative

        Pmp_cell = Vmp_cell * Imp_cell;     % [W] per cell

        % ── g. Panel MPP power ─────────────────────────────────────────────
        % n_cells in series  → string voltage  = n_cells  × Vmp_cell
        % n_strings parallel → string current  = n_strings × Imp_cell
        % Panel MPP power    = n_cells × n_strings × Pmp_cell
        P_face = Pmp_cell * pc.n_cells * pc.n_strings ...
                 * LDEF * shadow * eta_wiring;

        face_power(k)      = P_face;
        face_info(k).Imp   = Imp_cell;
        face_info(k).Vmp   = Vmp_cell;
        face_info(k).Pmp   = Pmp_cell;
        face_info(k).power = P_face;
    end

    %% ── 4. Total power ───────────────────────────────────────────────────
    total_power = sum(face_power);

end