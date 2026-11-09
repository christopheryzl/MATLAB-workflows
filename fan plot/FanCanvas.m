classdef FanCanvas < handle
    %FANCANVAS  A centimetre-based drawing surface for fan-shaped polar plots.
    %
    %   cv = FanCanvas(f) covers figure f with ONE invisible axes whose data
    %   units are centimetres on paper. Fans, 3D perspectives, flow arrows and
    %   legends are all placed in these coordinates, so layout means "put this
    %   0.3 cm below that", never fiddling with axes positions. Absolute
    %   coordinates don't matter: cv.fit() shrinks the figure around whatever
    %   was drawn.
    %
    %   cv = FanCanvas(f, Name=Value)
    %     Colors    [n x 3] line colour cycle             (default: MATLAB's)
    %     FontName  font for all text and legends         (default: groot's)
    %     FontSize  points                                (default: 10)
    %
    %   Methods
    %     fan = cv.addFan(thetaRange, levelRange, ...)   see Fan
    %     p   = cv.addPerspective(...)                   see FanPerspective
    %     h   = cv.flowArrow(position, ...)              U_inf style arrows
    %     lg  = cv.addLegend(handles, labels, position, Anchor=..., ...)
    %     bb  = cv.fit(Margin=0.1)                       resize figure to content
    %     bb  = FanCanvas.extentOf(handles)              [xmin xmax ymin ymax] cm
    %
    %   Example
    %     cv  = FanCanvas(figure, Colors=lines(4), FontName="Times New Roman");
    %     fan = cv.addFan([-35 55], [75 100]);
    %     fan.plot(theta, OASPL);
    %     fan.rLabels(Which=10); fan.tLabels(); fan.title("OASPL [dB]");
    %     cv.fit();
    %     exportgraphics(cv.Figure, "out.pdf", ContentType="vector");

    properties (SetAccess = private)
        Figure
        Axes
        Items = {}      % fans and perspectives, in creation order
    end

    properties (Access = private)
        Legends = struct('Handle', {}, 'Point', {}, 'Anchor', {})
    end

    properties (Constant)
        % Depth (z) layers used to stack objects in the 2D view.
        % Models sit with their top surface at z = 0.
        ZGrid  = -50
        ZBack  = -25
        ZFront = 10
        ZText  = 20
    end

    methods
        function obj = FanCanvas(f, opts)
            arguments
                f (1,1) matlab.ui.Figure = figure()
                opts.Colors (:,3) double = get(groot, 'defaultAxesColorOrder')
                opts.FontName (1,1) string = get(groot, 'defaultTextFontName')
                opts.FontSize (1,1) double {mustBePositive} = 10
            end
            obj.Figure = f;
            f.Units = 'centimeters';
            sz = f.Position(3:4);

            % Data units == cm because the limits span exactly the axes size.
            ax = axes(f, Units='centimeters', Position=[0 0 sz], ...
                XLim=[0 sz(1)], YLim=[0 sz(2)], ...
                Visible='off', Clipping='off', ...
                FontName=opts.FontName, FontSize=opts.FontSize);
            set(ax, 'DefaultTextFontName', opts.FontName, ...
                'DefaultTextFontSize', opts.FontSize);
            colororder(ax, opts.Colors);
            hold(ax, 'on');
            view(ax, 2);
            disableDefaultInteractivity(ax);
            obj.Axes = ax;
        end

        function fan = addFan(obj, thetaRange, levelRange, varargin)
            %ADDFAN  Add a 2D fan. See Fan for the options.
            fan = Fan(obj, thetaRange, levelRange, varargin{:});
            obj.Items{end+1} = fan;
        end

        function p = addPerspective(obj, varargin)
            %ADDPERSPECTIVE  Add a projected 3D scene. See FanPerspective.
            p = FanPerspective(obj, varargin{:});
            obj.Items{end+1} = p;
        end

        function h = flowArrow(obj, position, opts)
            %FLOWARROW  A group of parallel arrows with a label behind them.
            %   position is the centre of the arrow group in cm.
            arguments
                obj
                position (1,2) double
                opts.Angle (1,1) double = -90      % flow direction, deg
                opts.Length (1,1) double {mustBePositive} = 0.5
                opts.Count (1,1) double {mustBeInteger, mustBePositive} = 3
                opts.Spacing (1,1) double = 0.25   % cm between arrows
                opts.Label (1,1) string = "$U_\infty$"
                opts.Interpreter (1,1) string = "latex"
                opts.LabelGap (1,1) double = 0.05
                opts.Color = 'k'
                opts.LineWidth (1,1) double = 0.5
                opts.MaxHeadSize (1,1) double = 0.6
            end
            d = [cosd(opts.Angle), sind(opts.Angle)];
            n = [-d(2), d(1)];
            k = (1:opts.Count) - (opts.Count + 1)/2;
            tails = position - d*opts.Length/2 + k(:)*n*opts.Spacing;
            h.Arrows = quiver(obj.Axes, tails(:,1), tails(:,2), ...
                repmat(d(1)*opts.Length, opts.Count, 1), ...
                repmat(d(2)*opts.Length, opts.Count, 1), 0, ...
                Color=opts.Color, LineWidth=opts.LineWidth, ...
                MaxHeadSize=opts.MaxHeadSize, HandleVisibility='off');
            h.Label = gobjects(0);
            if strlength(opts.Label) > 0
                h.Label = FanCanvas.orientedText(obj.Axes, ...
                    position - d*(opts.Length/2 + opts.LabelGap), ...
                    opts.Label, 0, -d, Interpreter=opts.Interpreter);
            end
        end

        function lg = addLegend(obj, handles, labels, point, opts, legendProps)
            %ADDLEGEND  Legend pinned to a canvas point (cm).
            %   Anchor says which part of the legend box sits on the point:
            %   "northwest" (default), "north", "center", "southeast", ...
            %   Any legend property can be passed as Name=Value.
            arguments
                obj
                handles
                labels (1,:) string
                point (1,2) double
                opts.Anchor (1,1) string = "northwest"
                legendProps.?matlab.graphics.illustration.Legend
            end
            args = namedargs2cell(legendProps);
            %             lg = legend(obj.Axes, handles, cellstr(labels), ...
            %                 'AutoUpdate','off', args{:});
            lg = legend(obj.Axes, cellstr(labels));
            lg.AutoUpdate = 'off';
            args = namedargs2cell(legendProps);
            if ~isempty(args)
                set(lg, args{:});
            end
            lg.Units = 'centimeters';
            lg.Location = 'none';
            obj.Legends(end+1) = struct('Handle', lg, 'Point', point, ...
                'Anchor', opts.Anchor);
            obj.placeLegends(obj.Axes.XLim(1), obj.Axes.YLim(1));
        end

        function bb = fit(obj, opts)
            %FIT  Resize the figure so it just contains everything drawn.
            %   bb = cv.fit(Margin=0.1) returns the content box in cm.
            %   Call it last (after any font changes).
            arguments
                obj
                opts.Margin (1,1) double = 0.1   % cm
            end
            drawnow;
            ax = obj.Axes;
            bb = FanCanvas.extentOf(ax.Children);
            for k = 1:numel(obj.Legends)
                bb = FanCanvas.mergeBox(bb, obj.legendBox(k));
            end
            if any(~isfinite(bb))
                warning('FanCanvas:empty', 'Nothing to fit.');
                return
            end
            bb = bb + opts.Margin*[-1 1 -1 1];
            w = bb(2) - bb(1);
            h = bb(4) - bb(3);
            f = obj.Figure;
            f.Units = 'centimeters';
            f.Position(3:4) = [w h];
            ax.Position = [0 0 w h];
            ax.XLim = bb(1:2);
            ax.YLim = bb(3:4);
            obj.placeLegends(bb(1), bb(3));
        end
    end

    methods (Access = private)
        function r = legendBox(obj, k)
            L = obj.Legends(k);
            sz = L.Handle.Position(3:4);
            fr = FanCanvas.anchorFraction(L.Anchor);
            ll = L.Point - fr.*sz;
            r = [ll(1), ll(1)+sz(1), ll(2), ll(2)+sz(2)];
        end

        function placeLegends(obj, x0, y0)
            % convert canvas cm to figure cm (axes origin is at figure 0,0)
            for k = 1:numel(obj.Legends)
                r = obj.legendBox(k);
                lg = obj.Legends(k).Handle;
                lg.Position(1:2) = [r(1)-x0, r(3)-y0];
            end
        end
    end

    methods (Static)
        function bb = extentOf(hs)
            %EXTENTOF  [xmin xmax ymin ymax] in cm of graphics objects,
            %   including rotated text.
            bb = [inf -inf inf -inf];
            for h = reshape(hs, 1, [])
                if ~isgraphics(h) || ~strcmp(h.Visible, 'on'), continue; end
                if isa(h, 'matlab.graphics.primitive.Text')
                    [x, y] = FanCanvas.textCorners(h);
                elseif isa(h, 'matlab.graphics.primitive.Patch')
                    x = h.Vertices(:,1);  y = h.Vertices(:,2);
                elseif isa(h, 'matlab.graphics.chart.primitive.Quiver')
                    x = [h.XData(:); h.XData(:) + h.UData(:)];
                    y = [h.YData(:); h.YData(:) + h.VData(:)];
                elseif isprop(h, 'XData') && isprop(h, 'YData')
                    x = h.XData(:);  y = h.YData(:);
                else
                    continue
                end
                bb = FanCanvas.mergeBox(bb, [min(x) max(x) min(y) max(y)]);
            end
        end

        function t = orientedText(ax, xy, str, angle, outward, opts)
            %ORIENTEDTEXT  Text at xy with baseline angle (deg) that extends
            %   away from its anchor in the direction 'outward'. Alignment is
            %   chosen automatically unless given; text is kept upright.
            arguments
                ax
                xy (1,2) double
                str
                angle (1,1) double
                outward (1,2) double
                opts.KeepUpright (1,1) logical = true
                opts.HorizontalAlignment (1,1) string = "auto"
                opts.VerticalAlignment (1,1) string = "auto"
                opts.Interpreter (1,1) string = "tex"
                opts.Z (1,1) double = FanCanvas.ZText
            end
            a = mod(angle + 180, 360) - 180;          % [-180, 180)
            if opts.KeepUpright && (a > 90 || a <= -90)
                a = mod(a + 360, 360) - 180;          % flip by 180
            end
            [ha, va] = FanCanvas.autoAlign(a, outward);
            if opts.HorizontalAlignment ~= "auto", ha = opts.HorizontalAlignment; end
            if opts.VerticalAlignment ~= "auto",   va = opts.VerticalAlignment;   end
            t = text(ax, xy(1), xy(2), opts.Z, str, Rotation=a, ...
                HorizontalAlignment=ha, VerticalAlignment=va, ...
                Interpreter=opts.Interpreter);
        end

        function a = resolveAngle(spec, radialAngle)
            %RESOLVEANGLE  Text baseline angle from a spec:
            %   "radial" | "tangent" | "horizontal" | "vertical" | numeric deg
            if isnumeric(spec)
                a = spec;
                return
            end
            switch lower(string(spec))
                case "radial",     a = radialAngle;
                case "tangent",    a = radialAngle + 90;
                case "horizontal", a = 0;
                case "vertical",   a = 90;
                otherwise
                    error('FanCanvas:rotation', ...
                        'Rotation must be "radial", "tangent", "horizontal", "vertical" or numeric.');
            end
        end

        function fr = anchorFraction(anchor)
            %ANCHORFRACTION  [fx fy] of a named point on a box.
            switch lower(string(anchor))
                case "southwest", fr = [0   0  ];
                case "south",     fr = [0.5 0  ];
                case "southeast", fr = [1   0  ];
                case "west",      fr = [0   0.5];
                case "center",    fr = [0.5 0.5];
                case "east",      fr = [1   0.5];
                case "northwest", fr = [0   1  ];
                case "north",     fr = [0.5 1  ];
                case "northeast", fr = [1   1  ];
                otherwise
                    error('FanCanvas:anchor', 'Unknown anchor "%s".', anchor);
            end
        end

        function bb = mergeBox(a, b)
            bb = [min(a(1),b(1)) max(a(2),b(2)) min(a(3),b(3)) max(a(4),b(4))];
        end
    end

    methods (Static, Access = private)
        function [ha, va] = autoAlign(a, outward)
            % Pick the alignment whose anchor is on the side of the text
            % facing back towards the reference point.
            if norm(outward) == 0
                ha = "center"; va = "middle"; return
            end
            u = outward / norm(outward);
            b = [cosd(a), sind(a)];          % baseline direction
            n = [-sind(a), cosd(a)];         % text "up" direction
            k = mod(round(atan2d(dot(u,n), dot(u,b)) / 45), 8) + 1;
            H = ["left" "left"   "center" "right"  "right"  "right" "center" "left"];
            V = ["middle" "bottom" "bottom" "bottom" "middle" "top" "top" "top"];
            ha = H(k);  va = V(k);
        end

        function [x, y] = textCorners(t)
            % corners of a text's box, accounting for its rotation
            rot = t.Rotation;
            t.Rotation = 0;
            e = t.Extent;                    % [left bottom width height]
            t.Rotation = rot;
            p = t.Position(1:2);
            dx = e(1) + [0 e(3) e(3) 0] - p(1);
            dy = e(2) + [0 0 e(4) e(4)] - p(2);
            x = p(1) + cosd(rot)*dx - sind(rot)*dy;
            y = p(2) + sind(rot)*dx + cosd(rot)*dy;
        end
    end
end
