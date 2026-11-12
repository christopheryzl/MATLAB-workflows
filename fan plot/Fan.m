classdef Fan < handle
%FAN  A fan-shaped (annular sector) polar plot drawn on a FanCanvas.
%
%   fan = cv.addFan(thetaRange, levelRange, Name=Value)
%
%   thetaRange  [t1 t2] (or a vector; its min/max are used), degrees
%   levelRange  [L1 L2] values mapped to the inner/outer radius (e.g. dB)
%
%   Layout (all lengths in cm on paper)
%     Position   [x y] where the fan goes                  ([0 0])
%     Anchor     which point of the fan sits on Position:  ("origin")
%                "origin" (polar centre) or a point on the sector's
%                bounding box: "southwest", "north", "center", ...
%     Radius     [inner outer] radius                      ([1.7 4.5])
%     Rotation   drawing angle of theta = 0, deg ccw from +x (0)
%     Direction  "ccw" | "cw"                              ("ccw")
%
%   Grid
%     ThetaStep  theta tick spacing, deg                   (15)
%     LevelStep  level tick spacing                        (5)
%     SnapTheta  round thetaRange outwards to ThetaStep    (true)
%     Grid       draw interior grid lines                  (true)
%     Guide      dashed lines from the edges to the centre (true)
%     GridColor, GridLineWidth
%
%   Methods
%     h  = fan.plot(theta, level, ...)   data lines (columns = series)
%     t  = fan.rLabels(...)              level tick labels on one edge
%     t  = fan.tLabels(...)              theta tick labels on an arc
%     t  = fan.title(str, ...)           title along one edge
%     h  = fan.addModel(...)             STL model at the fan centre
%     p  = fan.addModel3D(...)           3D arcs + model sketch at the centre
%     bb = fan.extent()                  [xmin xmax ymin ymax] incl. labels
%     [x,y] = fan.toXY(theta, level)     data -> canvas cm
%
%   Read-only: Center, BBox (sector only, no labels), ThetaRange,
%   LevelRange, ThetaTicks, LevelTicks, Handles.

    properties (SetAccess = private)
        Canvas
        Center (1,2) double         % canvas cm of the polar origin
        BBox (1,4) double           % [xmin xmax ymin ymax] of the sector
        Radius (1,2) double
        ThetaRange (1,2) double
        LevelRange (1,2) double
        ThetaTicks (1,:) double
        LevelTicks (1,:) double
        Rotation (1,1) double
        Direction (1,1) double      % +1 ccw, -1 cw
        Handles = gobjects(0)
    end

    properties (Access = private)
        NextColor = 1
        GridStyle
    end

    methods
        function obj = Fan(canvas, thetaRange, levelRange, opts)
            arguments
                canvas (1,1) FanCanvas
                thetaRange (1,:) double {mustBeFinite}
                levelRange (1,2) double {mustBeFinite}
                opts.Position (1,2) double = [0 0]
                opts.Anchor (1,1) string = "origin"
                opts.Radius (1,2) double {mustBeNonnegative} = [1.7 4.5]
                opts.Rotation (1,1) double = 0
                opts.Direction (1,1) string {mustBeMember(opts.Direction, ["ccw","cw"])} = "ccw"
                opts.ThetaStep (1,1) double {mustBePositive} = 15
                opts.LevelStep (1,1) double {mustBePositive} = 5
                opts.SnapTheta (1,1) logical = true
                opts.Grid (1,1) logical = true
                opts.Guide (1,1) logical = true
                opts.GridColor = [0.7 0.7 0.7]
                opts.GridLineWidth (1,1) double = 0.6
            end
            obj.Canvas = canvas;
            obj.Radius = sort(opts.Radius);
            obj.Rotation = opts.Rotation;
            obj.Direction = 1 - 2*(opts.Direction == "cw");
            obj.GridStyle = {'Color', opts.GridColor, ...
                'LineWidth', opts.GridLineWidth, 'HandleVisibility', 'off'};

            % ticks
            ts = opts.ThetaStep;
            t = [min(thetaRange) max(thetaRange)];
            if opts.SnapTheta
                t = ts*[floor(t(1)/ts), ceil(t(2)/ts)];
            end
            obj.ThetaRange = t;
            obj.ThetaTicks = ts*(ceil(t(1)/ts - 1e-9):floor(t(2)/ts + 1e-9));
            ls = opts.LevelStep;
            L = ls*[floor(min(levelRange)/ls), ceil(max(levelRange)/ls)];
            obj.LevelRange = L;
            obj.LevelTicks = L(1):ls:L(2);

            % placement
            rel = obj.sectorBox();
            if opts.Anchor == "origin"
                obj.Center = opts.Position;
            else
                fr = FanCanvas.anchorFraction(opts.Anchor);
                corner = [rel(1) + fr(1)*(rel(2)-rel(1)), ...
                          rel(3) + fr(2)*(rel(4)-rel(3))];
                obj.Center = opts.Position - corner;
            end
            obj.BBox = rel + obj.Center([1 1 2 2]);

            obj.drawGrid(opts.Grid, opts.Guide);
        end

        %% ---------------------------------------------------------- data
        function [x, y] = toXY(obj, theta, level)
            %TOXY  Map (theta in deg, level) to canvas cm.
            [x, y] = obj.polarXY(theta, obj.levelToRadius(level));
        end

        function h = plot(obj, theta, level, opts, lineProps)
            %PLOT  Plot level(theta). Columns of a matrix are separate
            %   series; theta may be a vector shared by all columns.
            %
            %   ClipBelow   hide values below LevelRange(1)   (true)
            %   ColorIndex  restart the colour cycle here       ([])
            %   Layer       "front" (above model) | "back"      ("front")
            %   + any line property, e.g. LineWidth=0.8, LineStyle="--"
            arguments
                obj
                theta double
                level double
                opts.ClipBelow (1,1) logical = true
                opts.ColorIndex double {mustBeScalarOrEmpty} = []
                opts.Layer (1,1) string {mustBeMember(opts.Layer, ["front","back"])} = "front"
                lineProps.?matlab.graphics.primitive.Line
            end
            if isvector(theta), theta = theta(:); end
            if isvector(level), level = level(:); end
            th = theta + 0*level;           % implicit expansion
            L  = level + 0*theta;
            if opts.ClipBelow
                L(L < obj.LevelRange(1)) = NaN;
            end
            [x, y] = obj.toXY(th, L);
            z = obj.layerZ(opts.Layer) + 0*x;

            args = namedargs2cell(lineProps);
            h = line(obj.Canvas.Axes, x, y, z, args{:});

            if ~isfield(lineProps, 'Color')
                if ~isempty(opts.ColorIndex), obj.NextColor = opts.ColorIndex; end
                co = obj.Canvas.Axes.ColorOrder;
                for k = 1:numel(h)
                    h(k).Color = co(mod(obj.NextColor - 1, size(co,1)) + 1, :);
                    obj.NextColor = obj.NextColor + 1;
                end
            end
            obj.Handles = [obj.Handles; h(:)];
        end

        %% -------------------------------------------------------- labels
        function t = rLabels(obj, opts)
            %RLABELS  Level tick labels along one straight edge.
            %
            %   Side        "start" (theta min) | "end"        ("start")
            %   Which       "all" | "limits" | step, e.g. 10 labels only
            %               multiples of 10                     ("all")
            %   Labels      custom labels for the selected ticks ([])
            %   Suffix      appended to every label, e.g. " dB" ("")
            %   Extension   tick lines beyond the edge, in DEGREES (0)
            %   Gap         space between tick end and text, cm  (0.08)
            %   Rotation    "tangent" | "radial" | "horizontal" | deg
            %   KeepUpright, HorizontalAlignment, VerticalAlignment
            %               ("auto" picks the side facing the fan),
            %   Interpreter
            arguments
                obj
                opts.Side (1,1) string {mustBeMember(opts.Side, ["start","end"])} = "start"
                opts.Which = "all"
                opts.Labels = []
                opts.Suffix (1,1) string = ""
                opts.Extension (1,1) double {mustBeNonnegative} = 0
                opts.Gap (1,1) double = 0.08
                opts.Rotation = "tangent"
                opts.KeepUpright (1,1) logical = true
                opts.HorizontalAlignment (1,1) string = "auto"
                opts.VerticalAlignment (1,1) string = "auto"
                opts.Interpreter (1,1) string = "tex"
            end
            L = obj.LevelTicks;
            if isnumeric(opts.Which)
                idx = find(abs(L/opts.Which - round(L/opts.Which)) < 1e-9);
            elseif opts.Which == "limits"
                idx = [1 numel(L)];
            elseif opts.Which == "all"
                idx = 1:numel(L);
            else
                error('Fan:which', 'Which must be "all", "limits" or a numeric step.');
            end
            if isempty(opts.Labels)
                str = string(L(idx));
            else
                str = string(opts.Labels);
                assert(numel(str) == numel(idx), 'Fan:labels', ...
                    'Need %d labels, got %d.', numel(idx), numel(str));
            end
            str = str + opts.Suffix;

            [edge, s] = obj.edge(opts.Side);
            thEnd = edge + s*opts.Extension;
            a = obj.drawAngle(thEnd);
            u = s*obj.Direction*[-sind(a), cosd(a)];   % away from the fan
            ang = FanCanvas.resolveAngle(opts.Rotation, a);
            ax = obj.Canvas.Axes;

            t = gobjects(numel(idx), 1);
            for k = 1:numel(idx)
                r = obj.levelToRadius(L(idx(k)));
                if opts.Extension > 0
                    th = linspace(edge, thEnd, max(2, ceil(opts.Extension) + 1));
                    [x, y] = obj.polarXY(th, r);
                    obj.Handles(end+1,1) = line(ax, x, y, ...
                        FanCanvas.ZGrid + 0*x, obj.GridStyle{:});
                end
                [x, y] = obj.polarXY(thEnd, r);
                t(k) = FanCanvas.orientedText(ax, [x y] + opts.Gap*u, ...
                    str(k), ang, u, KeepUpright=opts.KeepUpright, ...
                    HorizontalAlignment=opts.HorizontalAlignment, ...
                    VerticalAlignment=opts.VerticalAlignment, ...
                    Interpreter=opts.Interpreter);
            end
            obj.Handles = [obj.Handles; t];
        end

        function t = tLabels(obj, opts)
            %TLABELS  Theta tick labels along the inner or outer arc.
            %
            %   Side        "outer" | "inner"                     ("outer")
            %   Labels      numeric values (NaN hides) or strings ([])
            %   Format      sprintf format for numeric labels     ("%g°")
            %   Prefix      text put before some labels, e.g. "\theta = "
            %   PrefixAt    "first" | "last" | "all" | indices    ("first")
            %   Extension   tick lines beyond the arc, cm          (0)
            %   Gap         space between tick end and text, cm   (0.08)
            %   Rotation    "radial" | "tangent" | "horizontal" | deg
            %   KeepUpright, HorizontalAlignment, VerticalAlignment,
            %   Interpreter
            arguments
                obj
                opts.Side (1,1) string {mustBeMember(opts.Side, ["outer","inner"])} = "outer"
                opts.Labels = []
                opts.Format (1,1) string = "%g" + char(176)
                opts.Prefix (1,1) string = ""
                opts.PrefixAt = "first"
                opts.Extension (1,1) double {mustBeNonnegative} = 0
                opts.Gap (1,1) double = 0.08
                opts.Rotation = "radial"
                opts.KeepUpright (1,1) logical = true
                opts.HorizontalAlignment (1,1) string = "auto"
                opts.VerticalAlignment (1,1) string = "auto"
                opts.Interpreter (1,1) string = "tex"
            end
            ticks = obj.ThetaTicks;
            n = numel(ticks);
            if isempty(opts.Labels)
                str = compose(opts.Format, ticks);
            elseif isnumeric(opts.Labels)
                assert(numel(opts.Labels) == n, 'Fan:labels', 'Need %d labels.', n);
                str = compose(opts.Format, opts.Labels(:)');
                str(isnan(opts.Labels)) = "";
            else
                str = string(opts.Labels(:)');
                assert(numel(str) == n, 'Fan:labels', 'Need %d labels.', n);
            end
            if strlength(opts.Prefix) > 0
                if isnumeric(opts.PrefixAt)
                    at = opts.PrefixAt;
                else
                    at = struct('first', 1, 'last', n, 'all', 1:n).(char(opts.PrefixAt));
                end
                str(at) = opts.Prefix + str(at);
            end

            if opts.Side == "outer"
                r0 = obj.Radius(2);  s = 1;
            else
                r0 = obj.Radius(1);  s = -1;
            end
            ax = obj.Canvas.Axes;
            t = gobjects(0);
            for k = find(strlength(str) > 0)
                a = obj.drawAngle(ticks(k));
                er = [cosd(a), sind(a)];
                if opts.Extension > 0
                    [x, y] = obj.polarXY(ticks(k), r0 + s*[0 opts.Extension]);
                    obj.Handles(end+1,1) = line(ax, x, y, ...
                        FanCanvas.ZGrid + 0*x, obj.GridStyle{:});
                end
                [x, y] = obj.polarXY(ticks(k), r0 + s*(opts.Extension + opts.Gap));
                t(end+1,1) = FanCanvas.orientedText(ax, [x y], str(k), ...
                    FanCanvas.resolveAngle(opts.Rotation, a), s*er, ...
                    KeepUpright=opts.KeepUpright, ...
                    HorizontalAlignment=opts.HorizontalAlignment, ...
                    VerticalAlignment=opts.VerticalAlignment, ...
                    Interpreter=opts.Interpreter); %#ok<AGROW>
            end
            obj.Handles = [obj.Handles; t];
        end

        function t = title(obj, str, opts)
            %TITLE  Title written along one straight edge, outside the fan.
            %
            %   Side    "end" | "start"                        ("end")
            %   Align   "inner": text starts near the inner radius and
            %           runs outwards; "outer": ends near the outer radius
            %   Inset   distance from that radius along the edge, cm (0.2)
            %   Gap     distance from the edge, cm              (0.08)
            %   Interpreter                                     ("latex")
            arguments
                obj
                str string
                opts.Side (1,1) string {mustBeMember(opts.Side, ["start","end"])} = "end"
                opts.Align (1,1) string {mustBeMember(opts.Align, ["inner","outer"])} = "inner"
                opts.Inset (1,1) double = 0.2
                opts.Gap (1,1) double = 0.08
                opts.Interpreter (1,1) string = "latex"
                opts.KeepUpright (1,1) logical = true
            end
            [edge, s] = obj.edge(opts.Side);
            a = obj.drawAngle(edge);
            er = [cosd(a), sind(a)];
            u = s*obj.Direction*[-sind(a), cosd(a)];   % away from the fan
            if opts.Align == "inner"
                r0 = obj.Radius(1) + opts.Inset;  runDir = er;
            else
                r0 = obj.Radius(2) - opts.Inset;  runDir = -er;
            end
            [x, y] = obj.polarXY(edge, r0);

            ang = mod(a + 180, 360) - 180;
            if opts.KeepUpright && (ang > 90 || ang <= -90)
                ang = ang + 180;
            end
            b = [cosd(ang), sind(ang)];
            n = [-sind(ang), cosd(ang)];
            ha = "left";   if dot(b, runDir) < 0, ha = "right"; end
            va = "bottom"; if dot(n, u) < 0,      va = "top";   end

            t = FanCanvas.orientedText(obj.Canvas.Axes, [x y] + opts.Gap*u, ...
                str, ang, u, KeepUpright=false, HorizontalAlignment=ha, ...
                VerticalAlignment=va, Interpreter=opts.Interpreter);
            obj.Handles(end+1,1) = t;
        end

        %% --------------------------------------------------------- model
        function h = addModel(obj, opts)
            %ADDMODEL  Top view of the STL rig model at the fan centre.
            %
            %   Scale     paper length of 1 m of model, as a fraction of
            %             the outer radius                       (0.625)
            %   Rotation  rotation about the model z axis, deg   (90)
            %   Offset    [dx dy] from the fan centre, cm        ([0 0])
            %   FaceAlpha                                        (1)
            %   Parts     struct array, see rigModelParts
            arguments
                obj
                opts.Scale (1,1) double {mustBePositive} = 0.625
                opts.Rotation (1,1) double = 90
                opts.Offset (1,2) double = [0 0]
                opts.FaceAlpha (1,1) double = 1
                opts.Parts struct = rigModelParts()
            end
            cmPerMm = opts.Scale*obj.Radius(2)/1000;
            M = cmPerMm*rotz3(opts.Rotation);         % top view: no projection
            h = drawModel(obj.Canvas.Axes, M, obj.Center + opts.Offset, ...
                Top=0, FaceAlpha=opts.FaceAlpha, Parts=opts.Parts);
            obj.Handles = [obj.Handles; h(:)];
        end

        function p = addModel3D(obj, opts)
            %ADDMODEL3D  3D sketch of the mic arcs + rig model at the fan
            %   centre (replaces the separate addPerspective axes).
            %
            %   Size            outer arc radius of the sketch as a fraction
            %                   of the fan's inner radius            (0.9)
            %   Offset          [dx dy] from the fan centre, cm      ([0 0])
            %   View            [az el]                              ([225 15])
            %   Arcs            arcs to draw, ids or names           (all)
            %                   0 "sideline", 1 "upstream",
            %                   2 "midstream", 3 "downstream"
            %   Highlight       arc(s) to shade, same ids or names   ([])
            %   HighlightColor                                       ([.5 .5 .5])
            %   Model, ModelAlpha, FlowLabel   as micArrayPerspective
            %
            %   Returns the FanPerspective, e.g. for p.text(...) additions.
            arguments
                obj
                opts.Size (1,1) double {mustBePositive} = 0.9
                opts.Offset (1,2) double = [0 0]
                opts.View (1,2) double = [225 15]
                opts.Arcs = 0:3
                opts.Highlight = []
                opts.HighlightColor (1,3) double = [0.5 0.5 0.5]
                opts.Model (1,1) logical = true
                opts.ModelAlpha (1,1) double = 1
                opts.FlowLabel (1,1) logical = true
            end
            % micArrayPerspective draws the arcs out to r = 2 scene units
            scale = opts.Size*obj.Radius(1)/2;
            p = micArrayPerspective(obj.Canvas, ...
                Position=obj.Center + opts.Offset, Scale=scale, View=opts.View, ...
                Arcs=opts.Arcs, Highlight=opts.Highlight, ...
                HighlightColor=opts.HighlightColor, ...
                Model=opts.Model, ModelAlpha=opts.ModelAlpha, ...
                FlowLabel=opts.FlowLabel, ...
                RangeLabel=true, ...
                RangeOffset=0.2);
            obj.Handles = [obj.Handles; p.Handles(:)];
        end

        function bb = extent(obj)
            %EXTENT  [xmin xmax ymin ymax] in cm, including labels.
            drawnow;
            bb = FanCanvas.extentOf(obj.Handles);
        end
    end

    methods (Access = private)
        function a = drawAngle(obj, theta)
            a = obj.Rotation + obj.Direction*theta;
        end

        function r = levelToRadius(obj, level)
            L = obj.LevelRange;  R = obj.Radius;
            r = R(1) + (level - L(1))/(L(2) - L(1))*(R(2) - R(1));
        end

        function [x, y] = polarXY(obj, theta, r)
            a = obj.drawAngle(theta);
            x = obj.Center(1) + r.*cosd(a);
            y = obj.Center(2) + r.*sind(a);
        end

        function [edge, s] = edge(obj, side)
            % theta of an edge and the sign that points away from the fan
            if side == "start"
                edge = obj.ThetaRange(1);  s = -1;
            else
                edge = obj.ThetaRange(2);  s = 1;
            end
        end

        function z = layerZ(~, layer)
            if layer == "front", z = FanCanvas.ZFront; else, z = FanCanvas.ZBack; end
        end

        function bb = sectorBox(obj)
            % bounding box of the sector relative to the polar origin
            a = sort(obj.drawAngle(obj.ThetaRange));
            card = 90*(ceil(a(1)/90):floor(a(2)/90));
            a = [linspace(a(1), a(2), 181), card];
            x = obj.Radius(:).*cosd(a);
            y = obj.Radius(:).*sind(a);
            bb = [min(x(:)) max(x(:)) min(y(:)) max(y(:))];
        end

        function drawGrid(obj, grid, guide)
            ax = obj.Canvas.Axes;
            t = obj.ThetaRange;
            th = linspace(t(1), t(2), max(2, ceil(t(2) - t(1)) + 1));
            z = FanCanvas.ZGrid;

            levels = obj.LevelRange;
            rays = t;
            if grid
                levels = obj.LevelTicks;
                rays = unique([t, obj.ThetaTicks]);
            end
            for L = levels
                [x, y] = obj.toXY(th, L);
                obj.Handles(end+1,1) = line(ax, x, y, z + 0*x, obj.GridStyle{:});
            end
            for r = rays
                [x, y] = obj.polarXY(r, obj.Radius);
                obj.Handles(end+1,1) = line(ax, x, y, z + [0 0], obj.GridStyle{:});
            end
            if guide
                for r = t
                    [x, y] = obj.polarXY(r, [0 obj.Radius(1)]);
                    obj.Handles(end+1,1) = line(ax, x, y, z + [0 0], ...
                        obj.GridStyle{:}, 'LineStyle', '--');
                end
            end
        end
    end
end

function R = rotz3(deg)
R = [cosd(deg) -sind(deg) 0; sind(deg) cosd(deg) 0; 0 0 1];
end