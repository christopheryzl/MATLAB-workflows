function [encoderTable] = readEncoderData(fileName,thisGroup)
% read angular encoder data (front and rear motor angles) for one case group

% create mask for front motor
motorMask = contains({thisGroup.Groups.Name},"front");
front = thisGroup.Groups(motorMask);
front_enc = readGroupByName(fileName,front,"angle");

% create mask for rear motor
motorMask = contains({thisGroup.Groups.Name},"rear");
rear = thisGroup.Groups(motorMask);
rear_enc = readGroupByName(fileName,rear,"angle");

encoderTable = table(front_enc,rear_enc,VariableNames=["front","rear"]);

end
