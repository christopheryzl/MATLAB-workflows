function [Results] = readRawFromList(fileName,selectedGroups,varargin)
% old implementation reading from h5 file storing acoustic pressure, new
% version required

varargs = reshape(varargin,2,[]);
p = struct(varargs{:});

if isfield(p,'Mics')
    MicList = p.Mics;
else
    MicList = 1:58;
end

microphones = "mic"+strtrim(string(num2str([MicList]')));

Output = cell(length(selectedGroups),7);

for i = 1:length(selectedGroups)
    name = selectedGroups(i);
    Output{i,1} = h5readatt(fileName,name,"H. separation");
    Output{i,2} = h5readatt(fileName,name,'V. separation');
    Output{i,3} = h5readatt(fileName,name,'Tilt');
    Output{i,4} = h5readatt(fileName,name,'Inflow');
    Output{i,5} = h5readatt(fileName,name,'RPM');
    Output{i,6} = h5readatt(fileName,name,"phase");
   
    
    phi = zeros(length(microphones),1);
    theta = phi;
    r = phi;
    FsP = phi;
    FsE = phi;
    OASPL1 = phi;
    OASPL4 = phi;
    
    dataP = cell(length(microphones),1);
    dataE = dataP;

    for j = 1:length(microphones)
        groupName = name+"/"+microphones(j);
        Pressure = h5read(fileName,groupName+"/acousticPressure");
        FrontEncoder = h5read(fileName,name+"/front_motor/encoder/biased_angle");
        RearEncoder = h5read(fileName,name+"/rear_motor/encoder/biased_angle");

        phi(j) = h5readatt(fileName,name+"/"+microphones(j),"phi (deg)");
        theta(j) = h5readatt(fileName,name+"/"+microphones(j),"theta (deg)");
        r(j) = h5readatt(fileName,name+"/"+microphones(j),"r (m)");
        FsP(j) = h5readatt(fileName,name+"/"+microphones(j),"sampling frequency");
        dataP{j} = table(Pressure,VariableNames=["Pressure"]);
        dataE{j} = table(FrontEncoder,RearEncoder,VariableNames=["FrontEncoder","RearEncoder"]);
    end
    
    data = table(phi,theta,r,FsP,FsE,dataP,dataE,VariableNames=["phi","theta","r","MicFs","EncoderFs","AcousticData","AngularData"]);
    Output{i,7} = data;
end
Results = cell2table(Output,VariableNames=["hsep","vsep","tilt","inflow","rpm","phase","data"]);

end

