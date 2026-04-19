% main_axis.m
% Axis Power Simulation Script (Orbit-averaged over tumbling axes)

clear; clc;
addpath('lib');

% 1. USER INPUTS
N_az  = 180;
N_el  = 90;
N_rot = 360;
irradiance = 1367;
config_list = {'a', 'b', 'c'};

% 2. OUTPUT DIRECTORY
out_dir = 'results';
if ~exist(out_dir, 'dir')
    mkdir(out_dir);
end

% 3. RUN ALL CONFIGURATIONS
for idx = 1:numel(config_list)
    dvs_config = config_list{idx};
    config_tag = lower(dvs_config);

    [P_axis, P_mean, cp, pc, phi_deg, theta_deg] = axis_power_sim(N_az, N_el, N_rot, irradiance, dvs_config);

    % Statistics
    P_flat = P_axis(:);
    fprintf('\n[dvs_sat_%s]\n', upper(config_tag));
    fprintf('Best-axis power    : %.4f W\n',  max(P_flat));
    fprintf('Mean over all axes : %.4f W\n',  P_mean);
    fprintf('Worst-axis power   : %.4f W\n',  min(P_flat));

    % Save per-configuration output
    result_file = sprintf('axis_results_dvs_sat_%s.mat', config_tag);
    save(fullfile(out_dir, result_file), ...
         'P_axis', 'P_flat', 'P_mean', ...
        'phi_deg', 'theta_deg', 'N_az', 'N_el', 'N_rot', 'irradiance', 'cp', 'pc', 'dvs_config');

    fprintf('Saved to %s/%s\n', out_dir, result_file);
end

% Keep legacy filename for backward compatibility (last run config).
save(fullfile(out_dir, 'axis_results.mat'), ...
    'P_axis', 'P_flat', 'P_mean', ...
    'phi_deg', 'theta_deg', 'N_az', 'N_el', 'N_rot', 'irradiance', 'cp', 'pc', 'dvs_config');
