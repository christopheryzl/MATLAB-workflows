function [correctedPSD,applied] = correctWindscreenPSD(F,PSD,type)
% add a correction for the windscreens used for tests, Windscreen
% characterisation carried out by Dr Sung Tyaek Go, this version corrects
% the PSD since characterisation uses pure tone, so we could directly
% convert the SPL values into PSD through the inverse of dB conversion
% without knowing the dF
%
% applied is false when no correction factor exists for that microphone type,
% in which case SPL is returned unchanged. The caller decides how to report it.
type = string(type);
applied = true;

switch type
    case "40PL"
        load("40PL correction.mat","Correction_SPL","Correction_freq");
    case "46BE"
        load("46BE correction.mat","Correction_SPL","Correction_freq");
    otherwise
        correctedPSD = PSD;
        applied = false;
        return
end

% pad the correction arrays so it's valid from 1Hz
Correction_freq = [1,Correction_freq];
Correction_SPL = [0,Correction_SPL];

correction_psd = interp1(Correction_freq,Correction_SPL,F,'linear');
correction_psd = 10.^(-correction_psd./10);
correctedPSD = PSD .* correction_psd;

end
