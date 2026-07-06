function correctedSPL = correctWindscreenSPL(F,SPL,type)
% add a correction for the windscreens used for tests, Windscreen
% characterisation carried out by Dr Sung Tyaek Go
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
end