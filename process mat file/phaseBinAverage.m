function [out_legacy,out] = phaseBinAverage(processed_raw,psi_c,psi_width, opts)
%PHASEBINAVERAGE  Average a signal onto a phase grid using sparse valid intervals.
%
%   out = phaseBinAverage(tx, x, tpsi, psi, valid) maps each sample of x to
%   the shaft angle psi at the same instant, accumulates all samples falling
%   in each angular bin, and returns the bin-averaged periodic signal. No
%   segment is required to span a full revolution: samples are indexed by
%   angle, not by revolution, so partial revolutions from many disjoint
%   intervals contribute to the same average.
%
%   INPUTS
%     processed_raw   data table from processRaw function
%     x     [Nt x Nc] data, one column per channel (e.g. microphone)
%     psi_c  [1 x 1]  centre phase angle for selective binning
%     psi_width [1 x 1]  binning width
%
%   NAME-VALUE OPTIONS
%     Resolution   bin width (deg), default 1. Period/Resolution must be an
%                  integer.
%     Period       angular period of the output (deg), default 360. Use
%                  360/B to fold onto one blade passage.
%     Splat        true (default) spreads each sample linearly over the two
%                  nearest bin centres; false assigns to the nearest bin.
%                  Splatting removes the staircase bias when bins are
%                  comparable to the sample spacing.
%     Detrend      'none' | 'mean' (default) | 'linear', applied per segment
%                  so that DC offset or slow drift between intervals does
%                  not leak into the average.
%     MinCount     minimum effective sample weight for a bin to be treated
%                  as observed, default 1.
%     FillMethod   'pchip' (default) | 'linear' | 'spline' | 'none',
%                  interpolation used to fill unobserved bins. The grid is
%                  extended periodically before interpolation so the fill is
%                  continuous across 0/Period.
%     MinSegment   shortest contiguous valid run to keep, in samples,
%                  default 8.
%     AngleWrapped true (default) if psi is wrapped and must be unwrapped
%                  before interpolation onto tx.
%     n_blade      2 (default) int16 scalar, number of blades
%
%   OUTPUT (struct)
%     theta     [nb x 1]  bin centres (deg)
%     mean      [nb x Nc] averaged signal with unobserved bins filled
%     meanRaw   [nb x Nc] averaged signal, NaN where unobserved
%     std       [nb x Nc] weighted standard deviation within each bin
%     count     [nb x 1]  effective sample weight per bin
%     observed  [nb x 1]  logical, bins that met MinCount
%     coverage  fraction of bins observed
%     nSeg      number of valid segments used
%     opts      settings used
%
%   NOTE ON RESOLUTION
%     The expected weight per bin is
%         (fs * 60 / rpm) / (Period / Resolution) * (revolutions observed).
%     Choosing Resolution finer than the sample spacing in angle,
%     360 * rpm / (60 * fs), guarantees empty bins on every pass and the
%     result becomes an interpolation of single samples rather than an
%     average. A warning is issued if this is the case.

arguments
    processed_raw
    psi_c
    psi_width
    opts.Resolution       (1,1) double {mustBePositive} = 1
    opts.Period           (1,1) double {mustBePositive} = 360
    opts.Splat            (1,1) logical = true
    opts.Detrend          (1,:) char {mustBeMember(opts.Detrend,{'none','mean','linear'})} = 'mean'
    opts.MinCount         (1,1) double {mustBePositive} = 1
    opts.FillMethod       (1,:) char {mustBeMember(opts.FillMethod,{'pchip','linear','spline','none'})} = 'pchip'
    opts.MinSegment       (1,1) double {mustBePositive} = 8
    opts.AngleWrapped     (1,1) logical = true
    opts.n_blade          (1,1) double = 2
    opts.debug            (1,:) char {mustBeMember(opts.debug,{'on','off'})} = 'on'
end
%import variables from raw table
%I will trim the angle and pressure so they are defined over the same
%interval, they are already in observer time
pressure_table = processed_raw.sourceTimePressure{1};
pressure_table = pressure_table(pressure_table.time>=0,:);
phase_table = processed_raw.phaseInfo{1}(1:height(pressure_table),:);
half_width = psi_width/2;
rpm = processed_raw.rpm(1);

t_pressure = pressure_table.time;
pressure = pressure_table.Pressure;
t_psi = phase_table.time;
psi = phase_table.diff;
psi_1 = phase_table.front;

psi_blade = 360/opts.n_blade;

valid = abs(mod(psi - psi_c + psi_blade/2, psi_blade) - psi_blade/2) <= half_width;

if matches(opts.debug,'on')
    % debug figure
    figure('Color','w','Position',[100 100 900 700]);
    hold on; grid on;
    plot(t_psi, psi, 'k-');
    plot(t_psi(valid), psi(valid), '.', 'Color',[0.85 0.33 0.10], 'MarkerSize', 4);
    yticks(0:45:psi_blade);
    xlabel('time [s]'); ylabel('\psi [deg]');
    title(sprintf('relative phase, accepted samples for \\psi_c = %g^\\circ', psi_c));

end

% ---------------------------------------------------------------- checks
if numel(t_pressure) ~= size(pressure,1)
    error('phaseBinAverage:size','tx and x must have the same number of rows.');
end
if numel(t_psi) ~= numel(psi_1)
    error('phaseBinAverage:size','tpsi and psi must be the same length.');
end
n_bins = round(opts.Period/opts.Resolution);
if abs(n_bins*opts.Resolution - opts.Period) > 1e-9
    error('phaseBinAverage:grid','Period/Resolution must be an integer.');
end
dth = opts.Period/n_bins;
n_channels  = size(pressure,2);

% ------------------------------------------- angle onto the data timebase
if isequal(t_psi, t_pressure)
    psiX = psi_1;
    if opts.AngleWrapped
        psiX = rad2deg(unwrap(deg2rad(psi_1)));
    end
else
    if any(diff(t_psi) <= 0)
        error('phaseBinAverage:tpsi','tpsi must be strictly increasing.');
    end
    p = psi_1;
    if opts.AngleWrapped
        p = rad2deg(unwrap(deg2rad(psi_1)));   % unwrap BEFORE interpolating,
    end                                      % never interpolate across a 360 jump
    psiX = interp1(t_psi, p, t_pressure, 'linear', NaN);
end

% ------------------------------------------------------------ valid mask
if islogical(valid)
    m = valid(:);
    if numel(m) ~= numel(t_pressure)
        error('phaseBinAverage:mask','logical valid must be the length of tx.');
    end
else
    if size(valid,2) ~= 2
        error('phaseBinAverage:intervals','interval form of valid must be [M x 2].');
    end
    m = false(size(t_pressure));
    for k = 1:size(valid,1)
        m = m | (t_pressure >= valid(k,1) & t_pressure <= valid(k,2));
    end
end
m = m & isfinite(psiX) & all(isfinite(pressure),2);

% --------------------------------------------------- contiguous segments
d  = diff([false; m; false]);
s0 = find(d ==  1);
s1 = find(d == -1) - 1;
len = s1 - s0 + 1;
keep = len >= opts.MinSegment;
s0 = s0(keep); s1 = s1(keep);
nSeg = numel(s0);
if nSeg == 0
    error('phaseBinAverage:empty','No valid segment longer than MinSegment samples.');
end

% ------------------------------------------------------- accumulate bins
sumW  = zeros(n_bins,1);
sumX  = zeros(n_bins,n_channels);
sumX2 = zeros(n_bins,n_channels);

for k = 1:nSeg
    idx = s0(k):s1(k);
    x_segment  = pressure(idx,:);

    switch opts.Detrend
        case 'mean'
            x_segment = x_segment - mean(x_segment,1);
        case 'linear'
            ts = t_pressure(idx) - mean(t_pressure(idx));
            A  = [ones(numel(idx),1) ts];
            x_segment = x_segment - A*(A\x_segment);
    end

    % position on the bin grid, in units of bins, in [0,nb)
    pb = mod(psiX(idx), opts.Period)/dth;

    if opts.Splat
        u  = pb - 0.5;                 % relative to bin centres
        k0 = floor(u);
        f  = u - k0;
        ii = [mod(k0,n_bins)+1; mod(k0+1,n_bins)+1];
        ww = [1-f; f];
    else
        ii = mod(floor(pb),n_bins) + 1;
        ww = ones(numel(idx),1);
    end
    xx = repmat(x_segment, size(ii,1)/numel(idx), 1);

    sumW = sumW + accumarray(ii, ww, [n_bins 1]);
    for c = 1:n_channels
        sumX(:,c)  = sumX(:,c)  + accumarray(ii, ww.*xx(:,c),    [n_bins 1]);
        sumX2(:,c) = sumX2(:,c) + accumarray(ii, ww.*xx(:,c).^2, [n_bins 1]);
    end
end

% ------------------------------------------------------------- reduction
theta    = ((1:n_bins)' - 0.5)*dth;
observed = sumW >= opts.MinCount;

meanRaw = nan(n_bins,n_channels);
sdev    = nan(n_bins,n_channels);
w = sumW(observed);
for c = 1:n_channels
    mu = sumX(observed,c)./w;
    meanRaw(observed,c) = mu;
    sdev(observed,c) = sqrt(max(sumX2(observed,c)./w - mu.^2, 0));
end

% --------------------------------------------------- periodic gap filling
xm = meanRaw;
if ~strcmp(opts.FillMethod,'none') && any(~observed) && any(observed)
    tg = theta(observed);
    te = [tg - opts.Period; tg; tg + opts.Period];
    for c = 1:n_channels
        yg = meanRaw(observed,c);
        xm(:,c) = interp1(te, [yg; yg; yg], theta, opts.FillMethod);
    end
end

% ------------------------------------------------------------- reporting
cov = mean(observed);
spacingWarn = [];
dt = median(diff(t_pressure));
if nSeg > 0 && isfinite(dt)
    dpsi = median(abs(diff(psiX(s0(1):s1(1)))));   % deg per sample
    if dpsi > dth
        spacingWarn = sprintf(['Bin width %.3g deg is finer than the angular ' ...
            'sample spacing %.3g deg; bins can only be filled by successive ' ...
            'passes, not within one pass.'], dth, dpsi);
        warning('phaseBinAverage:resolution','%s', spacingWarn);
    end
end
if cov < 1
    warning('phaseBinAverage:coverage', ...
        '%d of %d bins unobserved (%.1f%% coverage); filled by %s interpolation.', ...
        sum(~observed), n_bins, 100*cov, opts.FillMethod);
end

out = struct('theta',theta,'mean',xm,'meanRaw',meanRaw,'std',sdev, ...
             'count',sumW,'observed',observed,'coverage',cov, ...
             'nSeg',nSeg,'segIdx',[s0 s1],'opts',opts,'note',spacingWarn);
out_legacy.meanAngle = theta;
out_legacy.meanPressure = xm;
out_legacy.allPressure = xm;
out_legacy.fluctPressure = zeros(size(xm));
out_legacy.fs = floor(length(theta*rpm/(60)));
end
