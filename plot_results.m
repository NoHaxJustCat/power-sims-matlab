%% plot_results.m  –  CLIENT SIDE (run locally after scp)
% Just loads the .mat and reproduces all 3 plots from the original script.

clear; clc;

load('simulation_results.mat');   % adjust path if needed

fprintf('Loaded results:  P_avg = %.4f W  |  P_worst%d%% = %.4f W\n', ...
        P_avg, worst_pct, P_worst);

% ── Plot 1: Heatmap ───────────────────────────────────────────────────────
figure('Name', 'Tumbling Power – Spherical Map', 'NumberTitle', 'off');
imagesc(phi_deg, theta_deg, P_grid);
set(gca, 'YDir', 'normal');
colormap(turbo);
cb = colorbar; cb.Label.String = 'Power [W]';
xlabel('Azimuth \phi [°]');
ylabel('Elevation \theta [°]');
title(sprintf('Solar Power vs Sun Direction\nP_{avg} = %.3f W  |  P_{worst%d%%} = %.3f W', ...
              P_avg, worst_pct, P_worst));
xline(180, 'w--', 'LineWidth', 0.8);
yline(  0, 'w--', 'LineWidth', 0.8);
axis tight;

% ── Plot 2: 3D sphere ─────────────────────────────────────────────────────
figure('Name', 'Tumbling Power – 3D Sphere', 'NumberTitle', 'off');
[PHI, THETA] = meshgrid(phi_rad, theta_rad);
Xs = cos(THETA) .* cos(PHI);
Ys = cos(THETA) .* sin(PHI);
Zs = sin(THETA);
surf(Xs, Ys, Zs, P_grid, 'EdgeColor', 'none', 'FaceColor', 'interp');
colormap(turbo); colorbar;
axis equal off;
title(sprintf('Power on Unit Sphere  (P_{avg} = %.3f W)', P_avg));
view(135, 30);
camlight('headlight');
lighting gouraud;

% ── Plot 3: Histogram ─────────────────────────────────────────────────────
figure('Name', 'Tumbling Power – Distribution', 'NumberTitle', 'off');
histogram(P_all, 60, 'FaceColor', [0.2 0.5 0.9], 'EdgeColor', 'none', ...
          'Normalization', 'probability');
hold on;
xline(P_avg,   'r-',  'LineWidth', 2, 'Label', sprintf('Mean %.3f W', P_avg));
xline(P_worst, 'k--', 'LineWidth', 2, 'Label', sprintf('Worst %d%% %.3f W', worst_pct, P_worst));
xlabel('Power [W]');
ylabel('Probability');
title('Distribution of Power over All Sun Directions');
legend('All directions', 'Mean', sprintf('Worst %d%% mean', worst_pct));
grid on;
