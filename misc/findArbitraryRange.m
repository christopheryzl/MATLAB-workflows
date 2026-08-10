function [results] = findArbitraryRange(results,specGroup,f_range,varargin)
% find the SPL between the integration range from each row of the results,
% Note, this implementation expects an explicit SpecGroup table consisting 
% of f, and psd. Returns results with SPL from the integration range as
% "broadband" or customly added name appended in then noise data table
%
%   results: results table from readFromList
%   specGroup: spectral group from which the SPL integration will be
%   performed, string
%   f_range: [lower limit, upper limit] integration range, alternatively,
%   give the f_range as a nx2 vector, i.e. [lower limit 1, uppter limit 1;
%   ... ;lower limit n, upper limit n]
%   (optional) name: name for exported table column (string), default: broadband
%   (optional) windscreen: boolean true if windscreen correction should be
%   applied

varargs = reshape(varargin,[],2);
p = struct(varargs{:});

if isfield(p,"name")
    appendVariableName = p.name;
else
    appendVariableName = "broadband";
end

% pass windscreen correction as boolean, defaults to false
if isfield(p,"windscreen")
    windscreen = p.windscreen;
else
    windscreen = false;
end

numRows = height(results);
for i = 1:numRows

    numMics = height(results.("noise data"){i}.(specGroup));
    to_append = zeros(numMics,1);
    for j = 1:numMics
        F = results.("noise data"){i}.(specGroup){j}.f;
        PSD = results.("noise data"){i}.(specGroup){j}.psd;
        if windscreen && matches(results.("noise data"){i}.windscreen(j),'TRUE')
            % check each microphone if windscreen correction should be
            % applied

            [PSD,message] = correctWindscreenPSD(F,PSD,results.("noise data"){i}.type{j});
            if ~message
                display("windscreen not applied for microphone type "+results.("noise data"){i}.type{j});
            end

        end
        [n,~] = size(f_range);
        if n == 1
        % find closest index to the minimum
        [~,minidx] = min(abs(F-f_range(1)));
        % to maximum
        [~,maxidx] = min(abs(F-f_range(2)));
        % narrowband integration
        to_append(j) = 10*log10((trapz(F(minidx:maxidx),PSD(minidx:maxidx)))/2e-5^2);
        else
            psd_chunk = zeros(n,1);
            for k = 1:n
                % find closest index to the minimum
                [~,minidx] = min(abs(F-f_range(k,1)));
                % to maximum
                [~,maxidx] = min(abs(F-f_range(k,2)));
                psd_chunk(k) = trapz(F(minidx:maxidx),PSD(minidx:maxidx));
            end
        to_append(j) = 10*log10(sum(psd_chunk)/2e-5^2);
        end

    end
    % return table
    toAppend = array2table(to_append,VariableNames=appendVariableName);
    % stuff everything back to the noise data of row i
    results.("noise data"){i} = [results.("noise data"){i},toAppend];
end
end

