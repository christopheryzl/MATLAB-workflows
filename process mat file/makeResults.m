function [X,Y] = makeResults(results,micLocations,varargin)
% Extract spectra from a readFromList results table for a single microphone
% location, applying the windscreen correction where one was fitted.
%
% The results table is used as given: filter and sort it to the cases wanted
% before calling. Row j of results becomes column j of the outputs.
%
% Inputs:
%   results      : results table from readFromList, already filtered to the
%                  cases of interest
%   micLocations : table holding exactly one microphone location.
%                  Required columns: phi, theta
%                  Optional columns: r          - also matched on when present
%                                    windscreen - logical, true when a windscreen
%                                                 was fitted. The correction to
%                                                 apply is then taken from the
%                                                 microphone's own 'type'
%                                                 attribute.
%                                                 Absent column => no correction.
%
% Optional name/value arguments:
%   SpecGroup  : spectrum group to read from each mic (default "df4")
%   ExportName : if given, X and Y are also saved to this .mat file
%
% Outputs:
%   X, Y : [nFreq x nCase] matrices of frequency and (corrected) SPL.
%
% Where a windscreen is flagged but no correction factor exists for that
% microphone type, a warning is raised once and the SPL is left uncorrected.

varargs = reshape(varargin,2,[]);
p = struct(varargs{:});

if isfield(p,'SpecGroup')
    specGroup = string(p.SpecGroup);
else
    specGroup = "df4";   % fallback: original hard-coded group
end

dataSize = height(results);
locVars  = string(micLocations.Properties.VariableNames);
warnedTypes = strings(0);   % types already warned about, to avoid repeat warnings

%% resolve the single microphone location
nLoc = height(micLocations);

% check if one microphone is provided, reject if not
if nLoc ~= 1
    error("makeResults:tooManyLocations", ...
        "%d microphone locations given; current implementation accepts one.",nLoc)
end

thisLoc = micLocations(1,:);
useWindscreen = locationHasWindscreen(thisLoc);

% take the spectrum length from the first case, so the output can be
% preallocated. A case whose spectrum differs in length then errors on
% assignment below rather than silently reshaping.
first_result = results(1,:).("noise data"){1};
first_result_Mic = filterMicByLocation(first_result,thisLoc);
specLength = length(first_result_Mic.(specGroup){1}.spl);
F   = zeros(specLength,dataSize);
SPL = F;

%% read that microphone's spectrum for every case
for j = 1:dataSize
    thisResult = results(j,:);

    % pick the microphone at this location
    micTable = thisResult.("noise data"){1};
    thisMic  = filterMicByLocation(micTable,thisLoc);

    spec = thisMic.(specGroup){1};
    F(:,j)   = spec.f;
    SPL(:,j) = spec.spl;

    % correct for the windscreen, using the microphone's own type
    if useWindscreen
        micType = string(thisMic.type);
        [correctedSPL,applied] = correctWindscreenSPL(F(:,j),SPL(:,j),micType);

        if applied
            SPL(:,j) = correctedSPL;
        else
            warnOncePerType(micType);
        end
    end
end
 
X = F;
Y = SPL;

if isfield(p,'ExportName')
    save(p.ExportName,"X","Y");
end

    function [thisMic] = filterMicByLocation(micTable,thisLoc)
        % match on phi and theta, and on r when the location table supplies it
        micMask = micTable.phi == thisLoc.phi & micTable.theta == thisLoc.theta;
        if ismember("r",locVars)
            micMask = micMask & micTable.r == thisLoc.r;
        end

        if ~any(micMask)
            error("makeResults:micNotFound", ...
                "No microphone at phi=%g, theta=%g.",thisLoc.phi,thisLoc.theta);
        elseif sum(micMask) > 1
            error("makeResults:micAmbiguous", ...
                "%d microphones match phi=%g, theta=%g. Add an r column to disambiguate.", ...
                sum(micMask),thisLoc.phi,thisLoc.theta);
        end

        thisMic = micTable(micMask,:);
    end

    function [tf] = locationHasWindscreen(thisLoc)
        % a missing windscreen column means no windscreen was fitted
        if ~ismember("windscreen",locVars)
            tf = false;
            return
        end

        tf = logical(thisLoc.windscreen);
    end

    function warnOncePerType(micType)
        % one warning per microphone type, not one per case
        if any(warnedTypes == micType)
            return
        end

        warning("makeResults:noWindscreenCorrection", ...
            "No windscreen correction factor for microphone type '%s'. " + ...
            "SPL left uncorrected.",micType);
        warnedTypes(end+1) = micType;
    end

end
