function [out] = readAttrsByName(group,attrsName)
% read a single attribute value by name from an h5 group
    mask = strcmp({group.Attributes.Name},attrsName);
    out = group.Attributes(mask).Value;
end
