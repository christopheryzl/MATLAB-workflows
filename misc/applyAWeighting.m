function [A_SPL] = applyAWeighting(SPL,F)
%APPLYAWEIGHTING note F must be between 6.3 and 20000 Hz 
% SPL: sound pressure level (scalar or vector)
% F: frequency (scalar or vector)
load("A_factors.mat","A_factors");
A_SPL = SPL+interp1(A_factors.F,A_factors.Aweight,F);
end

