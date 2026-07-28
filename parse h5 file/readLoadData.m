function [loadTable] = readLoadData(fileName,thisGroup)
% read load data (e.g. load cell / thrust / torque) for one case group.
%
% STUB: not yet implemented. Returns an empty table so callers stay stable.
% TODO: fill in the h5 group/dataset names once known, following the same
% pattern as readEncoderData, e.g.:
%
%   loadMask  = contains({thisGroup.Groups.Name},"load");
%   loadGroup = thisGroup.Groups(loadMask);
%   thrust    = readGroupByName(fileName,loadGroup,"thrust");
%   torque    = readGroupByName(fileName,loadGroup,"torque");
%   loadTable = table(thrust,torque,VariableNames=["thrust","torque"]);

loadMask  = contains({thisGroup.Groups.Name},["rotor","inboard","outboard"]);
loadGroups = thisGroup.Groups(loadMask);

for i = 1:length(loadGroups)
    % get the load group name, used in table variable
    name_split = split(loadGroups(i).Name,'/');
    groupName(i) = string(name_split{end});
    Thrust(i) = readGroupByName(fileName,loadGroups(i),"Fz");
    Torque(i) = readGroupByName(fileName,loadGroups(i),"Tz");
end
loadTable = table(groupName',Thrust',Torque',VariableNames=["name","thrust","torque"]);

end
