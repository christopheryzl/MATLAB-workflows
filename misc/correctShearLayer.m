function [Tc,dAP] = correctShearLayer(Tm,M,H,h)
%shearLayerCorrection outputs the corrected observer angle in degrees and
%the delta acoustic pressure amplitude pc/pm in dB
%
% The shear layer correction is based on Amiet's method assuming
% zero-thickness shear layer and no loss to turbulent shear layer
% scattering
%
%   Tm = theta_m, uncorrected measurement angle in degrees.
%   M = Mach number, Mach number of freestream inside the shear layer
%   H = total height, distance from source to uncorrected measurement
%   location, taken perpendicular to the shear layer
%   h = shear layer height, distance from source to shear layer, taken
%   perpendicular to the shear layer
%
% outputs
%   Tc = theta_cc, corrected measurement angle in degrees.
%   dAP = delta acoustic pressure, pc/pm in dB

x0 = [50,95]; %arbitrary initial guess
x = fsolve(@(x) angleCorrection(x,Tm,M,H,h),x0);
Tc = real(x(1));
Tt = acosd(cosd(x(2))/(1+M*cosd(x(2))));
dAP = 20*log10(sqrt(amplitudeCorrection(Tt,M,H,h)));


    function F = angleCorrection(x,Tm,M,H,h)
        % nonlinear system of equations to solve for x (eqn. 17.2.16, 17.2.17,
        % 17.2.19 Aeroacoustics of Low Mach Number Flows)

        % x(1) -> theta_m
        % x(2) -> theta_i

        F(1) = H*cotd(Tm) - h*cotd(x(1)) - (H-h)*(1/(sign(secd(x(2)))*sqrt((secd(x(2))+M)^2-1)));
        F(2) = tand(x(2)/2) - (1/(1-M))*(sqrt(cscd(x(1))^2-M^2)-cotd(x(1)));
    end

    function PCoverPm2 = amplitudeCorrection(Tt,M,H,h)
        % calculates the square of Pc^/Pm^ (eqn. 17.2.30 Aeroacoustics of Low Mach
        % Number Flows)

        xi = sqrt((1-M.*cosd(Tt)).^2-cosd(Tt).^2);

        PCoverPm2 = (1./(4.*xi.^2)) .* (h/H)^2 .* (1+(H-h)/h.*(xi.^3)./(sind(Tt).^3)) .* (1+(H-h)/h.*(xi)./sind(Tt)) .* ...
            (xi+sind(Tt).*(1-M.*cosd(Tt)).^2).^2;
    end
end