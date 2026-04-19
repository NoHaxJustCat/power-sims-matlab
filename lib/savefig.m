function savefig(filename, size)
    % savefig: Save the figure to a file with a specific filename.
    %
    % Inputs:
    %   - filename: The name of the file to save the figure to (e.g., 'figure.png').
    %   - size: A two-element vector specifying the width and height.

    if ~exist('./out', 'dir')
        mkdir('./out')
    end

    fig = gcf;

    starting_pos = fig.Position;

    s = settings();
    scale_factor = s.matlab.desktop.DisplayScaleFactor.ActiveValue;

    base_unit = 150 * scale_factor; % [px]

    width = size(1) * base_unit;
    height = size(2) * base_unit;
    dpi = 96 * 6; % [dpi]

    fig.Position = [0 0 width height];
    exportgraphics(fig, strcat("out/", filename), Resolution = dpi);
    fig.Position = starting_pos;

end