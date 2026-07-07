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

loadTable = table();

end
