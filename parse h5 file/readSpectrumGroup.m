function [specTable,oaspl] = readSpectrumGroup(fileName,thisMic,groupName)
% read one spectrum subgroup (e.g. "df1", "df4") for a single microphone.
% Returns a table with f/psd/spl columns and the scalar OASPL.

nameMask = contains({thisMic.Groups.Name},groupName,IgnoreCase=true);
grp = thisMic.Groups(nameMask);

SPL   = readGroupByName(fileName,grp,"spl");
F     = readGroupByName(fileName,grp,"f");
PSD   = readGroupByName(fileName,grp,"psd");
oaspl = readGroupByName(fileName,grp,"oaspl");

specTable = table(F,PSD,SPL,VariableNames=["f","psd","spl"]);

end
