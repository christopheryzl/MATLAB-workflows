addpath(genpath("C:\Users\zy17360\OneDrive - University of Bristol\PhD\Journals\2 App Aco exp baseline\revision\MATLAB-workflows"))
addpath(genpath("C:\Users\zy17360\OneDrive - University of Bristol\PhD\Journals\2 App Aco exp baseline\functions\custom polar plots"))
addpath(genpath("C:\Users\zy17360\OneDrive - University of Bristol\PhD\Journals\2 App Aco exp baseline\functions\Colors"))
load("Bang Wong colors.mat","colors"); % Bang Wong, Points of view: Color blindness, https://doi.org/10.1038/nmeth.1618
colors = colors([1:4,7:end],:); % remove some bad contrast colours

RPM = 9000;
tilt = 0:10:30;
inflow = 0:10:20;
phase = "avg";
dF = 1;
exportName = "isolated_rotor_21ms";
front = load("results_all_ms_front.mat","results");
front = front.results;

background = load("results_background.mat","results");
background = background.results;


%% process in-plane
for i = 1:height(front)
    mask = front.("noise data"){i}.phi==0;
    mask(59) = false; % round one had an extra scaling microphone for no reason
    % process OASPL
    X = double(front.("noise data"){i}.theta(mask));
    Y = front.("noise data"){i}.df1_OASPL(mask);
    Mach = double(front.inflow(i)/343);
    for j = 1:length(X)
        % note that H and h are measured parpendicular to the shear layer
        [X(j),SPL_correction(j)] = correctShearLayer(90-X(j),Mach,1.5*cosd(X(j)),0.35);
    end
    ip_front.X(:,i) = 90-X;
    ip_front.Y(:,i) = Y+SPL_correction';
end


% process background
mask = background.("noise data"){1}.phi==0;
clear X Y SPL_correction
X = double(background.("noise data"){1}.theta(mask));
Y = background.("noise data"){1}.df1_OASPL(mask);
Mach = double(background.inflow(1)/343);
for j = 1:length(X)
    % note that H and h are measured parpendicular to the shear layer
    [X(j),SPL_correction(j)] = correctShearLayer(90-X(j),Mach,1.5*cosd(X(j)),0.35);
end
BG_ip.X(:,1) = 90-X;
BG_ip.Y(:,1) = Y+SPL_correction';

%% plotting
% Everything below is in cm on paper. Absolute positions don't matter:
% cv.fit() shrinks the figure around the content at the end.
f  = figure;
cv = FanCanvas(f, Colors=colors, FontName="Times New Roman", FontSize=10);

%%%%%%%% sideline arc OASPL %%%%%%%%
fan = cv.addFan([-35 55], [75 100], Radius=[1.7 4.5]);
fan.rLabels(Which=10, Extension=5, Rotation="horizontal");
fan.tLabels(Extension=0.3);
fan.title(["Sideline", "OASPL [dB]"]);

fan.plot(ip_front.X, ip_front.Y, LineWidth=0.8);
% background: restart the colour cycle, draw beneath the model
fan.plot(BG_ip.X, BG_ip.Y, ColorIndex=1, Layer="back", LineWidth=0.6, LineStyle="--");
fan.addModel();

%%%%%%%% legend and annotations, placed relative to the fan %%%%%%%%
bb = fan.extent();   % [xmin xmax ymin ymax] including labels

proxies = gobjects(numel(tilt), 1);
for i = 1:numel(tilt)
    proxies(i) = line(cv.Axes, NaN, NaN, Color=colors(i,:), LineWidth=1.5);
end
cv.addLegend(proxies, "$\alpha = " + tilt + "^\circ$", [bb(1), bb(3) - 0.2], ...
    Anchor="northwest", Interpreter="latex", ItemTokenSize=[10 18]);

cv.flowArrow([fan.Center(1), bb(4) + 0.6]);

cv.fit(Margin=0.1);
exportgraphics(f, exportName + ".pdf", ContentType="vector");
