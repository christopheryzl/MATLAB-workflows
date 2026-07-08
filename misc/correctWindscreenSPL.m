function [correctedSPL,applied] = correctWindscreenSPL(F,SPL,type)
% add a correction for the windscreens used for tests, Windscreen
% characterisation carried out by Dr Sung Tyaek Go
%
% applied is false when no correction factor exists for that microphone type,
% in which case SPL is returned unchanged. The caller decides how to report it.
type = string(type);
applied = true;

switch type
    case "40PL"
        load("40PL correction.mat","Correction_SPL","Correction_freq");
        Correction_freq = [1,Correction_freq];
        Correction_SPL = [0,Correction_SPL];
        correctedSPL = SPL + -1 .* interp1(Correction_freq,Correction_SPL,F,'linear');
    case "46BE"
        load("46BE correction.mat","Correction_SPL","Correction_freq");
        Correction_freq = [1,Correction_freq];
        Correction_SPL = [0,Correction_SPL];
        correctedSPL = SPL + -1 .* interp1(Correction_freq,Correction_SPL,F,'linear');
    otherwise
        % no characterisation for this microphone type
        correctedSPL = SPL;
        applied = false;
end
end
