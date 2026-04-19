function [P_axis, P_mean, cp, pc, phi_deg, theta_deg] = axis_power_sim(N_az, N_el, N_rot, irradiance, dvs_config)
% axis_power_sim computes the orbit-averaged power for a tumbling satellite
%   It uniformly samples the sphere for tumbling axes. For each axis, it
%   rotates the sun vector around the axis N_rot times and averages the power.

    if nargin < 5
        dvs_config = 'b';
    end
    sat_fn = str2func(sprintf('dvs_sat_%s', lower(char(dvs_config))));
    [cp, pc] = sat_fn();

    phi_deg   = linspace(0, 360 - 360/N_az, N_az);
    sin_ax    = linspace(-1, 1, N_el);
    theta_deg = asind(sin_ax);
    phi       = deg2rad(phi_deg);
    theta     = deg2rad(theta_deg);

    rot_angles = linspace(0, 2*pi*(1 - 1/N_rot), N_rot);

    P_axis = zeros(N_el, N_az);

    parfor i = 1:N_el
        row_P  = zeros(1, N_az);
        t_i    = theta(i);
        phi_   = phi;
        rot_a  = rot_angles;

        for j = 1:N_az
            n_hat = [cos(t_i) * cos(phi_(j));
                     cos(t_i) * sin(phi_(j));
                     sin(t_i)];

            P_rot = zeros(N_rot, 1);
            for r = 1:N_rot
                alpha = rot_a(r);
                % Rodrigues rotation formula for rotating the sun vector [1;0;0]
                % around n_hat by -alpha
                ca = cos(-alpha);  sa = sin(-alpha);
                v = [1; 0; 0];
                s_body = v*ca + cross(n_hat,v)*sa + n_hat*dot(n_hat,v)*(1-ca);

                [P_rot(r), ~, ~] = solar_power_output(s_body, irradiance, cp, pc, 0.3);
            end
            
            row_P(j) = mean(P_rot);
        end
        
        P_axis(i,:) = row_P;
    end

    P_mean = mean(P_axis(:));
end
