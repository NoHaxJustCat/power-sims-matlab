% plot_axis.m  —  CLIENT SIDE

clear; clc;
addpath('lib');

result_files = dir(fullfile('results', 'axis_results_dvs_sat_*.mat'));
if isempty(result_files)
    result_files = dir(fullfile('results', 'axis_results.mat'));
end

for f = 1:numel(result_files)
    result_file = result_files(f).name;
    load(fullfile('results', result_file));

    config_label = 'unknown';
    name_token = regexp(result_file, 'axis_results_dvs_sat_([a-zA-Z0-9_]+)\.mat', 'tokens', 'once');
    if ~isempty(name_token)
        config_label = lower(name_token{1});
    end
    if exist('dvs_config', 'var') && (ischar(dvs_config) || isstring(dvs_config))
        config_label = lower(char(dvs_config));
    end

    fprintf('[dvs_sat_%s] P_mean = %.4f W\n', upper(config_label), P_mean);

    % ── Fig 1: Heatmap ────────────────────────────────────────────────────
    figure('Name','Orbit-Average Power vs Tumbling Axis','NumberTitle','off');
    imagesc(phi_deg, theta_deg, P_axis);
    set(gca,'YDir','normal'); colormap(turbo);
    cb = colorbar; cb.Label.String = 'Orbit-average power [W]';
    xlabel('Tumbling-axis azimuth \phi [°]');
    ylabel('Tumbling-axis elevation \theta [°]');
    title(sprintf('Orbit-Average Power vs Tumbling Axis\nMean = %.3f W  |  Min = %.3f W  |  Max = %.3f W', ...
                  P_mean, min(P_flat), max(P_flat)));
    xline(180,'w--','LineWidth',0.8); yline(0,'w--','LineWidth',0.8);
    axis tight;
    savefig(sprintf('axis_heatmap_dvs_sat_%s.png', config_label), [10 6]);

    % ── Fig 2: 3D sphere ──────────────────────────────────────────────────
    figure('Name','Orbit-Average Power – 3D Sphere','NumberTitle','off');
    [PHI, THETA] = meshgrid(deg2rad(phi_deg), deg2rad(theta_deg));
    Xs = cos(THETA).*cos(PHI);
    Ys = cos(THETA).*sin(PHI);
    Zs = sin(THETA);
    surf(Xs, Ys, Zs, P_axis, 'EdgeColor','none','FaceColor','interp');
    colormap(turbo); cb2 = colorbar;
    cb2.Label.String = 'Orbit-average power [W]';
    axis equal off;
    title(sprintf('Orbit-Average Power on Tumbling-Axis Sphere\nMean = %.3f W', P_mean));
    view(135,30); camlight('headlight'); lighting gouraud;
    savefig(sprintf('axis_sphere_dvs_sat_%s.png', config_label), [10 8]);

    % ── Fig 3: Histogram ──────────────────────────────────────────────────
    figure('Name','Orbit-Average Power – Distribution','NumberTitle','off');
    histogram(P_flat, 60, 'FaceColor',[0.2 0.5 0.9], ...
              'EdgeColor','none','Normalization','probability');
    hold on;
    xline(P_mean,  'r-',  'LineWidth',2, 'Label',sprintf('Mean %.3f W', P_mean), ...
          'LabelVerticalAlignment','bottom');
    xlabel('Orbit-average power [W]'); ylabel('Probability');
    title('Distribution of Orbit-Average Power Across All Tumbling Axes');
    grid on;
    savefig(sprintf('axis_distribution_dvs_sat_%s.png', config_label), [10 6]);
end