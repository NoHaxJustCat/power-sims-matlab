function plot_temp_vs_incidence(alpha_cell, eps_cell, irradiance)
    % PLOT_TEMP_VS_INCIDENCE Plots theoretical face temperature vs angle of incidence.
    % 
    % Inputs:
    %   alpha_cell - Solar absorptance (default 0.60)
    %   eps_cell   - IR emissivity (default 0.89)
    %   irradiance - Solar irradiance [W/m^2] (default 1367)

    if nargin < 1, alpha_cell = 0.60; end
    if nargin < 2, eps_cell = 0.89;   end
    if nargin < 3, irradiance = 1367; end

    % Stefan-Boltzmann constant [W/(m^2 K^4)]
    sigma = 5.670374419e-8; 

    % Angle of incidence [degrees]
    theta_deg = linspace(0, 90, 500);
    cosTheta  = cosd(theta_deg);

    % --- Conduction Correction ---
    % Determine the fraction of absorbed heat that conducts away into the 
    % spacecraft body to achieve exactly 40°C at normal incidence (0°).
    target_max_T = 40; % [°C]
    target_T_K = target_max_T + 273.15;
    
    % Minimum heat required to maintain 40°C via radiation alone
    Q_rad_req = eps_cell * sigma * target_T_K^4; 
    
    % Maximum heat absorbed at 0 degrees
    Q_in_max = alpha_cell * irradiance; 
    
    % The correction factor is the fraction of heat we keep (retained)
    f_retain = Q_rad_req / Q_in_max; 
    
    % Thermal balance: Q_in_retained = Q_out_rad
    % alpha * G * cos(theta) * f_retain = eps * sigma * T^4
    T_K = ( (alpha_cell .* irradiance .* cosTheta .* f_retain) ./ (sigma .* eps_cell) ).^0.25;
    T_cell = T_K - 273.15; % Convert to Celsius

    % Plotting
    figure('Name', 'Face Temperature vs Incidence Angle', 'NumberTitle', 'off');
    plot(T_cell, theta_deg, 'LineWidth', 2, 'Color', [0.8500 0.3250 0.0980]);
    
    % Axis limits and labels
    xlim([-20, 60]);
    ylim([0, 90]);
    
    xlabel('Face Temperature [°C]');
    ylabel('Angle of Incidence [°]');
    title('Steady-State Face Temperature vs Angle of Incidence');
    
    grid on;
    
    % Add a marker for max temperature (0 degrees incidence)
    hold on;
    max_T = T_cell(1);
    plot(max_T, 0, 'k.', 'MarkerSize', 15);
    text(max_T, 2, sprintf('  Max: %.1f °C', max_T), 'VerticalAlignment', 'bottom');
end