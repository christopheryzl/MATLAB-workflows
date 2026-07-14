function [metaTable] = readMetadata(fileName,thisGroup)
% read metadata for each motor of the current group
motorMask = contains({thisGroup.Groups.Name},"front");
front = thisGroup.Groups(motorMask);
try
    front_dRPM = readGroupByName(fileName,front,"delta RPM");
catch
    front_dRPM = [];
    warning("Front delta RPM data not found")
end

try
    front_dPhase = readGroupByName(fileName,front,"delta phase");
catch
    front_dPhase = [];
    warning("Front delta phase data not found")
end

% create mask for rear motor
motorMask = contains({thisGroup.Groups.Name},"rear");
rear = thisGroup.Groups(motorMask);
try
    rear_dRPM = readGroupByName(fileName,rear,"delta RPM");
catch
    rear_dRPM = [];
    warning("Rear delta RPM data not found")
end

try
    rear_dPhase = readGroupByName(fileName,rear,"delta phase");
catch
    rear_dPhase = [];
    warning("Rear delta phase data not found")
end

metaTable = table(front_dRPM,front_dPhase,rear_dRPM,rear_dPhase,VariableNames=["front d_rpm","front d_phase","rear d_rpm","rear d_phase"]);


end