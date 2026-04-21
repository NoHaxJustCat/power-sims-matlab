function [P_dir, T_cells, P_mean, cp, pc, phi_deg, theta_deg] = directional_power_sim(N_az, N_el, irradiance, dvs_config)
% directional_power_sim computes the power generated from each direction
%   It uniformly samples the sphere (equal solid angle per point) and 
%   evaluates the solar power output.

    if nargin < 4
        dvs_config = 'b';
    end
    sat_fn = str2func(sprintf('dvs_sat_%s', lower(char(dvs_config))));
    [cp, pc] = sat_fn();

    phi_deg   = linspace(0, 360 - 360/N_az, N_az);
    sin_ax    = linspace(-1, 1, N_el);
    theta_deg = asind(sin_ax);
    phi       = deg2rad(phi_deg);
    theta     = deg2rad(theta_deg);

    nFaces = numel(pc);
    P_dir = zeros(N_el, N_az);
    T_cells = zeros(N_el, N_az, nFaces);

    parfor i = 1:N_el
        row_P  = zeros(1, N_az);
        row_T  = zeros(N_az, nFaces);
        t_i    = theta(i);
        phi_   = phi;

        for j = 1:N_az
            % s_body is the sun direction vector
            s_body = [cos(t_i) * cos(phi_(j));
                      cos(t_i) * sin(phi_(j));
                      sin(t_i)];
            
            [row_P(j), ~, fi] = solar_power_output(s_body, irradiance, cp, pc); 
            row_T(j,:) = [fi.T_cell];
        end
        
        P_dir(i,:) = row_P;
        T_cells(i,:,:) = row_T;
    end

    P_mean = mean(P_dir(:));
end
