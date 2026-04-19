function [total_power, face_power, face_info] = solar_power_output(sun_vector, irradiance, cell_params, panel_config)

    % ── 0. Validate & defaults ───────────────────────────────────────────
    required = {'Vmp0','Imp0','dVdT','dIdT','alpha_cell','eps_cell'};
    for r = required
        if ~isfield(cell_params, r{1})
            error('solar_power_output:missingField', ...
                'cell_params.%s is required.', r{1});
        end
    end
    if ~isfield(cell_params,'Tref'), cell_params.Tref = 28;    end
    if ~isfield(cell_params,'LDEF'), cell_params.LDEF = 1;     end
    if ~isfield(cell_params,'G0'),   cell_params.G0   = 1367;  end
    

    % ── 1. Unpack cell parameters ────────────────────────────────────────
    Vmp0 = cell_params.Vmp0;
    Imp0 = cell_params.Imp0;
    dVdT = cell_params.dVdT;
    dIdT = cell_params.dIdT;
    LDEF = cell_params.LDEF;
    G0   = cell_params.G0;

    % ── 2. Normalise sun vector & face normal lookup ─────────────────────
    sun_hat = sun_vector(:) / norm(sun_vector);

    face_normals = containers.Map( ...
        {'+X','-X','+Y','-Y','+Z','-Z'}, ...
        {[1;0;0],[-1;0;0],[0;1;0],[0;-1;0],[0;0;1],[0;0;-1]});

    nFaces = numel(panel_config);

    % ── 3. PRE-PASS: compute cosTheta & face normals for all faces ───────
    cosTheta_all = zeros(nFaces, 1);
    n_hat_all    = zeros(3, nFaces);

    for k = 1:nFaces
        pc = panel_config(k);
        if isfield(pc,'normal') && ~isempty(pc.normal)
            n_hat_all(:,k) = pc.normal(:) / norm(pc.normal);
        else
            label = strtrim(upper(pc.face));
            n_hat_all(:,k) = face_normals(label);
        end
        cosTheta_all(k) = dot(n_hat_all(:,k), sun_hat);
    end

    % ── 4 & 5. THERMAL BALANCE & POWER LOOP ──────────────────────────────
    face_power = zeros(nFaces, 1);
    face_info  = struct('face',        cell(nFaces,1),            ...
                        'cosTheta',    num2cell(zeros(nFaces,1)), ...
                        'illuminated', num2cell(false(nFaces,1)), ...
                        'T_cell',      num2cell(zeros(nFaces,1)), ...
                        'Imp',         num2cell(zeros(nFaces,1)), ...
                        'Vmp',         num2cell(zeros(nFaces,1)), ...
                        'Pmp',         num2cell(zeros(nFaces,1)), ...
                        'power',       num2cell(zeros(nFaces,1)));

    for k = 1:nFaces
        pc = panel_config(k);
        cT = cosTheta_all(k);

        % individual face thermal balance
        if cT > 0
            Q_abs = cell_params.alpha_cell * pc.A_cell * irradiance * cT;
            emit_coeff = cell_params.eps_cell * pc.A_cell;
            T_K = (Q_abs / (5.670374419e-8 * emit_coeff)) ^ 0.25;
            T_cell = T_K - 273.15;
        else
            T_cell = -273.15; % or cold deep space, effectively won't produce power anyway
        end
        
        dT = T_cell - cell_params.Tref;
        Vmp_cell = Vmp0 + dVdT * dT;

        face_info(k).face   = pc.face;
        face_info(k).T_cell = T_cell;

        % inactive face
        if pc.n_cells == 0 || pc.n_strings == 0
            face_info(k).cosTheta    = 0;
            face_info(k).illuminated = false;
            face_info(k).Vmp         = Vmp_cell;
            continue
        end

        face_info(k).cosTheta    = cT;
        face_info(k).illuminated = (cT > 0);

        % dark face
        if cT <= 0
            face_info(k).Vmp = Vmp_cell;
            continue
        end

        % wiring efficiency
        eta_wiring = 1;
        if isfield(pc,'eta_wiring') && ~isempty(pc.eta_wiring)
            eta_wiring = pc.eta_wiring;
        end
        shadow = 1;
        if isfield(pc,'shadowing') && ~isempty(pc.shadowing)
            shadow = pc.shadowing;
        end

        G_eff    = irradiance * cT;
        Imp_cell = Imp0 * (G_eff / G0) + dIdT * dT;
        Imp_cell = max(Imp_cell, 0);
        Pmp_cell = Vmp_cell * Imp_cell;

        P_face = Pmp_cell * pc.n_cells * pc.n_strings ...
                 * LDEF * shadow * eta_wiring;

        face_power(k)      = P_face;
        face_info(k).Imp   = Imp_cell;
        face_info(k).Vmp   = Vmp_cell;
        face_info(k).Pmp   = Pmp_cell;
        face_info(k).power = P_face;
    end

    total_power = sum(face_power);
end