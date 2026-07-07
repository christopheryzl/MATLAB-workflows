function [out] = readGroupByName(fileName,group,datasetName)
% read a single dataset by name from an h5 group
    mask = strcmp({group.Datasets.Name},datasetName);
    out = h5read(fileName,group.Name+"/"+group.Datasets(mask).Name);
end
