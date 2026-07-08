function [] = makeResults(result,vsep,tilt,inflow)
RPM = 9000;
dF = 1;
dataSize = length(vsep);


filteredResults = result(result.tilt==tilt,:);
filteredResults = filteredResults(filteredResults.inflow==inflow,:);
filteredResults = filteredResults(any(filteredResults.vsep==vsep,2),:);
filteredResults = sortrows(filteredResults,["inflow","vsep"]);
micLoc = [300,90];
%micarrays = {1:19,20:32,33:45,46:58};
exportName = num2str(tilt)+"deg_"+num2str(inflow)+"ms_9000rpm_p"+num2str(micLoc(1))+"_t"+num2str(micLoc(2));

%%
X=cell(size(micLoc,1),1);
Y = X;

for i = 1:length(X)

    for j = 1:dataSize
        thisResult = filteredResults(j,:);
        thisMic = thisResult.data{1};
        thisMic = thisMic(thisMic.phi==micLoc(i,1),:);
        thisMic = thisMic(thisMic.theta==micLoc(i,2),:);
        F(j,:) = thisMic.dF4{1}.F;
        SPL(j,:) = thisMic.dF4{1}.SPL;
        if micLoc(1) ~= 0
            if any(micLoc(2) == 45:5:65)
                SPL(j,:) = correctWindscreenSPL(F(j,:),SPL(j,:),"40PL");
            else
                SPL(j,:) = correctWindscreenSPL(F(j,:),SPL(j,:),"46BE");
            end
        end
    end
    X{i} = F;
    Y{i} = SPL;
end
save(exportName,"X","Y");
end