function [noiseTable] = readNoiseData(fileName,thisGroup,microphones,micsAttrsName,specGroups)
% read noise data for every microphone in one case group. specGroups is a
% string array of spectrum subgroups to read (e.g. ["df1","df4"]); defaults
% to ["df1","df4"] when omitted. Returns a table with mic attributes
% prepended and, per spectrum group, a <group> data column (f/psd/spl table)
% plus a <group>_OASPL scalar column.

if nargin < 5 || isempty(specGroups)
    specGroups = ["df1","df4"];   % fallback: original hard-coded groups
end
specGroups = string(specGroups);
nG   = numel(specGroups);
nMic = length(microphones);

specData = cell(nMic,nG);
oaspl    = zeros(nMic,nG);

% make microphone attributes cell
micAttrsCell = cell(nMic,length(micsAttrsName));

for j = 1:nMic
    micMask = strcmp({thisGroup.Groups.Name},thisGroup.Name+"/"+microphones(j));
    thisMic = thisGroup.Groups(micMask);

    % make microphone attributes cell
    for k = 1:length(thisMic.Attributes)
        micAttrsCell{j,k} = readAttrsByName(thisMic,micsAttrsName(k));
    end

    % read each requested spectrum subgroup
    for g = 1:nG
        [specData{j,g},oaspl(j,g)] = readSpectrumGroup(fileName,thisMic,specGroups(g));
    end
end

micAttrsTable = cell2table(micAttrsCell,VariableNames=micsAttrsName);

% assemble output: per group, a <group> data column and a <group>_OASPL column
noiseTable = table();
for g = 1:nG
    noiseTable.(char(specGroups(g)))          = specData(:,g);
    noiseTable.(char(specGroups(g)+"_OASPL")) = oaspl(:,g);
end

noiseTable = [micAttrsTable,noiseTable];

end
