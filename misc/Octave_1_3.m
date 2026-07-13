function [out] = Octave_1_3(psd,f,windscreen,micType)
% Third-octave band SPL from a narrowband PSD spectrum.
%
% psd and f come from another pipeline. Pass windscreen = true to apply the
% windscreen correction; the microphone type must then be supplied so the
% right correction factor is used.
%
% Inputs:
%   psd       : narrowband power spectral density [Pa^2/Hz]
%   f         : matching frequency vector [Hz], uniform spacing assumed
%   windscreen: (optional) logical, true when a windscreen was fitted.
%               Default false.
%   micType   : microphone type (string/char), required when windscreen is true
%
% Outputs:
%   out.fc  : band centre frequencies [Hz]
%   out.spl : band SPL [dB re 20 uPa]

    if nargin < 3 || isempty(windscreen)
        windscreen = false;
    end

    pref = 20e-6;
    psd  = psd(:);
    f    = f(:);
    df   = mean(diff(f));                    % narrowband bin width

    % narrowband SPL: each bin holds a mean-square pressure of psd*df
    SPL = 10*log10(psd*df/pref^2);

    % windscreen correction (dB offset per frequency) before banding
    if windscreen
        if nargin < 4 || strlength(string(micType)) == 0
            error("Octave_1_3:missingMicType", ...
                "windscreen is true; supply the microphone type.");
        end
        micType = string(micType);
        [correctedSPL,applied] = correctWindscreenSPL(f,SPL,micType);
        if applied
            SPL = correctedSPL;
        else
            warning("Octave_1_3:noWindscreenCorrection", ...
                "No windscreen correction factor for microphone type '%s'. " + ...
                "SPL left uncorrected.",micType);
        end
    end

    % ANSI S1.11 base-10 third-octave centres (see wikipedia), 16 Hz to 20 kHz
    fcAll     = 10.^((12:43)/10);
    fLowerAll = fcAll / 10^(1/20);
    fUpperAll = fcAll * 10^(1/20);

    % keep only bands fully inside the available frequency range
    keep   = fLowerAll >= f(1) & fUpperAll <= f(end);
    fc     = fcAll(keep);
    fLower = fLowerAll(keep);
    fUpper = fUpperAll(keep);

    nBand   = numel(fc);
    bandSPL = nan(nBand,1);
    for k = 1:nBand
        inBand = f >= fLower(k) & f < fUpper(k);
        bandSPL(k) = 10*log10(sum(10.^(SPL(inBand)/10)));  % pref^2 cancels
    end

    out.fc  = fc(:);
    out.spl = bandSPL;
end
