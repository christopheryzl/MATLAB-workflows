function p = micArrayPerspective(canvas, opts)
%MICARRAYPERSPECTIVE  3D sketch of the microphone arcs + rig model.
%   Replaces addPerspective. Drawn on a FanCanvas like any 2D fan, so it
%   is placed in cm rather than with a separate axes position.
%
%   p = micArrayPerspective(cv, Name=Value)
%     Position        [x y] canvas cm of the scene origin       ([0 0])
%     Scale           cm per scene unit (arcs span r = 1..2)    (1.2)
%     View            [az el]                                   ([225 15])
%     Arcs            arcs to draw, by id or name               (all)
%                     0 "sideline", 1 "upstream",
%                     2 "midstream", 3 "downstream"
%     Highlight       arc(s) to shade, same ids or names        ([])
%     HighlightColor                                            ([.5 .5 .5])
%     Model           draw the rig model                        (true)
%     ModelAlpha                                                (1)
%     FlowLabel       draw the U_inf arrows                     (true)
%     RangeLabel      label the theta limits of the
%                     highlighted arc(s)                        (false)
%     RangeOffset     radial gap beyond the outer edge (r = 2)
%                     to each label, in scene units             (0.3)
%
%   Examples
%     micArrayPerspective(cv, Arcs=[0 2], Highlight=2)
%     micArrayPerspective(cv, Arcs=["sideline" "midstream"], Highlight="midstream")
%     micArrayPerspective(cv, Highlight="sideline", RangeLabel=true)
arguments
    canvas (1,1) FanCanvas
    opts.Position (1,2) double = [0 0]
    opts.Scale (1,1) double {mustBePositive} = 1.2
    opts.View (1,2) double = [225 15]
    opts.Arcs = 0:3
    opts.Highlight = []
    opts.HighlightColor (1,3) double = [0.5 0.5 0.5]
    opts.Model (1,1) logical = true
    opts.ModelAlpha (1,1) double = 1
    opts.FlowLabel (1,1) logical = true
    opts.RangeLabel (1,1) logical = false
    opts.RangeOffset (1,1) double {mustBeNonnegative} = 0.3
end

% Arc definitions, in drawing order (back to front as before).
% "labels" are the angles printed at theta(1) and theta(2) by RangeLabel,
% in the plotting convention (not necessarily equal to theta).
%         id  name           theta        phi   labels
arcs = {  3,  "downstream",  [45 105],    240,  [45 105]
          2,  "midstream",   [45 105],    270,  [45 105]
          1,  "upstream",    [45 105],    300,  [45 105]
          0,  "sideline",    [305 395],   0,    [-35 55]   };
names = [arcs{:,2}];
show = arcIds(opts.Arcs, names, [arcs{:,1}]);
shade = arcIds(opts.Highlight, names, [arcs{:,1}]);

p = canvas.addPerspective(Position=opts.Position, Scale=opts.Scale, View=opts.View);

for k = 1:size(arcs, 1)
    id = arcs{k,1};
    if ~ismember(id, show), continue; end
    face = [1 1 1];
    if ismember(id, shade)
        face = opts.HighlightColor;
    end
    p.arc(arcs{k,3}, arcs{k,4}, FaceColor=face);
    if opts.RangeLabel && ismember(id, shade)
        rangeLabels(p, arcs{k,3}, arcs{k,4}, arcs{k,5}, opts.RangeOffset);
    end
end

if opts.Model
    p.addModel(FaceAlpha=opts.ModelAlpha);
end

if opts.FlowLabel
    p.arrows([-0.25 0 0.25; 2 2 2; 0 0 0], repmat([0; -0.5; 0], 1, 3));
    p.text([0; 2.6; 0], "$U_\infty$", Interpreter="latex", Outward=[0 1 0]);
end
end

function rangeLabels(p, theta, phi, labels, offset)
% label each theta limit just outside the outer edge (r = 2) of the arc
rOuter = 2;
for j = 1:2
    u = arcPoint(theta(j), phi, 1);  % unit radial direction at this limit
    pos = (rOuter + offset) * u;
    p.text(pos, sprintf('$%g^\\circ$', labels(j)), Interpreter="latex", ...
        Outward=u.');
end
end

function xyz = arcPoint(theta, phi, r)
% Point on an arc in scene units, matching p.arc: theta is measured in the
% x-y plane from +x towards +y, and that plane is then tilted by phi about
% the x axis (phi = 0 horizontal sideline plane, phi = 270 the vertical
% x-z plane below the rig, 300/240 tilted up/downstream).
xyz = r * [cosd(theta); sind(theta)*cosd(phi); sind(theta)*sind(phi)];
end

function ids = arcIds(sel, names, allIds)
% numeric ids or names -> numeric ids, with a clear error for typos
if isempty(sel)
    ids = [];
elseif isnumeric(sel)
    bad = sel(~ismember(sel, allIds));
    if ~isempty(bad)
        error('micArrayPerspective:arc', ...
            'Unknown arc id %g; use 0 sideline, 1 upstream, 2 midstream, 3 downstream.', bad(1));
    end
    ids = sel;
else
    sel = lower(string(sel));
    [ok, loc] = ismember(sel, names);
    assert(all(ok), 'micArrayPerspective:arc', ...
        'Unknown arc "%s"; use sideline, upstream, midstream or downstream.', ...
        sel(find(~ok, 1)));
    ids = allIds(loc);
end
end