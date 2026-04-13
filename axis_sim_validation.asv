%% orbit_average_simulation.m  —  SERVER SIDE (no plots)

clear; clc;

%% ═══════════════════════════════════════════════════════
%  1. USER INPUTS
% ═══════════════════════════════════════════════════════
N_az  = 180;
N_el  = 90;
N_rot = 360;

irradiance = 1367;

cp.Vmp0 = 2.411;
cp.Imp0 = 0.504;
cp.dVdT = -6.7e-3;
cp.dIdT =  0.24e-3;
cp.Tref = 28;
cp.T_dark = -20;
cp.T_hot  =  80;
cp.LDEF = 0.95;
cp.G0   = 1367;

face_labels   = {'+X', '-X', '+Y', '-Y', '+Z', '-Z'};
n_cells_vec   = [  2,    2,    2,    2,    2,    2 ];
n_strings_vec = [  1,    1,    1,    1,    1,    1 ];
eta_wiring    = 0.98;

pc = struct([]);
for i = 1:numel(face_labels)
    pc(i).face       = face_labels{i};
    pc(i).n_cells    = n_cells_vec(i);
    pc(i).n_strings  = n_strings_ve
    c(i);
    pc(i).eta_wiring = eta_wiring;
end

%% ═══════════════════════════════════════════════════════
%  2. BUILD EQUAL-AREA GRID
% ═══════════════════════════════════════════════════════
phi_ax_deg   = linspace(0, 360 - 360/N_az, N_az);
sin_ax       = linspace(-1, 1, N_el);
theta_ax_deg = asind(sin_ax);
phi_ax       = deg2rad(phi_ax_deg);
theta_ax     = deg2rad(theta_ax_deg);

%% ═══════════════════════════════════════════════════════
%  3. ROTATION ANGLES
% ═══════════════════════════════════════════════════════
rot_angles = linspace(0, 2*pi*(1 - 1/N_rot), N_rot );

%% ═══════════════════════════════════════════════════════
%  4. MAIN LOOP  —  parallelised over elevation rows
% ═══════════════════════════════════════════════════════
n_cores = 6;  % Adjust based on your machine; set to 1 for no parallelism
if isnan(n_cores) || n_cores < 1, n_cores = 1; end
fprintf('Using %d cores\n', n_cores);

if n_cores > 1
    parpool('local', n_cores);
end

P_axis_avg = zeros(N_el, N_az);

fprintf('Computing orbit-average power for %d axes...\n', N_el*N_az);
t0 = tic;

parfor i = 1:N_el
    % All variables used inside must be explicitly local to the parfor body
    row        = zeros(1, N_az);
    t_ax_i     = theta_ax(i);
    phi_ax_    = phi_ax;          % sliced broadcast
    rot_ang_   = rot_angles;

    for j = 1:N_az
        n_hat = [cos(t_ax_i) * cos(phi_ax_(j));
                 cos(t_ax_i) * sin(phi_ax_(j));
                 sin(t_ax_i)];

        P_rot = zeros(N_rot, 1);
        for r = 1:N_rot
            s_body   = rodrigues_rotate([1;0;0], n_hat, -rot_ang_(r));
            P_rot(r) = solar_power_output(s_body, irradiance, cp, pc);
        end

        row(j) = mean(P_rot);
    end
    P_axis_avg(i,:) = row;
end

fprintf('Done in %.1f s\n', toc(t0));

if n_cores > 1
    delete(gcp('nocreate'));
end

%% ═══════════════════════════════════════════════════════
%  5. STATISTICS
% ═══════════════════════════════════════════════════════
P_flat   = P_axis_avg(:);
P_mean   = mean(P_flat);
P_sorted = sort(P_flat, 'ascend');

fprintf('\n');
fprintf('Best-axis power    : %.4f W\n', max(P_flat));
fprintf('Mean over all axes : %.4f W\n', P_mean);
fprintf('Worst-axis power   : %.4f W\n', min(P_flat));

%% ═══════════════════════════════════════════════════════
%  6. SAVE
% ═══════════════════════════════════════════════════════
% Define the output directory
out_dir = 'results';

% Create the folder if it doesn't already exist
if ~exist(out_dir, 'dir')
    mkdir(out_dir);
end

% Save the variables
save(fullfile(out_dir, 'orbit_results.mat'), ...
     'P_axis_avg', 'P_flat', 'P_mean', ...
     'phi_ax_deg', 'theta_ax_deg', 'phi_ax', 'theta_ax', ...
     'N_az', 'N_el', 'N_rot', 'irradiance', 'cp', 'pc');

% Display the confirmation
fprintf('Saved to %s/orbit_results.mat\n', out_dir);

%% ═══════════════════════════════════════════════════════
%  LOCAL FUNCTION
% ═══════════════════════════════════════════════════════
function v_rot = rodrigues_rotate(v, n, alpha)
    ca = cos(alpha);  sa = sin(alpha);
    v_rot = v*ca + cross(n,v)*sa + n*dot(n,v)*(1-ca);
end
