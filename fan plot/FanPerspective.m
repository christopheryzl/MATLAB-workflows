classdef FanPerspective < handle
%FANPERSPECTIVE  A 3D scene projected onto a FanCanvas (orthographic).
%
%   p = cv.addPerspective(Name=Value)
%     Position  [x y] canvas cm where the scene origin lands   ([0 0])
%     Scale     cm on paper per scene unit                     (1.2)
%     View      [az el] in degrees, as for view()              ([225 15])
%
%   Everything is projected with viewmtx and drawn in the canvas's 2D
%   axes, so it shares the canvas's cm layout with the 2D fans. Depth is
%   kept in z, so occlusion and model lighting still work.
%
%   Methods
%     h = p.arc(theta, phi, ...)       microphone-arc fan in a plane
%     h = p.addModel(...)              STL rig model
%     h = p.arrows(tails, vectors)     3D arrows (3 x n each)
%     t = p.text(xyz, str, ...)        label at a 3D point
%     [x,y,d] = p.project(xyz)         scene (3 x n) -> canvas cm, depth
%
%   Scene coordinates of an arc at polar angle theta (from the scene x
%   axis) and azimuth phi (about x):
%       [r cos(theta); r sin(theta) cos(phi); r sin(theta) sin(phi)]

    properties (SetAccess = private)
        Canvas
        Origin (1,2) double
        Scale (1,1) double
        View (1,2) double
        Projection (3,3) double
        MaxRadius (1,1) double = 0
        Handles = gobjects(0)
    end

    methods
        function obj = FanPerspective(canvas, opts)
            arguments
                canvas (1,1) FanCanvas
                opts.Position (1,2) double = [0 0]
                opts.Scale (1,1) double {mustBePositive} = 1.2
                opts.View (1,2) double = [225 15]
            end
            obj.Canvas = canvas;
            obj.Origin = opts.Position;
            obj.Scale = opts.Scale;
            obj.View = opts.View;
            T = viewmtx(opts.View(1), opts.View(2));
            obj.Projection = T(1:3, 1:3);   % rows: screen x, screen y, depth (towards viewer)
        end

        function [x, y, d] = project(obj, xyz)
            %PROJECT  Scene points (3 x n) to canvas cm and depth (cm).
            q = obj.Scale * obj.Projection * xyz;
            x = obj.Origin(1) + q(1,:);
            y = obj.Origin(2) + q(2,:);
            d = q(3,:);
        end

        function h = arc(obj, theta, phi, opts)
            %ARC  Fan of a microphone arc: boundary lines + translucent face.
            %
            %   theta  [t1 t2] (or vector) polar angles, deg
            %   phi    azimuth of the arc's plane, deg
            %
            %   Radius      [inner outer] scene units          ([1 2])
            %   ThetaStep   tick spacing, deg                  (15)
            %   SnapTheta   round range outwards to ThetaStep  (true)
            %   Grid        draw interior ticks too            (false)
            %   GridLevels  number of radial rings if Grid     (6)
            %   FaceColor   ([1 1 1]),  FaceAlpha (0.5)
            %   EdgeColor   ([0.5 0.5 0.5]), LineWidth (0.6)
            arguments
                obj
                theta (1,:) double
                phi (1,1) double
                opts.Radius (1,2) double = [1 2]
                opts.ThetaStep (1,1) double {mustBePositive} = 15
                opts.SnapTheta (1,1) logical = true
                opts.Grid (1,1) logical = false
                opts.GridLevels (1,1) double {mustBeInteger, mustBeGreaterThanOrEqual(opts.GridLevels,2)} = 6
                opts.FaceColor = [1 1 1]
                opts.FaceAlpha (1,1) double = 0.5
                opts.EdgeColor = [0.5 0.5 0.5]
                opts.LineWidth (1,1) double = 0.6
            end
            ts = opts.ThetaStep;
            t = [min(theta) max(theta)];
            if opts.SnapTheta
                t = ts*[floor(t(1)/ts), ceil(t(2)/ts)];
            end
            R = opts.Radius;
            obj.MaxRadius = max(obj.MaxRadius, max(R));
            th = linspace(t(1), t(2), max(2, ceil(t(2) - t(1)) + 1));

            rings = R;
            rays = t;
            if opts.Grid
                rings = linspace(R(1), R(2), opts.GridLevels);
                rays = unique([t, ts*(ceil(t(1)/ts):floor(t(2)/ts))]);
            end

            ax = obj.Canvas.Axes;
            lift = 0.01;   % keep lines just in front of their own face
            style = {'Color', opts.EdgeColor, 'LineWidth', opts.LineWidth, ...
                     'HandleVisibility', 'off'};
            h = gobjects(0);

            [xo, yo, do] = obj.project(arcXYZ(th, phi, R(2)));
            [xi, yi, di] = obj.project(arcXYZ(th, phi, R(1)));
            h(end+1,1) = patch(ax, [xo fliplr(xi)], [yo fliplr(yi)], ...
                [do fliplr(di)], opts.FaceColor, FaceAlpha=opts.FaceAlpha, ...
                EdgeColor='none', FaceLighting='none', HandleVisibility='off');
            for r = rings
                [x, y, d] = obj.project(arcXYZ(th, phi, r));
                h(end+1,1) = line(ax, x, y, d + lift, style{:}); %#ok<AGROW>
            end
            for a = rays
                [x, y, d] = obj.project(arcXYZ(a, phi, R));
                h(end+1,1) = line(ax, x, y, d + lift, style{:}); %#ok<AGROW>
            end
            obj.Handles = [obj.Handles; h];
        end

        function h = addModel(obj, opts)
            %ADDMODEL  STL rig model at the scene origin.
            %
            %   Scale     scene units per metre of model        (2)
            %   Rotation  rotation about the model z axis, deg  (90)
            %   OnTop     always draw over the arcs (as the old
            %             overlay axes did); false = true depth (true)
            %   FaceAlpha (1),  Parts (rigModelParts())
            arguments
                obj
                opts.Scale (1,1) double {mustBePositive} = 2
                opts.Rotation (1,1) double = 90
                opts.OnTop (1,1) logical = true
                opts.FaceAlpha (1,1) double = 1
                opts.Parts struct = rigModelParts()
            end
            c = cosd(opts.Rotation);  s = sind(opts.Rotation);
            Rz = [c -s 0; s c 0; 0 0 1];
            M = obj.Scale * obj.Projection * Rz * (opts.Scale/1000);
            if opts.OnTop
                depth = {'Bottom', obj.Scale*max(obj.MaxRadius, 1) + 0.5};
            else
                depth = {'Top', NaN, 'Bottom', NaN};
            end
            h = drawModel(obj.Canvas.Axes, M, obj.Origin, depth{:}, ...
                FaceAlpha=opts.FaceAlpha, Parts=opts.Parts);
            obj.Handles = [obj.Handles; h(:)];
        end

        function h = arrows(obj, tails, vectors, opts)
            %ARROWS  Projected 3D arrows. tails, vectors: 3 x n scene units.
            arguments
                obj
                tails (3,:) double
                vectors (3,:) double
                opts.Color = 'k'
                opts.LineWidth (1,1) double = 0.5
                opts.MaxHeadSize (1,1) double = 0.6
            end
            [x0, y0] = obj.project(tails);
            [x1, y1] = obj.project(tails + vectors);
            h = quiver(obj.Canvas.Axes, x0, y0, x1 - x0, y1 - y0, 0, ...
                Color=opts.Color, LineWidth=opts.LineWidth, ...
                MaxHeadSize=opts.MaxHeadSize, HandleVisibility='off');
            obj.Handles(end+1,1) = h;
        end

        function t = text(obj, xyz, str, opts)
            %TEXT  Label at a 3D point.
            %   Along    3-vector; baseline follows its projection ([] = horizontal)
            %   Outward  3-vector; text extends this way from the point ([])
            arguments
                obj
                xyz (3,1) double
                str
                opts.Along double = []
                opts.Outward double = []
                opts.Interpreter (1,1) string = "tex"
            end
            [x, y] = obj.project(xyz);
            ang = 0;
            if ~isempty(opts.Along)
                [xa, ya] = obj.project(xyz + opts.Along(:));
                ang = atan2d(ya - y, xa - x);
            end
            u = [0 0];
            if ~isempty(opts.Outward)
                [xo, yo] = obj.project(xyz + opts.Outward(:));
                u = [xo - x, yo - y];
            end
            t = FanCanvas.orientedText(obj.Canvas.Axes, [x y], str, ang, u, ...
                Interpreter=opts.Interpreter);
            obj.Handles(end+1,1) = t;
        end
    end
end

function p = arcXYZ(theta, phi, r)
% scene points of an arc; theta and r may be vectors (not both)
theta = theta(:).';  r = r(:).';
p = [r.*cosd(theta); r.*sind(theta)*cosd(phi); r.*sind(theta)*sind(phi)];
end
