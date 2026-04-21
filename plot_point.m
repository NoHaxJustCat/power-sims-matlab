% plot_point.m  —  CLIENT SIDE

clear; clc; close all;
addpath('lib');

result_files = dir(fullfile('results', 'directional_results_dvs_sat_*.mat'));
if isempty(result_files)
    result_files = dir(fullfile('results', 'directional_results.mat'));
end

% Determine consistent color scale across all results
global_P_min = inf;
global_P_max = -inf;
for f = 1:numel(result_files)
    tmp = load(fullfile('results', result_files(f).name), 'P_flat');
    if isfield(tmp, 'P_flat')
        global_P_min = min(global_P_min, min(tmp.P_flat));
        global_P_max = max(global_P_max, max(tmp.P_flat));
    end
end

% Create figures outside the loop
fig_heat = figure('Name','Directional Power vs Sun Direction','NumberTitle','off');
tlo_heat = tiledlayout(2,2,'TileSpacing','compact','Padding','compact');

fig_dist = figure('Name','Directional Power – Distribution','NumberTitle','off');
tlo_dist = tiledlayout(2,2,'TileSpacing','compact','Padding','compact');

subplot_labels = {'(a)', '(b)', '(c)', '(d)'};

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
    
    lbl = '';
    if f <= numel(subplot_labels)
        lbl = subplot_labels{f};
    end

    switch config_label
        case 'a'
            config_desc = 'Nominal configuration';
        case 'b'
            config_desc = 'Two Y+ solar cells removed';
        case 'c'
            config_desc = 'Two Z- solar cells removed';
        case 'd'
            config_desc = 'Two Z- and two Y+ solar cells removed';
        otherwise
            config_desc = sprintf('Config %s', upper(config_label));
    end

    % ── Fig 1: Heatmap ────────────────────────────────────────────────────
    figure(fig_heat);
    nexttile(tlo_heat);
    imagesc(phi_deg, theta_deg, P_dir);
    set(gca,'YDir','normal'); colormap(turbo);
    try clim([global_P_min global_P_max]); catch; caxis([global_P_min global_P_max]); end
    cb = colorbar; cb.Label.String = 'Power [W]';
    xlabel('Sun azimuth \phi [°]');
    ylabel('Sun elevation \theta [°]');
    title(sprintf('%s %s', lbl, config_desc));
    xline(180,'w--','LineWidth',0.8); yline(0,'w--','LineWidth',0.8);
    axis tight;

    % ── Fig 3: Histogram ──────────────────────────────────────────────────
    figure(fig_dist);
    nexttile(tlo_dist);
    histogram(P_flat, 60, 'FaceColor',[0.2 0.5 0.9], ...
              'EdgeColor','none','Normalization','probability');
    hold on;
    xline(P_mean,  'r-',  'LineWidth',2, 'Label',sprintf('Mean %.3f W', P_mean), ...
          'LabelVerticalAlignment','bottom');
    xlabel('Power [W]'); ylabel('Probability');
    title(sprintf('%s %s Distribution', lbl, config_desc));
    grid on;

    % ── Single figures for this configuration ─────────────────────────────
    fig_single_heat = figure('Name','Directional Power vs Sun Direction','NumberTitle','off');
    imagesc(phi_deg, theta_deg, P_dir);
    set(gca,'YDir','normal'); colormap(turbo);
    try clim([global_P_min global_P_max]); catch; caxis([global_P_min global_P_max]); end
    cb = colorbar; cb.Label.String = 'Power [W]';
    xlabel('Sun azimuth \phi [°]');
    ylabel('Sun elevation \theta [°]');
    title(sprintf('%s %s', lbl, config_desc));
    xline(180,'w--','LineWidth',0.8); yline(0,'w--','LineWidth',0.8);
    axis tight;
    savefig(sprintf('point_heatmap_dvs_sat_%s.png', config_label), [10 6]);
    close(fig_single_heat);

    fig_single_dist = figure('Name','Directional Power – Distribution','NumberTitle','off');
    histogram(P_flat, 60, 'FaceColor',[0.2 0.5 0.9], ...
              'EdgeColor','none','Normalization','probability');
    hold on;
    xline(P_mean,  'r-',  'LineWidth',2, 'Label',sprintf('Mean %.3f W', P_mean), ...
          'LabelVerticalAlignment','bottom');
    xlabel('Power [W]'); ylabel('Probability');
    title(sprintf('%s %s Distribution', lbl, config_desc));
    grid on;
    savefig(sprintf('point_distribution_dvs_sat_%s.png', config_label), [10 6]);
    close(fig_single_dist);
    
end

figure(fig_heat);
savefig('point_heatmap_all.png', [12 8]);

figure(fig_dist);
savefig('point_distribution_all.png', [12 8]);