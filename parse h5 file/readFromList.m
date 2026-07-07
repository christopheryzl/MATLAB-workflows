function [Results] = readFromList(fileName,groups,varargin)
% read results stored as a .mat from selected Groups from the h5 dataset
%
% Noise, load and angular encoder data are read per group by the helper
% functions readNoiseData, readLoadData and readEncoderData respectively.

% optional arguments:
%Mics: scalar or numeric array, specifies the mic to read from the name
%(Mics are named as Mic1, Mic2, etc in the h5 file, so you first need to
%know the group structure.
varargs = reshape(varargin,2,[]);
p = struct(varargs{:});


% auto-detect the available microphone channels from the first group's
% subgroups. Handles both "mic#" and "Mic#" naming, and assumes the mic
% set is constant across every group within one h5 file.
subNames  = string({groups(1).Groups.Name});
leafNames = extractAfter(subNames,groups(1).Name+"/");                 % strip parent path
micMask   = ~cellfun(@isempty,regexp(leafNames,"^[Mm]ic\d+$","once")); % keep mic#/Mic# only
availableMics = leafNames(micMask);
% order by numeric index (mic1, mic2, ...)
availableNums = str2double(erase(lower(availableMics),"mic"));
[availableNums,order] = sort(availableNums);
availableMics = availableMics(order);

if isfield(p,'Mics')
    MicList = p.Mics(:)';
    % validate that every requested mic exists in the file
    missing = setdiff(MicList,availableNums);
    if ~isempty(missing)
        error("readFromList:micNotAvailable", ...
            "Requested microphone(s) not available in file: %s. Available: %s", ...
            mat2str(missing),mat2str(availableNums));
    end
    % map requested indices to the actual (case-preserved) mic names
    [~,idx] = ismember(MicList,availableNums);
    microphones = availableMics(idx);
else
    microphones = availableMics;
end

% ---- original hard-coded mic handling (kept for reference) ----
% if isfield(p,'Mics')
%     MicList = p.Mics;
% else
%     % this part is hard-coded, could be changed so that the mic list is read from the h5 group directly
%     MicList = 1:58;
% end
% microphones = "mic"+strtrim(string(num2str([MicList]')));

%% initialise output cells
% make case attribute variable names
attrsName = string({groups(1).Attributes.Name});
% make case attribute cell
attrsCell = cell(length(groups),length(attrsName));

noiseData = cell(length(groups),1);
loadData  = noiseData;
data_enc  = noiseData;

% spectrum subgroups to read from each microphone (user input or fallback)
if isfield(p,'SpecGroups')
    specGroups = string(p.SpecGroups);
else
    specGroups = ["df1","df4"];   % fallback: original hard-coded groups
end

% make microphone variable names
micFirstGroup = find(strcmp({groups(1).Groups.Name},groups(1).Name+"/"+microphones(1)));
micsAttrsName = string({groups(1).Groups(micFirstGroup).Attributes.Name});

% iterate over all groups
for i = 1:length(groups)
    thisGroup = groups(i);

    % make attribute cells
    for j = 1:length(thisGroup.Attributes)
        attrsCell{i,j} = readAttrsByName(thisGroup,attrsName(j));
    end

    % read noise, load and angular encoder data for this group
    noiseData{i} = readNoiseData(fileName,thisGroup,microphones,micsAttrsName,specGroups);
    loadData{i}  = readLoadData(fileName,thisGroup);
    data_enc{i}  = readEncoderData(fileName,thisGroup);
end

attrsTable       = cell2table(attrsCell,VariableNames=attrsName);
micTable         = cell2table(noiseData,VariableNames="noise data");
loadDataTable    = cell2table(loadData,VariableNames="load data");
encoderDataTable = cell2table(data_enc,VariableNames="encoder data");

Results = [attrsTable,micTable,loadDataTable,encoderDataTable];

end
