%% run_simulation.m  –  SERVER SIDE (no plots, no display)
% Sections 1, 2, 3, 5 from original script.
% Saves everything plot_results.m needs.

clear; clc;

%% ═══════════════════════════════════════════════════════
%  1. USER INPUTS
% ═══════════════════════════════════════════════════════
N_az = 360;
N_el = 180;
irradiance = 1361;

cp.Vmp0 = 2.395;
cp.Imp0 = 1.284;
cp.dVdT = -6.7e-3;
cp.dIdT =  0.62e-3;
cp.Tref = 28;
cp.T    = 80;
cp.LDEF = 0.95;
cp.G0   = 1367;

face_labels   = {'+X', '-X', '+Y', '-Y', '+Z', '-Z'};
n_cells_vec   = [  4,   4,   0,   4,   2,   0];
n_strings_vec = [  1,   1,   0,   1,   0,   1];
cell_area     = 77.55e-4;
eta_wiring    = 0.98;

pc = struct([]);
for i = 1:numel(face_labels)
    pc(i).face       = face_labels{i};
    pc(i).n_cells    = n_cells_vec(i);
    pc(i).n_strings  = n_strings_vec(i);
    pc(i).cell_area  = cell_area;
    pc(i).eta_wiring = eta_wiring;
end

worst_pct = 10;

%% ═══════════════════════════════════════════════════════
%  2. BUILD EQUAL-AREA SPHERICAL GRID
% ═══════════════════════════════════════════════════════
phi_deg   = linspace(0, 360 - 360/N_az, N_az);
sin_vals  = linspace(-1, 1, N_el);
theta_deg = asind(sin_vals);
phi_rad   = deg2rad(phi_deg);
theta_rad = deg2rad(theta_deg);

%% ═══════════════════════════════════════════════════════
%  3. EVALUATE POWER  (the heavy part)
% ═══════════════════════════════════════════════════════
P_grid = zeros(N_el, N_az);

fprintf('Running spherical sweep: %d x %d = %d directions...\n', ...
        N_el, N_az, N_el*N_az);
t_start = tic;

% Parallelised — uses SLURM_CPUS_PER_TASK cores via parpool('local')
n_cores = str2double(getenv('SLURM_CPUS_PER_TASK'));
if isnan(n_cores) || n_cores < 1, n_cores = 1; end
fprintf('Using %d cores (parpool local)\n', n_cores);

if n_cores > 1
    parpool('local', n_cores);
end

parfor i = 1:N_el
    row = zeros(1, N_az);
    for j = 1:N_az
        sun_body = [cos(theta_rad(i)) * cos(phi_rad(j));
                    cos(theta_rad(i)) * sin(phi_rad(j));
                    sin(theta_rad(i))];
        [row(j), ~, ~] = solar_power_output(sun_body, irradiance, cp, pc);
    end
    P_grid(i,:) = row;
end

elapsed = toc(t_start);
fprintf('Sweep done in %.1f s\n', elapsed);

if n_cores > 1
    delete(gcp('nocreate'));
end

%% ═══════════════════════════════════════════════════════
%  4. STATS  (also printed server-side for the log)
% ═══════════════════════════════════════════════════════
P_all    = P_grid(:);
N_total  = numel(P_all);
P_avg    = mean(P_all);
P_sorted = sort(P_all, 'ascend');
n_worst  = round(worst_pct/100 * N_total);
P_worst  = mean(P_sorted(1:n_worst));

fprintf('\n');
fprintf('P_avg        : %.4f W\n', P_avg);
fprintf('P_worst %2d%% : %.4f W\n', worst_pct, P_worst);
fprintf('P_min        : %.4f W\n', min(P_all));
fprintf('P_max        : %.4f W\n', max(P_all));
fprintf('Std dev      : %.4f W\n', std(P_all));

%% ═══════════════════════════════════════════════════════
%  5. SAVE — everything plot_results.m will need
% ═══════════════════════════════════════════════════════
out_dir = fullfile(getenv('HOME'), 'jobs');
save(fullfile(out_dir, 'simulation_results.mat'), ...
     'P_grid', 'P_all', 'P_avg', 'P_worst', ...
     'phi_deg', 'theta_deg', 'phi_rad', 'theta_rad', ...
     'N_az', 'N_el', 'worst_pct', 'irradiance', 'cp', 'pc');

fprintf('Results saved to %s/simulation_results.mat\n', out_dir);
