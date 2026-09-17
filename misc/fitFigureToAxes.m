function [figW, figH] = fitFigureToAxes(fig, axW, axH, opts)
%FITFIGURETOAXES Size a figure around a fixed axes display area.
%   [figW, figH] = fitFigureToAxes(fig, axW, axH) sets the plot box of the
%   single axes in FIG to AXW x AXH [cm] and resizes the figure so that the
%   tick labels, axis labels and title are enclosed by the axes TightInset
%   plus a small pad. The returned figure width and height are in [cm].
%
%   fitFigureToAxes(..., 'Pad', p) sets the whitespace added outside
%   TightInset on every side [cm]. Default 0.1.
%
%   fitFigureToAxes(..., 'Extra', [l b r t]) adds margin [cm] for items not
%   covered by TightInset, such as a colorbar, an outside legend or
%   annotations. Default [0 0 0 0].
%
%   Call after all content, labels, limits and ticks have been set, since
%   TightInset depends on the rendered text. Only sizing properties are
%   changed; the original Units of the axes and figure are restored.
%
%   The axes must be a direct child of the figure (not in a uipanel or
%   tiledlayout). With a manual DataAspectRatio or PlotBoxAspectRatio
%   (e.g. axis equal), the drawn box can be smaller than AXW x AXH.
%
%   Example
%       fig = figure;  ax = axes(fig);
%       plot(ax, x, y);  xlabel(ax, '$f$ [Hz]', 'Interpreter', 'latex');
%       fitFigureToAxes(fig, 7, 5, 'Extra', [0 0 1.2 0]);
%       print(fig, 'out', '-dpdf', '-vector');   % R2022b+; else '-painters'

arguments
    fig        (1,1) matlab.ui.Figure
    axW        (1,1) double {mustBePositive}
    axH        (1,1) double {mustBePositive}
    opts.Pad   (1,1) double {mustBeNonnegative} = 0.1
    opts.Extra (1,4) double {mustBeNonnegative} = [0 0 0 0]
end

%% ---- Locate the axes ----------------------------------------------------
ax = findall(fig, 'Type', 'axes');
if numel(ax) ~= 1
    error('fitFigureToAxes:axesCount', ...
        'Expected one axes in the figure, found %d.', numel(ax));
end
if ~isequal(ax.Parent, fig)
    error('fitFigureToAxes:parent', ...
        'The axes must be a direct child of the figure.');
end

%% ---- Store units to restore afterwards ----------------------------------
axUnits    = ax.Units;
figUnits   = fig.Units;
paperUnits = fig.PaperUnits;

%% ---- Fix the plot box size ----------------------------------------------
if strcmp(fig.WindowStyle, 'docked')
    fig.WindowStyle = 'normal';                  % docked figures ignore Position
end

ax.PositionConstraint = 'innerposition';         % R2020a+; earlier releases:
                                                 % ax.ActivePositionProperty = 'position'
ax.Units = 'centimeters';
ax.Position(3:4) = [axW axH];
drawnow;                                         % TightInset is valid only after rendering

%% ---- Margins and figure size --------------------------------------------
m = ax.TightInset + opts.Pad + opts.Extra;       % [left bottom right top] [cm]

figW = m(1) + axW + m(3);
figH = m(2) + axH + m(4);

fig.Units = 'centimeters';
fig.Position(3:4) = [figW figH];
ax.Position = [m(1) m(2) axW axH];

fig.PaperUnits    = 'centimeters';
fig.PaperSize     = [figW figH];
fig.PaperPosition = [0 0 figW figH];

%% ---- Restore units ------------------------------------------------------
ax.Units       = axUnits;
fig.Units      = figUnits;
fig.PaperUnits = paperUnits;
end
