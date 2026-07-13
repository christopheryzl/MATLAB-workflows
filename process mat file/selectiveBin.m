function [out] = selectiveBin(processedRaw,interval,varargin)
%SELECTIVEBIN bin acoustic pressure from processedRaw for given phase
%interval between [0,angle_domain] (hard coded for 2-bladed propeller at the
%moment). I resampled the bins so they'd fit in an array nicely but the
%implication is that their sampling rate would be different to the actual
%sampling rate, maybe that'll fuck the spectra, I don't know
%
%   processedRaw = processed raw table from processRawTable
%   interval = 2-element array for binning interval, for centre phase = 0
%   wrap the lower bound by 360/bladeN, e.g. [175,5]
%   (optional)bladeN = determine the angle wrap, check that the
%   processedRaw table also have this argument passed through, defaults to
%   2

varargs = reshape(varargin,2,[]);
p = struct(varargs{:});

if isfield(p,"bladeN")
    bladeN = p.bladeN;
else
    bladeN = 2;
end

phaseInfo = processedRaw.phaseInfo{1};
sourceTimePressure = processedRaw.sourceTimePressure{1};

phase_diff = phaseInfo.diff;
front = phaseInfo.front;
fs = double(processedRaw.fs);
rpm = processedRaw.rpm;
delta_rpm = processedRaw.delta_rpm;

% check for if phase range wrapped around zero
angle_domain = 360/bladeN;
if interval(1)<interval(2)
    TF = phase_diff>interval(1) & phase_diff<interval(2);
else
    TF_1 = phase_diff<interval(2) & phase_diff> 0;
    TF_2 = phase_diff>interval(1) & phase_diff<angle_domain;
    TF = TF_1 | TF_2;
end
% hard-coded ignore to avoid short head/tail 
idx_ignore=5000;

% determine appropriate MinPeakDistance guess based on the rpm delta and
% sampling frequency
guess_distance = 0.75*bladeN*fs*delta_rpm/60;
[~,peaks_forward] = findpeaks(double(TF(idx_ignore:end-idx_ignore)),MinPeakDistance=guess_distance);
[~,peaks_backward] = findpeaks(flipud(double(TF(idx_ignore:end-idx_ignore))),MinPeakDistance=guess_distance);
peaks_forward = peaks_forward+idx_ignore;
peaks_backward = peaks_backward+idx_ignore;
peaks_backward = length(TF)-peaks_backward + 1;
peaks = [peaks_forward, flipud(peaks_backward)];

% figure for debug
% figure
% plot(phaseInfo.phaseDiff)
% yyaxis right
% hold on
% plot(TF)
% scatter(peaks_forward,ones(size(peaks_forward)))
% scatter(peaks_backward,ones(size(peaks_backward)))

for i = 1:size(peaks,1)
    first_idx = find(front(peaks(i,1):end-1)-front(peaks(i,1)+1:end)>100,1,"first");
    last_idx = find(front(peaks(i,1):peaks(i,2)-1)-front(peaks(i,1)+1:peaks(i,2))>100,1,"last");
    % offset so the series starts with front rotor at zero degrees
    peaks(i,:) = [peaks(i,1)+first_idx,peaks(i,1)+last_idx];
end

% remove peak ranges that are too short (noise)
lengths = peaks(:,2)-peaks(:,1)+1;
peaks = peaks(lengths>1000,:);
% remove first and last peaks to prevent overflow
peaks = peaks(1:end,:);
% ax.ColorOrderIndex=1;
% scatter(ax,phaseInfo.time([peaks(:,1);peaks(:,2)]),phaseInfo.diff([peaks(:,1);peaks(:,2)]));
% 
% for i = 1:size(peaks,1)
% patchX = phaseInfo.time([peaks(i,1);peaks(i,1);peaks(i,2);peaks(i,2)]);
% patchY = [0;180;180;0];
% patch(ax,patchX,patchY,[0,0,1], ...
%     EdgeColor="none", ...
%     FaceAlpha=0.25);
% end

% normalised length for a single bin
normalised_length = ceil(60/(rpm*bladeN)*fs);

x_mean = zeros(size(peaks,1),normalised_length);
y_mean = zeros(size(peaks,1),normalised_length);
all_Interval_Pressure = zeros(1,normalised_length);
for i = 1:size(peaks,1)
    interval_Phase = phaseInfo(peaks(i,1):peaks(i,2),:);
    [~,time_offset] = min(abs(sourceTimePressure.time-0));
    interval_Pressure = sourceTimePressure(peaks(i,1)+time_offset:peaks(i,2)+time_offset,:);
    interval_Pressure.Pressure = highpass(interval_Pressure.Pressure,160,fs);

    % find wrap cycle
    wrap_idx = find(diff(interval_Phase.front)< -160);

    % start indices for bins
    starts_idx = [1; wrap_idx+1];
    % end indices for bins
    ends_idx = [wrap_idx;length(interval_Phase.front)];

    % calculate and trim bin size
    bin_sizes = ends_idx-starts_idx+1;
    starts_idx = starts_idx(bin_sizes >= (0.75*60/(rpm*bladeN))/(1/fs));
    bin_sizes = bin_sizes(bin_sizes >= (0.75*60/(rpm*bladeN))/(1/fs));
    %max_len = max(bin_sizes);
    
    %max_len = 500;
    % bin pressures
    binned_pressure = zeros(length(starts_idx),normalised_length);
    binned_angle = binned_pressure;
    normalised_time = linspace(0,1,normalised_length);
    for j = 1:size(binned_pressure,1)
        pressure = interval_Pressure.Pressure(starts_idx(j):starts_idx(j)+bin_sizes(j)-1);
        angle = interval_Phase.front(starts_idx(j):starts_idx(j)+bin_sizes(j)-1);
        old_time = linspace(0,1,length(pressure));
        binned_pressure(j,:) = interp1(old_time,pressure,normalised_time,"linear");
        binned_angle(j,:) = interp1(old_time,angle,normalised_time,"linear");
        all_Interval_Pressure(end+1,:) = binned_pressure(j,:);
    end
    x_mean(i,:) = mean(binned_angle,1);
    y_mean(i,:) = mean(binned_pressure,1);

end
out.meanAngle = mean(x_mean,1);
out.meanPressure = mean(y_mean,1);
out.allPressure = all_Interval_Pressure(2:end,:);
out.fluctPressure = out.allPressure-out.meanPressure;
out.fs = floor(normalised_length*rpm/(60/bladeN));
end

