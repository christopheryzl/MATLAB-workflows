function [out] = customPWelch(dF,pressure,Fs,windscreen,micType)
% Welch PSD/SPL with an optional windscreen correction.
%
% Pass windscreen = true to apply the correction; the microphone type must
% then be supplied so the right correction factor is used. The correction is a
% dB offset per frequency, applied to both SPL and PSD so oaspl reflects it.
%
% Inputs:
%   dF        : frequency resolution [Hz]
%   pressure  : time-series acoustic pressure [Pa]
%   Fs        : sample rate [Hz]
%   windscreen: (optional) logical, true when a windscreen was fitted. Default false.
%   micType   : microphone type (string/char), required when windscreen is true

    if nargin < 4 || isempty(windscreen)
        windscreen = false;
    end

    window = Fs/(dF); %windowing
    noverlap = window/2; %overlap
    nfft = window; % Equal to the window
    [PSD,F] = pwelch(pressure,window,noverlap,nfft,Fs);
    SPL = (10*log10(PSD*dF/2e-5^2));

    % windscreen correction (dB offset per frequency)
    if windscreen
        if nargin < 5 || strlength(string(micType)) == 0
            error("customPWelch:missingMicType", ...
                "windscreen is true; supply the microphone type.");
        end
        micType = string(micType);
        [correctedSPL,applied] = correctWindscreenSPL(F,SPL,micType);
        if applied
            PSD = PSD .* 10.^((correctedSPL - SPL)/10);  % carry offset into PSD
            SPL = correctedSPL;
        else
            warning("customPWelch:noWindscreenCorrection", ...
                "No windscreen correction factor for microphone type '%s'. " + ...
                "SPL left uncorrected.",micType);
        end
    end

    [~,istart] = min(abs(F-160));
    [~,iend] = min(abs(F-10000));
    iRange = istart:iend;

    X = squeeze(F(iRange));
    Y = squeeze(PSD(iRange));

    OASPL = 10*log10((trapz(X,Y)/(20e-6)^2));

    out.spl = SPL;
    out.f = F;
    out.oaspl = OASPL;
    out.psd = PSD;
end
