function [raw] = readRawFromTDMS(results,micLocation,tdmsDir)
%READRAWFROMTDMS takes the filtered results and reads the tdms file for a
%given channel when a folder name where the tdms files are stored is
%supplied
%   results     : filtered results table from readFromList, one row per case
%   micLocation : single-row table locating the microphone (phi, theta, and
%                 optionally r), same convention as makeResults
%   tdmsDir     : path to the folder holding the raw tdms files
%   raw         : table with duration, fs and the acoustic pressure per case
%
% The microphone channel, sampling frequency and sensitivity are taken from
% the noise-data table's mic attributes; the raw voltage is read from the
% matching channel of the tdms file named in each case's 'file' attribute and
% divided by the sensitivity to give pressure.
%
% Assumes the mic attributes (channel, fs, sensitivity) are present and
% identical across all rows, so the channel is resolved once from the first
% row and reused. fs and sensitivity are still read per case in case they vary.

% convert to char and read last character, if not "\" or "/" add to end
tdmsDir = char(tdmsDir);
if ~any(tdmsDir(end)==["\","/"])
    tdmsDir = [tdmsDir '/'];
end


numResults = height(results);


% check if one microphone is provided, reject if not
nLoc = height(micLocation);
if nLoc ~= 1
    error("readRawFromTDMS:tooManyLocations", ...
        "%d microphone locations given; current implementation accepts one.",nLoc)
end


% resolve the microphone channel name once from the first case (assumed the
% same across every case). This is the tdms ChannelName, e.g. "PXI1Slot3/ai0".
locVars  = string(micLocation.Properties.VariableNames);
first_result = results(1,:).("noise data"){1};
first_result_Mic = filterMicByLocation(first_result,micLocation);
activeChannel = first_result_Mic.channel{1};

rawdata = cell(numResults,1);
duration = zeros(numResults,1);
fs = zeros(numResults,1);
for i = 1:numResults
    % get sampling duration
    duration(i) = results.duration(i);
    % get sampling frequency for this case's microphone
    thisResult = results.("noise data"){i};
    thisMic = filterMicByLocation(thisResult,micLocation);
    fs(i) = thisMic.fs;

    % get sensitivity (V/Pa) used to convert voltage to pressure
    Sensitivity = thisMic.sensitivity;
    % build full path to this case's tdms file
    thisFile = results.file{i};
    thisPath = string([tdmsDir thisFile]);

    % locate the channel-group the active channel lives in (the group name is
    % dynamic per file, e.g. "mics (4499)", so it has to be looked up)
    thisTDMSinfo = tdmsinfo(thisPath);
    channelMask = thisTDMSinfo.ChannelList.ChannelName==activeChannel;
    if ~any(channelMask)
        error("readRawFromTDMS:micNotAvailable", ...
            "Requested microphone channel '%s' is not available in %s.", ...
            activeChannel,thisFile);
    end
    activeChannelGroup = thisTDMSinfo.ChannelList.ChannelGroupName(channelMask);
    % read just that one channel, then convert voltage to pressure
    voltage = tdmsread(thisPath,ChannelGroupName=activeChannelGroup,ChannelNames=activeChannel);
    pressure = table2array(voltage{1})/Sensitivity;
    rawdata{i} = pressure;


end

raw = table(duration,fs,VariableNames=["duration","fs"]);
data = cell2table(rawdata,VariableNames="acoustic pressure");
raw = [raw data];


    function [thisMic] = filterMicByLocation(micTable,thisLoc)
        % match on phi and theta, and on r when the location table supplies it
        micMask = micTable.phi == thisLoc.phi & micTable.theta == thisLoc.theta;
        if ismember("r",locVars)
            micMask = micMask & micTable.r == thisLoc.r;
        end

        if ~any(micMask)
            error("readRawFromTDMS:micNotFound", ...
                "No microphone at phi=%g, theta=%g.",thisLoc.phi,thisLoc.theta);
        elseif sum(micMask) > 1
            error("readRawFromTDMS:micAmbiguous", ...
                "%d microphones match phi=%g, theta=%g. Add an r column to disambiguate.", ...
                sum(micMask),thisLoc.phi,thisLoc.theta);
        end

        thisMic = micTable(micMask,:);
    end
end

