function [out] = directBin(processedRaw,varargin)
%DIRECTBIN bins the entire acoustic pressure history from processedRaw
%directly, you do not need to provide an interval. It will automatically
%pick the point where the front rotor returns to 0 deg
%I resampled the bins so they'd fit in an array nicely but the
%implication is that their sampling rate would be different to the actual
%sampling rate, maybe that'll fuck the spectra, I don't know
%
%   processedRaw = processed raw table from processRawTable
%   (optional)bladeN = determine the angle wrap, check that the
%   processedRaw table also have this argument passed through, defaults to
%   2
%   (optional)phaseShift = apply a fudge factor until I can check the
%   offset angles for all the test cases
%   out.meanAngle = mean front phase angle
%   out.meanPressure = mean acoustic pressure over all bins (tonal)
%   out.allPressure = raw pressure over all bins
%   out.fluctPressure = pressure with mean subtracted (broadband)
%   out.fs = new sampling frequency after fudgery
varargs = reshape(varargin,2,[]);
p = struct(varargs{:});

% make the tables align in time
phaseInfo = processedRaw.phaseInfo{1};
sourceTimePressure = processedRaw.sourceTimePressure{1};
sourceTimePressure = sourceTimePressure(sourceTimePressure.time>=0,:);
phaseInfo = phaseInfo(1:height(sourceTimePressure),:);
% 
% pressure_table = processed_raw.sourceTimePressure{1};
% pressure_table = pressure_table(pressure_table.time>=0,:);
% phase_table = processed_raw.phaseInfo{1}(1:height(pressure_table),:);

phase_diff = phaseInfo.diff;
front = phaseInfo.front;
fs = double(processedRaw.fs);
rpm = processedRaw.rpm;

normalised_length = ceil(60/(rpm)*fs);


% find wrap cycle
wrap_idx = find(diff(front)< -160);

% start indices for bins
starts_idx = [1; wrap_idx+1];
% end indices for bins
ends_idx = [wrap_idx;length(front)];

% remove first few bins because encoder is doing some weird fuckery
starts_idx = starts_idx(10:end);
ends_idx = ends_idx(10:end);

% calculate and trim bin size
bin_sizes = ends_idx-starts_idx+1;
starts_idx = starts_idx(bin_sizes >= (0.75*60/(rpm))/(1/fs));
bin_sizes = bin_sizes(bin_sizes >= (0.75*60/(rpm))/(1/fs));
%max_len = max(bin_sizes);

%max_len = 500;
% bin pressures
all_Binned_Pressure = zeros(1,normalised_length);
binned_pressure = zeros(length(starts_idx),normalised_length);
binned_angle = binned_pressure;
normalised_time = linspace(0,1,normalised_length);
for j = 1:size(binned_pressure,1)
    pressure = sourceTimePressure.Pressure(starts_idx(j):starts_idx(j)+bin_sizes(j)-1);
    angle = front(starts_idx(j):starts_idx(j)+bin_sizes(j)-1);
    old_time = linspace(0,1,length(pressure));
    binned_pressure(j,:) = interp1(old_time,pressure,normalised_time,"linear");
    binned_angle(j,:) = interp1(old_time,angle,normalised_time,"linear");
    all_Binned_Pressure(end+1,:) = binned_pressure(j,:);
end
x_mean = mean(binned_angle,1);
y_mean = mean(binned_pressure,1);

if isfield(p,"phaseShift")
    out.meanAngle = rad2deg(wrapTo360(deg2rad(x_mean+p.phaseShift)));
else
    out.meanAngle = x_mean;
end
out.meanPressure = y_mean;
out.allPressure = all_Binned_Pressure(2:end,:);
out.fluctPressure = out.allPressure-out.meanPressure;
out.fs = floor(normalised_length*rpm/(60));
end

