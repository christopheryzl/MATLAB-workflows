function p = micArrayPerspective(canvas, opts)
%MICARRAYPERSPECTIVE  3D sketch of the four microphone arcs + rig model.
%   Replaces addPerspective. Drawn on a FanCanvas like any 2D fan, so it
%   is placed in cm rather than with a separate axes position.
%
%   p = micArrayPerspective(cv, Name=Value)
%     Position        [x y] canvas cm of the scene origin       ([0 0])
%     Scale           cm per scene unit (arcs span r = 1..2)    (1.2)
%     View            [az el]                                   ([225 15])
%     Highlight       arc(s) to shade: 0 sideline, 1 upstream,
%                     2 midstream, 3 downstream                 ([])
%     HighlightColor                                            ([.5 .5 .5])
%     Model           draw the rig model                        (true)
%     ModelAlpha                                                (1)
%     FlowLabel       draw the U_inf arrows                     (true)
arguments
    canvas (1,1) FanCanvas
    opts.Position (1,2) double = [0 0]
    opts.Scale (1,1) double {mustBePositive} = 1.2
    opts.View (1,2) double = [225 15]
    opts.Highlight double {mustBeMember(opts.Highlight, 0:3)} = []
    opts.HighlightColor (1,3) double = [0.5 0.5 0.5]
    opts.Model (1,1) logical = true
    opts.ModelAlpha (1,1) double = 1
    opts.FlowLabel (1,1) logical = true
end

p = canvas.addPerspective(Position=opts.Position, Scale=opts.Scale, View=opts.View);

%           id  theta        phi
arcs = {    3,  [45 105],    240     % downstream
            2,  [45 105],    270     % midstream
            1,  [45 105],    300     % upstream
            0,  [305 395],   0   };  % sideline
for k = 1:size(arcs, 1)
    face = [1 1 1];
    if ismember(arcs{k,1}, opts.Highlight)
        face = opts.HighlightColor;
    end
    p.arc(arcs{k,2}, arcs{k,3}, FaceColor=face);
end

if opts.Model
    p.addModel(FaceAlpha=opts.ModelAlpha);
end

if opts.FlowLabel
    p.arrows([-0.25 0 0.25; 2 2 2; 0 0 0], repmat([0; -0.5; 0], 1, 3));
    p.text([0; 2.6; 0], "$U_\infty$", Interpreter="latex", Outward=[0 1 0]);
end
end
