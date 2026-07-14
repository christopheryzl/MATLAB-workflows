function [encoderTable] = readEncoderData(fileName,thisGroup)
% read angular encoder data (front and rear motor angles) for one case group

% create mask for front motor
motorMask = contains({thisGroup.Groups.Name},"front");
front = thisGroup.Groups(motorMask);
try
    front_enc = readGroupByName(fileName,front,"angle");
catch
    front_enc = [];
    warning("Front encoder data not found")
end
% create mask for rear motor
motorMask = contains({thisGroup.Groups.Name},"rear");
rear = thisGroup.Groups(motorMask);
try
    rear_enc = readGroupByName(fileName,rear,"angle");
catch
    rear_enc = [];
    warning("Rear encoder data not found")
end
encoderTable = table(front_enc,rear_enc,VariableNames=["front","rear"]);

end
