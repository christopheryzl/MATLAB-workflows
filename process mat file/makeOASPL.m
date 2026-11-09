function [phi,theta,OASPL] = makeOASPL(results,micLocations,varargin)
% Extract the overall SPL from a readFromList results table for a set of
% microphone locations, applying the windscreen correction where one was
% fitted.
%
% The results table is used as given: filter and sort it to the cases wanted
% before calling. Row j of results becomes column j of the output, and row i
% of micLocations becomes row i of the output.
%
% Inputs:
%   results      : results table from readFromList, already filtered to the
%                  cases of interest
%   micLocations : table of one or more microphone locations, all lying on a
%                  single arc: either every row shares the same theta, or
%                  every row shares the same phi.
%                  Required columns: phi, theta
%                  Optional columns: r          - also matched on when present
%                                    windscreen - logical, true when a windscreen
%                                                 was fitted at that location.
%                                                 The correction to apply is
%                                                 then taken from the
%                                                 microphone's own 'type'
%                                                 attribute.
%                                                 Absent column => no correction.
%
% Optional name/value arguments:
%   SpecGroup  : spectrum group whose OASPL is read, i.e. the column
%                "<SpecGroup>_OASPL" of each mic table (default "df4")
%   ExportName : if given, OASPL is also saved to this .mat file
%
% Outputs:
%   OASPL   : [nMic x nCase] matrix of (corrected) overall SPL.
%   theta   : [nMic x nCase] matrix of microphone elevations.
%   phi     : [nMic x nCase] matrix of microphone azimuths.
%
% Windscreen correction:
%   The stored OASPL is a single number, so the frequency-dependent
%   windscreen correction cannot be applied to it directly. Instead the
%   matching spectrum (same SpecGroup) is corrected, and the change in its
%   energy sum is added to the stored OASPL:
%
%       OASPL_corr = OASPL_stored + 10*log10( sum(10.^(SPL_corr/10)) / ...
%                                             sum(10.^(SPL_raw /10)) )
%
%   This difference does not depend on the dB reference or on a uniform bin
%   width, so it holds whether spl is per-bin SPL or PSD in dB/Hz. It does
%   assume the stored OASPL was integrated over the same frequency range as
%   the stored spectrum.
%
% Where a windscreen is flagged but no correction factor exists for that
% microphone type, a warning is raised once and the OASPL is left uncorrected.

varargs = reshape(varargin,2,[]);
p = struct(varargs{:});

if isfield(p,'SpecGroup')
    specGroup = string(p.SpecGroup);
else
    specGroup = "df4";   % fallback: original hard-coded group
end
oasplVar = specGroup + "_OASPL";

dataSize = height(results);
locVars  = string(micLocations.Properties.VariableNames);
warnedTypes = strings(0);   % types already warned about, to avoid repeat warnings

%% check the microphone locations
nLoc = height(micLocations);

if nLoc == 0
    error("makeOASPL:noLocations","No microphone locations given.")
end

% all microphones must lie on one arc: a single theta or a single phi
oneTheta = numel(unique(micLocations.theta)) == 1;
onePhi   = numel(unique(micLocations.phi))   == 1;
if ~(oneTheta || onePhi)
    error("makeOASPL:notOneArc", ...
        "Microphone locations span %d theta and %d phi values; " + ...
        "either theta or phi must be the same for every row.", ...
        numel(unique(micLocations.theta)),numel(unique(micLocations.phi)))
end

% windscreen flag for each location, resolved once
useWindscreen = false(nLoc,1);
for i = 1:nLoc
    useWindscreen(i) = locationHasWindscreen(micLocations(i,:));
end

OASPL   = zeros(nLoc,dataSize);
theta   = zeros(nLoc,dataSize);
phi     = zeros (nLoc,dataSize);

%% read each microphone's OASPL for every case
for j = 1:dataSize
    micTable = results(j,:).("noise data"){1};

    for i = 1:nLoc
        thisLoc = micLocations(i,:);
        thisMic = filterMicByLocation(micTable,thisLoc);

        if ~ismember(oasplVar,string(thisMic.Properties.VariableNames))
            error("makeOASPL:noOASPL", ...
                "Case %d has no '%s' column for the microphone at phi=%g, theta=%g.", ...
                j,oasplVar,thisLoc.phi,thisLoc.theta);
        end
        OASPL(i,j)  = readScalar(thisMic.(oasplVar));
        theta(i,j)  = thisMic.theta;
        phi(i,j)    = thisMic.phi;

        % correct for the windscreen, using the microphone's own type
        if useWindscreen(i)
            micType = string(thisMic.type);
            spec    = thisMic.(specGroup){1};
            [correctedSPL,applied] = correctWindscreenSPL(spec.f(:),spec.spl(:),micType);

            if applied
                OASPL(i,j) = OASPL(i,j) + energyDelta(spec.spl(:),correctedSPL(:));
            else
                warnOncePerType(micType);
            end
        end
    end
end

if isfield(p,'ExportName')
    save(p.ExportName,"OASPL");
end

    function [val] = readScalar(stored)
        % the OASPL may be stored directly or wrapped in a cell
        if iscell(stored)
            stored = stored{1};
        end
        if ~isscalar(stored)
            error("makeOASPL:notScalar", ...
                "'%s' holds %d values; expected a single number.", ...
                oasplVar,numel(stored));
        end
        val = double(stored);
    end

    function [dL] = energyDelta(splRaw,splCorr)
        % change in overall level caused by correcting the spectrum
        dL = 10*log10( sum(10.^(splCorr/10)) / sum(10.^(splRaw/10)) );
    end

    function [thisMic] = filterMicByLocation(micTable,thisLoc)
        % match on phi and theta, and on r when the location table supplies it
        micMask = micTable.phi == thisLoc.phi & micTable.theta == thisLoc.theta;
        if ismember("r",locVars)
            micMask = micMask & micTable.r == thisLoc.r;
        end

        if ~any(micMask)
            error("makeOASPL:micNotFound", ...
                "No microphone at phi=%g, theta=%g.",thisLoc.phi,thisLoc.theta);
        elseif sum(micMask) > 1
            error("makeOASPL:micAmbiguous", ...
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

        warning("makeOASPL:noWindscreenCorrection", ...
            "No windscreen correction factor for microphone type '%s'. " + ...
            "OASPL left uncorrected.",micType);
        warnedTypes(end+1) = micType;
    end

end