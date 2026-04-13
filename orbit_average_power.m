%% orbit_average_power.m
%
% For a TUMBLING satellite, computes the ORBIT-AVERAGE power for every
% possible tumbling axis direction.
%
% Physical picture
% ─────────────────
%   - The Sun is fixed in inertial space (along +X by convention here).
%   - The satellite spins around some body axis n̂ at a constant rate.
%   - Over one full rotation (360°), the Sun vector sweeps a great circle
%     in the body frame perpendicular to n̂.
%   - The orbit-average power for that axis is the mean of solar_power_output
%     evaluated at N_rot equally-spaced points around that great circle.
%   - Repeating this for every possible n̂ (sampled on a sphere with equal-
%     area spacing) gives a complete map of "what average power do we get
%     depending on which way the satellite happens to be tumbling?"
%
% Outputs
% ───────
%   P_axis_avg  [N_el × N_az]  orbit-average power for each tumbling axis
%   Scalar summary: overall mean, worst-20% mean, min, max
%   Three figures:
%     Fig 1 – 2-D heatmap of P_axis_avg vs tumbling-axis direction
%     Fig 2 – 3-D sphere coloured by P_axis_avg
%     Fig 3 – Histogram with mean and worst-20% marked
%
% Calls: solar_power_output.m  (must be in the same folder or on the path)
%
% =========================================================================

clear; clc;

%% ═══════════════════════════════════════════════════════════════════════
%  1. USER INPUTS
% ═══════════════════════════════════════════════════════════════════════

% ── Tumbling-axis grid (equal solid-angle per sample) ────────────────────
N_az  = 180;   % azimuth  steps for the tumbling-axis sphere
N_el  = 90;    % elevation steps (sin-spaced → equal area)
               % Total axes evaluated: N_az × N_el

% ── Rotation samples per axis ────────────────────────────────────────────
N_rot = 360;   % points around the great circle for each tumbling axis
               % 360 gives 1° resolution, plenty for convergence

% ── Solar irradiance ─────────────────────────────────────────────────────
irradiance = 1367;   % W/m²  AM0 at 1 AU

% ── Cell parameters (AZUR 3G30-Advanced, BOL, from datasheet) ────────────
cp.Vmp0 = 2.411;     % V      Vmp at STC
cp.Imp0 = 0.504;     % A      Imp at STC
cp.dVdT = -6.7e-3;   % V/°C   dVmp/dT
cp.dIdT =  0.62e-3;  % A/°C   dImp/dT
cp.Tref = 28;        % °C     AZUR AM0 reference
cp.T    = 80;        % °C     on-orbit hot case
cp.LDEF = 0.95;      % [-]    EOL degradation
cp.G0   = 1367;      % W/m²   AM0 reference irradiance

% ── Panel configuration ───────────────────────────────────────────────────
% Set n_cells=0 OR n_strings=0 for inactive faces.
face_labels   = {'+X', '-X', '+Y', '-Y', '+Z', '-Z'};
n_cells_vec   = [  4,    4,    0,    4,    2,    0 ];
n_strings_vec = [  1,    1,    0,    1,    0,    1 ];
eta_wiring    = 0.98;

pc = struct([]);
for i = 1:numel(face_labels)
    pc(i).face       = face_labels{i};
    pc(i).n_cells    = n_cells_vec(i);
    pc(i).n_strings  = n_strings_vec(i);
    pc(i).eta_wiring = eta_wiring;
end

% ── Statistics ────────────────────────────────────────────────────────────
worst_pct = 20;

%% ═══════════════════════════════════════════════════════════════════════
%  2. BUILD EQUAL-AREA GRID FOR TUMBLING AXES
% ═══════════════════════════════════════════════════════════════════════
% sin-spaced elevation → every (az, el) cell has the same solid angle
phi_ax_deg   = linspace(0, 360 - 360/N_az, N_az);
sin_ax       = linspace(-1, 1, N_el);
theta_ax_deg = asind(sin_ax);

phi_ax   = deg2rad(phi_ax_deg);
theta_ax = deg2rad(theta_ax_deg);

%% ═══════════════════════════════════════════════════════════════════════
%  3. ROTATION ANGLES AROUND EACH TUMBLING AXIS
% ═══════════════════════════════════════════════════════════════════════
rot_angles = linspace(0, 2*pi*(1 - 1/N_rot), N_rot);   % N_rot points, 0–360°

%% ═══════════════════════════════════════════════════════════════════════
%  4. MAIN LOOP — orbit-average power for every tumbling axis
% ═══════════════════════════════════════════════════════════════════════
% The Sun is fixed along inertial +X.
% For tumbling axis n̂, the Sun direction in the body frame at rotation
% angle α is given by Rodrigues' rotation formula applied INVERSELY:
%   s_body(α) = R(n̂, α)^T * [1;0;0]  =  R(n̂, -α) * [1;0;0]
% which rotates the inertial Sun vector into the body frame.

P_axis_avg = zeros(N_el, N_az);

fprintf('Computing orbit-average power for %d tumbling axes...\n', N_el*N_az);
t0 = tic;

for i = 1:N_el
    for j = 1:N_az

        % ── Tumbling axis unit vector (body frame) ─────────────────────────
        n_hat = [cos(theta_ax(i)) * cos(phi_ax(j));
                 cos(theta_ax(i)) * sin(phi_ax(j));
                 sin(theta_ax(i))];

        % ── Power at each rotation angle ───────────────────────────────────
        P_rot = zeros(N_rot, 1);
        for r = 1:N_rot
            alpha = rot_angles(r);

            % Rodrigues rotation: rotate Sun (+X inertial) by -alpha around n̂
            % to get Sun direction in body frame
            s_body = rodrigues_rotate([1;0;0], n_hat, -alpha);

            [P_rot(r), ~, ~] = solar_power_output(s_body, irradiance, cp, pc);
        end

        % ── Orbit average for this axis ────────────────────────────────────
        P_axis_avg(i,j) = mean(P_rot);
    end
end

fprintf('Done in %.1f s\n\n', toc(t0));

%% ═══════════════════════════════════════════════════════════════════════
%  5. STATISTICS ACROSS ALL AXES
% ═══════════════════════════════════════════════════════════════════════
P_flat   = P_axis_avg(:);
P_mean   = mean(P_flat);
P_sorted = sort(P_flat, 'ascend');
n_worst  = round(worst_pct/100 * numel(P_flat));
P_worst  = mean(P_sorted(1:n_worst));

fprintf('╔══════════════════════════════════════════════╗\n');
fprintf('║      ORBIT-AVERAGE POWER vs TUMBLING AXIS    ║\n');
fprintf('╠══════════════════════════════════════════════╣\n');
fprintf('║  Tumbling-axis grid : %4d az × %4d el      ║\n', N_az, N_el);
fprintf('║  Rotation samples   : %4d per axis          ║\n', N_rot);
fprintf('║  Irradiance         : %8.1f W/m²          ║\n', irradiance);
fprintf('║  Cell temp          : %8.1f °C            ║\n', cp.T);
fprintf('╠══════════════════════════════════════════════╣\n');
fprintf('║  Best-axis power    : %8.4f W            ║\n', max(P_flat));
fprintf('║  Mean over all axes : %8.4f W            ║\n', P_mean);
fprintf('║  Worst %2d%% mean     : %8.4f W            ║\n', worst_pct, P_worst);
fprintf('║  Worst-axis power   : %8.4f W            ║\n', min(P_flat));
fprintf('╚══════════════════════════════════════════════╝\n\n');

%% ═══════════════════════════════════════════════════════════════════════
%  6. PLOTS
% ═══════════════════════════════════════════════════════════════════════

% ── Fig 1: 2-D heatmap ───────────────────────────────────────────────────
figure('Name','Orbit-Average Power vs Tumbling Axis','NumberTitle','off');
imagesc(phi_ax_deg, theta_ax_deg, P_axis_avg);
set(gca,'YDir','normal');
colormap(turbo); cb = colorbar;
cb.Label.String = 'Orbit-average power [W]';
xlabel('Tumbling-axis azimuth \phi [°]');
ylabel('Tumbling-axis elevation \theta [°]');
title(sprintf(['Orbit-Average Power vs Tumbling Axis Direction\n' ...
               'Mean = %.3f W  |  Worst-%d%% = %.3f W  |  ' ...
               'Min = %.3f W  |  Max = %.3f W'], ...
               P_mean, worst_pct, P_worst, min(P_flat), max(P_flat)));
xline(180,'w--','LineWidth',0.8);
yline(  0,'w--','LineWidth',0.8);
axis tight;

% ── Fig 2: 3-D sphere ────────────────────────────────────────────────────
figure('Name','Orbit-Average Power – 3D Sphere','NumberTitle','off');
[PHI, THETA] = meshgrid(phi_ax, theta_ax);
Xs = cos(THETA) .* cos(PHI);
Ys = cos(THETA) .* sin(PHI);
Zs = sin(THETA);
surf(Xs, Ys, Zs, P_axis_avg, 'EdgeColor','none','FaceColor','interp');
colormap(turbo); cb2 = colorbar;
cb2.Label.String = 'Orbit-average power [W]';
axis equal off;
title(sprintf('Orbit-Average Power on Tumbling-Axis Sphere\nMean = %.3f W', P_mean));
view(135, 30);
camlight('headlight');
lighting gouraud;

% ── Fig 3: Histogram ─────────────────────────────────────────────────────
figure('Name','Orbit-Average Power – Distribution','NumberTitle','off');
histogram(P_flat, 60, 'FaceColor',[0.2 0.5 0.9], ...
          'EdgeColor','none','Normalization','probability');
hold on;
xline(P_mean,  'r-',  'LineWidth', 2, ...
      'Label', sprintf('Mean %.3f W', P_mean), ...
      'LabelVerticalAlignment','bottom');
xline(P_worst, 'k--', 'LineWidth', 2, ...
      'Label', sprintf('Worst %d%% %.3f W', worst_pct, P_worst), ...
      'LabelVerticalAlignment','bottom');
xlabel('Orbit-average power [W]');
ylabel('Probability');
title('Distribution of Orbit-Average Power Across All Tumbling Axes');
grid on;

%% ═══════════════════════════════════════════════════════════════════════
%  LOCAL FUNCTION — Rodrigues rotation formula
% ═══════════════════════════════════════════════════════════════════════
% Rotates vector v by angle alpha (radians) around unit axis n.
% Uses: v_rot = v·cos(α) + (n×v)·sin(α) + n·(n·v)·(1−cos(α))

function v_rot = rodrigues_rotate(v, n, alpha)
    ca = cos(alpha);
    sa = sin(alpha);
    v_rot = v * ca + cross(n, v) * sa + n * dot(n, v) * (1 - ca);
end