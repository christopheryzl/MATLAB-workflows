function [Results] = readFromList(fileName,groups,varargin)
% read results stored as a .mat from selected Groups from the h5 dataset

% optional arguments:
%Mics: scalar or numeric array, specifies the mic to read from the name
%(Mics are named as Mic1, Mic2, etc in the h5 file, so you first need to
%know the group structure.
varargs = reshape(varargin,2,[]);
p = struct(varargs{:});


if isfield(p,'Mics')
    MicList = p.Mics;
else
    % this part is hard-coded, could be changed so that the mic list is read from the h5 group directly 
    MicList = 1:58;
end
microphones = "mic"+strtrim(string(num2str([MicList]')));

%% initialise output cells
% make case attribute variable names
attrsName = string({groups(1).Attributes.Name});
% make case attribute cell
attrsCell = cell(length(groups),length(attrsName));

noiseData = cell(length(groups),1);
data_enc = noiseData;

% make microphone variable names
micFirstGroup =find(strcmp({groups(1).Groups.Name},groups(1).Name+"/"+microphones(1)));
micsAttrsName = string({groups(1).Groups(micFirstGroup).Attributes.Name});

% iterate over all groups
for i = 1:length(groups)
    thisGroup = groups(i);
    % make attribute cells
    for j = 1:length(thisGroup.Attributes)
        attrsCell{i,j} = readAttrsByName(thisGroup,attrsName(j));
    end
    
    data1 = cell(length(microphones),1);
    data4 = data1;
    
    % make microphone attributes cell
    micAttrsCell = cell(length(microphones),length(micsAttrsName));

    for j = 1:length(microphones)
        micMask =strcmp({thisGroup.Groups.Name},thisGroup.Name+"/"+microphones(j));
        thisMic = thisGroup.Groups(micMask);

        % make microphone attributes cell
        for k = 1:length(thisMic.Attributes)
            micAttrsCell{j,k} = readAttrsByName(thisMic,micsAttrsName(k));
        end
        % create name mask for df1 group
        nameMask = contains({thisMic.Groups.Name},"df1",IgnoreCase=true);
        df1 = thisMic.Groups(nameMask);
        
        SPL1        = readGroupByName(df1,"spl");
        F1          = readGroupByName(df1,"f");
        PSD1        = readGroupByName(df1,"psd");
        OASPL1(j)   = readGroupByName(df1,"oaspl");
        
        data1{j} = table(F1,PSD1,SPL1,VariableNames=["f","psd","spl"]);
        
        % create name mask for df4 group
        nameMask = contains({thisMic.Groups.Name},"df4",IgnoreCase=true);
        df4 = thisMic.Groups(nameMask);
        SPL4        = readGroupByName(df4,"spl");
        F4          = readGroupByName(df4,"f");
        PSD4        = readGroupByName(df4,"psd");
        OASPL4(j)   = readGroupByName(df4,"oaspl");

        data4{j} = table(F4,PSD4,SPL4,VariableNames=["f","psd","spl"]);
    end
    

    noiseData{i} = table(OASPL1',OASPL4',data1,data4,VariableNames=["OASPL1","OASPL4","dF1","dF4"]);
    %read encoder data

    % create mask for front motor
    motorMask = contains({thisGroup.Groups.Name},"front");
    front = thisGroup.Groups(motorMask);
    front_enc = readGroupByName(front,"angle");

    % create mask for rear motor
    motorMask = contains({thisGroup.Groups.Name},"rear");
    rear = thisGroup.Groups(motorMask);
    rear_enc = readGroupByName(rear,"angle");

    data_enc{i} = table(front_enc,rear_enc,VariableNames=["front","rear"]);


end
attrsTable = cell2table(attrsCell,VariableNames=attrsName);
micAttrsTable = cell2table(micAttrsCell,VariableNames=micsAttrsName);
for i = 1:length(noiseData)
    noiseData{i} = [micAttrsTable,noiseData{i}];
end
micTable = cell2table(noiseData,VariableNames="noise data");
encoderDataTable = cell2table(data_enc,VariableNames="encoder data");

data_table = [micTable,encoderDataTable];
Results = [attrsTable,data_table];


    function [out] = readGroupByName(group,datasetName)
        mask = strcmp({group.Datasets.Name},datasetName);
        out = h5read(fileName,group.Name+"/"+group.Datasets(mask).Name);

    end

    function [out] = readAttrsByName(group,attrsName)
        mask = strcmp({group.Attributes.Name},attrsName);
        out = group.Attributes(mask).Value;
    end
end


