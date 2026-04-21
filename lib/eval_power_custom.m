function [P_mean, P_min, P_max] = eval_power_custom(N_az, N_el, irradiance, dvs_config, ignore_temp, force_bol)
    sat_fn = str2func(sprintf('dvs_sat_%s', lower(char(dvs_config))));
    [cp, pc] = sat_fn();
    
    if force_bol
        cp.Vmp0 = 2.411;
        cp.Imp0 = 0.504;
    end
    
    phi_deg   = linspace(0, 360 - 360/N_az, N_az);
    sin_ax    = linspace(-1, 1, N_el);
    theta_deg = asind(sin_ax);
    phi       = deg2rad(phi_deg);
    theta     = deg2rad(theta_deg);

    N_tot = N_el * N_az;
    P_dir = zeros(N_tot, 1);
    
    % Flattened vectors for fast loop
    idx = 1;
    S = zeros(3, N_tot);
    for i = 1:N_el
        for j = 1:N_az
            S(:, idx) = [cos(theta(i))*cos(phi(j)); cos(theta(i))*sin(phi(j)); sin(theta(i))];
            idx = idx + 1;
        end
    end
    
    parfor i = 1:N_tot
        P_dir(i) = solar_power_output(S(:,i), irradiance, cp, pc, ignore_temp);
    end
    
    P_mean = mean(P_dir);
    P_min = min(P_dir);
    P_max = max(P_dir);
end
