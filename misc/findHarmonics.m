function [results] = findHarmonics(results,specGroup,varargin)
% find the first n harmonics of the BPF from each row of the results,
% defaults to n = 5 and bladeN = 2. Note, this implementation expects an
% explicit SpecGroup table consisting of f, and psd. Returns results with
% harmonic SPLs appended in then noise data as "harmonic1","harmonic2",
% etc.
%
%   results: results table from readFromList
%   specGroup: spectral group from which the narrowband integration will be
%   performed, string
%   (optional)n: harmonic number upper range, default = 5
%   (optional)bladeN: blade number, default = 2
%   (optional)windscreen: boolean, apply windscreen correction, reads
%   microphone type from results table and if windscreen should be applied.
%   h5 file must have windscreen attribute
varargs = reshape(varargin,[],2);
p = struct(varargs{:});

if isfield(p,"bladeN")
    bladeN = p.bladeN;
else
    bladeN = 2;
end
if isfield(p,"n")
    n = p.n;
else
    n = 5;
end

% pass windscreen correction as boolean, defaults to false
if isfield(p,"windscreen")
    windscreen = p.windscreen;
else
    windscreen = false;
end

% make variable names for appended table
appendVariableName = strings(n,1);
for i = 1:length(appendVariableName)
    appendVariableName(i) = "harmonic"+num2str(i);
end

numRows = height(results);
for i = 1:numRows

    BPF = bladeN * results.rpm(i)/60;
    numMics = height(results.("noise data"){i}.(specGroup));
    harmonic = zeros(numMics,n);
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
        for k = 1:n
            % find closest index to the harmonic
            [~,Harmidx] = min(abs(F-k*BPF));
            % narrowband integration
            harmonic(j,k) = 10*log10((trapz(F(Harmidx-10:Harmidx+10),PSD(Harmidx-10:Harmidx+10)))/2e-5^2);
        end
    end
    % return table, column names are harmonic1, harmonic2, ...
    toAppend = array2table(harmonic,VariableNames=appendVariableName);
    % stuff back to the noise data of row i
    results.("noise data"){i} = [results.("noise data"){i},toAppend];
end
end

