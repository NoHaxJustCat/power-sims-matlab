%% orbit_plot_results.m  —  CLIENT SIDE

clear; clc;
load('results/orbit_results.mat');

fprintf('P_mean = %.4f W', P_mean);

% ── Fig 1: Heatmap ────────────────────────────────────────────────────────
figure('Name','Orbit-Average Power vs Tumbling Axis','NumberTitle','off');
imagesc(phi_ax_deg, theta_ax_deg, P_axis_avg);
set(gca,'YDir','normal'); colormap(turbo);
cb = colorbar; cb.Label.String = 'Orbit-average power [W]';
xlabel('Tumbling-axis azimuth \phi [°]');
ylabel('Tumbling-axis elevation \theta [°]');
title(sprintf('Orbit-Average Power vs Tumbling Axis\nMean = %.3f W  |  Min = %.3f W  |  Max = %.3f W', ...
              P_mean, min(P_flat), max(P_flat)));
xline(180,'w--','LineWidth',0.8); yline(0,'w--','LineWidth',0.8);
axis tight;

% ── Fig 2: 3D sphere ──────────────────────────────────────────────────────
figure('Name','Orbit-Average Power – 3D Sphere','NumberTitle','off');
[PHI, THETA] = meshgrid(phi_ax, theta_ax);
Xs = cos(THETA).*cos(PHI);
Ys = cos(THETA).*sin(PHI);
Zs = sin(THETA);
surf(Xs, Ys, Zs, P_axis_avg, 'EdgeColor','none','FaceColor','interp');
colormap(turbo); cb2 = colorbar;
cb2.Label.String = 'Orbit-average power [W]';
axis equal off;
title(sprintf('Orbit-Average Power on Tumbling-Axis Sphere\nMean = %.3f W', P_mean));
view(135,30); camlight('headlight'); lighting gouraud;

% ── Fig 3: Histogram ──────────────────────────────────────────────────────
figure('Name','Orbit-Average Power – Distribution','NumberTitle','off');
histogram(P_flat, 60, 'FaceColor',[0.2 0.5 0.9], ...
          'EdgeColor','none','Normalization','probability');
hold on;
xline(P_mean,  'r-',  'LineWidth',2, 'Label',sprintf('Mean %.3f W', P_mean), ...
      'LabelVerticalAlignment','bottom');

xlabel('Orbit-average power [W]'); ylabel('Probability');
title('Distribution of Orbit-Average Power Across All Tumbling Axes');
grid on;