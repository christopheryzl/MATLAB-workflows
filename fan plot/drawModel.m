function h = drawModel(ax, M, origin, opts)
%DRAWMODEL  Draw STL parts on a FanCanvas axes, already projected.
%
%   h = drawModel(ax, M, origin, Name=Value)
%     M       3x3 matrix taking model mm to canvas [x; y; depth] in cm
%             (scale * view projection * model rotation)
%     origin  [x y] canvas cm where the model origin lands
%
%   Options
%     Top / Bottom  shift depth so the highest / lowest point sits at this
%                   z (layering against other objects). Default: Top = 0.
%                   Set both to NaN to keep the true projected depth.
%     FaceAlpha     (1)
%     Parts         struct array, see rigModelParts
%
%   STL files are read once per session and cached.
arguments
    ax
    M (3,3) double
    origin (1,2) double
    opts.Top (1,1) double = 0
    opts.Bottom (1,1) double = NaN
    opts.FaceAlpha (1,1) double = 1
    opts.Parts struct = rigModelParts()
end

V = cell(numel(opts.Parts), 1);
F = V;
for k = 1:numel(opts.Parts)
    tr = readSTL(opts.Parts(k).File);
    V{k} = (tr.Points + opts.Parts(k).Offset) * M.';
    F{k} = tr.ConnectivityList;
end

allV = vertcat(V{:});
if isfinite(opts.Bottom)
    dz = opts.Bottom - min(allV(:,3));
elseif isfinite(opts.Top)
    dz = opts.Top - max(allV(:,3));
else
    dz = 0;
end

h = gobjects(numel(V), 1);
for k = 1:numel(V)
    v = V{k} + [origin, dz];
    h(k) = patch(ax, Faces=F{k}, Vertices=v, ...
        FaceColor=opts.Parts(k).Color, EdgeColor='none', ...
        FaceAlpha=opts.FaceAlpha, HandleVisibility='off');
end
material(h, 'dull');
if isempty(findobj(ax, 'Type', 'light'))
    camlight(ax, 'headlight');   % the camera looks straight down in view(2)
end
end

function tr = readSTL(file)
persistent cache
if isempty(cache)
    cache = containers.Map('KeyType', 'char', 'ValueType', 'any');
end
key = char(file);
if ~isKey(cache, key)
    tr = stlread(key);
    cache(key) = struct('Points', double(tr.Points), ...
        'ConnectivityList', tr.ConnectivityList);
end
tr = cache(key);
end
