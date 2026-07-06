function [Results] = readFromList(fileName,selectedGroups,varargin)
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

Output = cell(length(selectedGroups),9);

for i = 1:length(selectedGroups)
    name = selectedGroups(i);
    Output{i,1} = h5readatt(fileName,name,"advance ratio");
    Output{i,2} = h5readatt(fileName,name,'separation');
    Output{i,3} = h5readatt(fileName,name,'blade number');
    Output{i,4} = h5readatt(fileName,name,'inflow');
    Output{i,5} = h5readatt(fileName,name,'rotational speed');
    Output{i,6} = h5readatt(fileName,name,"phase");
   
    BPF = Output{i,3}*Output{i,5}/60;
    phi = zeros(length(microphones),1);
    theta = phi;
    r = phi;
    Fs = phi;
    OASPL1 = phi;
    OASPL4 = phi;
    
    data1 = cell(length(microphones),1);
    data4 = data1;
    harmonic_data1 = data1;

    for j = 1:length(microphones)
        groupName = name+"/"+microphones(j);
        SPL1 = h5read(fileName,groupName+"/1dF/SPL");

        F1 = h5read(fileName,groupName+"/1dF/F");
        
        SPL4 = h5read(fileName,groupName+"/4dF/SPL");

        F4 = h5read(fileName,groupName+"/4dF/F");
        OASPL1(j) = h5read(fileName,groupName+"/1dF/OASPL");
        OASPL4(j) = h5read(fileName,groupName+"/4dF/OASPL");

        phi(j) = h5readatt(fileName,name+"/"+microphones(j),"phi (deg)");
        theta(j) = h5readatt(fileName,name+"/"+microphones(j),"theta (deg)");
        r(j) = h5readatt(fileName,name+"/"+microphones(j),"r (m)");
        Fs(j) = 65536;%h5readatt(fileName,name+"/"+microphones(j),"sampling frequency");
        data1{j} = table(F1,SPL1,VariableNames=["F","SPL"]);
        data4{j} = table(F4,SPL4,VariableNames=["F","SPL"]);

        [BPHSPL,~,~] = findFirst5BPH(F1,SPL1,BPF,1);
        harmonic_data1{j} = table([1:5]',BPHSPL',VariableNames=["harmonic","SPL"]);
    end
    

    data = table(phi,theta,r,Fs,OASPL1,OASPL4,data1,data4,harmonic_data1,VariableNames=["phi","theta","r","Fs","OASPL1","OASPL4","dF1","dF4","Harmonics"]);
    Output{i,7} = data;
    %read encoder data from Forrest's dataset
    inboard_enc = h5read(fileName,name+"/inboard/Phase");
    outboard_enc = h5read(fileName,name+"/outboard/Phase");

    data_enc = table(inboard_enc,outboard_enc,VariableNames=["inboard","outboard"]);
    Output{i,8} = data_enc;

    %read load cell data from Forrest's dataset
    inboard_LC = h5read(fileName,name+"/inboard/Fz");
    outboard_LC = h5read(fileName,name+"/outboard/Fz");
    inboard_LC = mean(inboard_LC);
    outboard_LC = mean(outboard_LC);
    
    data_LC = table(inboard_LC,outboard_LC,VariableNames=["inboard","outboard"]);
    Output{i,9} = data_LC;
end
Results = cell2table(Output,VariableNames=["J","Sep","B_No","inflow","rpm","phase","noise data","encoder data","load cell data"]);

end

