% plot_point.m  —  CLIENT SIDE

clear; clc;
addpath('lib');

result_files = dir(fullfile('results', 'directional_results_dvs_sat_*.mat'));
if isempty(result_files)
    result_files = dir(fullfile('results', 'directional_results.mat'));
end

for f = 1:numel(result_files)
    result_file = result_files(f).name;
    load(fullfile('results', result_file));

    config_label = 'unknown';
    name_token = regexp(result_file, 'directional_results_dvs_sat_([a-zA-Z0-9_]+)\.mat', 'tokens', 'once');
    if ~isempty(name_token)
        config_label = lower(name_token{1});
    end
    if exist('dvs_config', 'var') && (ischar(dvs_config) || isstring(dvs_config))
        config_label = lower(char(dvs_config));
    end

    if ~exist('face_labels', 'var')
        face_labels = {pc.face};
    end

    fprintf('[dvs_sat_%s] P_mean = %.4f W\n', upper(config_label), P_mean);

    % ── Fig 1: Heatmap ────────────────────────────────────────────────────
    figure('Name','Directional Power vs Sun Direction','NumberTitle','off');
    imagesc(phi_deg, theta_deg, P_dir);
    set(gca,'YDir','normal'); colormap(turbo);
    cb = colorbar; cb.Label.String = 'Power [W]';
    xlabel('Sun azimuth \phi [°]');
    ylabel('Sun elevation \theta [°]');
    title(sprintf('Directional Power vs Sun Direction\nMean = %.3f W  |  Min = %.3f W  |  Max = %.3f W', ...
                  P_mean, min(P_flat), max(P_flat)));
    xline(180,'w--','LineWidth',0.8); yline(0,'w--','LineWidth',0.8);
    axis tight;
    savefig(sprintf('point_heatmap_dvs_sat_%s.png', config_label), [10 6]);

    % ── Fig 2: 3D sphere ──────────────────────────────────────────────────
    figure('Name','Directional Power – 3D Sphere','NumberTitle','off');
    [PHI, THETA] = meshgrid(deg2rad(phi_deg), deg2rad(theta_deg));
    Xs = cos(THETA).*cos(PHI);
    Ys = cos(THETA).*sin(PHI);
    Zs = sin(THETA);
    surf(Xs, Ys, Zs, P_dir, 'EdgeColor','none','FaceColor','interp');
    colormap(turbo); cb2 = colorbar;
    cb2.Label.String = 'Power [W]';
    axis equal off;
    title(sprintf('Directional Power on Sun-Direction Sphere\nMean = %.3f W', P_mean));
    view(135,30); camlight('headlight'); lighting gouraud;
    savefig(sprintf('point_sphere_dvs_sat_%s.png', config_label), [10 8]);

    % ── Fig 3: Histogram ──────────────────────────────────────────────────
    figure('Name','Directional Power – Distribution','NumberTitle','off');
    histogram(P_flat, 60, 'FaceColor',[0.2 0.5 0.9], ...
              'EdgeColor','none','Normalization','probability');
    hold on;
    xline(P_mean,  'r-',  'LineWidth',2, 'Label',sprintf('Mean %.3f W', P_mean), ...
          'LabelVerticalAlignment','bottom');
    xlabel('Power [W]'); ylabel('Probability');
    title('Distribution of Expected Power Across All Sun Directions');
    grid on;
    savefig(sprintf('point_distribution_dvs_sat_%s.png', config_label), [10 6]);

    % ── Fig 4: Six face temperatures (3x2 heatmaps) ─────────────────────
    figure('Name','Cell Temperature Maps by Face','NumberTitle','off');
    tiledlayout(3,2,'TileSpacing','compact','Padding','compact');

    for k = 1:6
        nexttile;
        imagesc(phi_deg, theta_deg, T_cells(:,:,k));
        set(gca,'YDir','normal');
        colormap(turbo);
        cb = colorbar;
        cb.Label.String = 'Cell temperature [°C]';
        xlabel('Sun azimuth \phi [°]');
        ylabel('Sun elevation \theta [°]');
        title(sprintf('Face %s', face_labels{k}));
        xline(180,'w--','LineWidth',0.8);
        yline(0,'w--','LineWidth',0.8);
        axis tight;
    end

    savefig(sprintf('point_face_temperatures_dvs_sat_%s.png', config_label), [6 4]);
end