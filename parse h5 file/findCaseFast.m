function [foundGroups] = findCaseFast(fileName,J,Sep,B_No,Inflow,RPM,phase)

fid = H5F.open(fileName);
if isnumeric(phase)
    rootGroup = "/";
else
    H5F.close(fid);
    disp("invalid group");
    return
end

try
    gid = H5G.open(fid,rootGroup);
catch
    H5F.close(fid)
    disp("Cannot find group, check file name")
    return
end

num_groups = H5G.get_num_objs(gid);
selectedNames = strings(1,num_groups);
for i = 0:num_groups-1
    groupName = H5G.get_objname_by_idx(gid,i);
    caseid = H5G.open(gid,groupName);
    attLength = H5A.get_num_attrs(caseid);
    H5G.close(caseid)
    for j = 0:attLength-1
        attid = H5A.open_by_idx(gid,groupName,"H5_INDEX_NAME","H5_ITER_INC",j);
        tf = checkCondition(attid,J,Sep,B_No,Inflow,RPM,phase);
        H5A.close(attid)
        if tf == false
            break
        end
    end
    if tf == true
        selectedNames(i+1) = groupName;
    end
end

H5G.close(gid)
H5F.close(fid)

foundGroups = rootGroup+selectedNames(selectedNames~="");

    function [tf] = checkCondition(attid,J,Sep,B_No,Inflow,RPM,phase)
        attName = H5A.get_name(attid);
        switch attName
            case "advance ratio"
                tf = checkTF(attid,J);
            case "separation"
                tf = checkTF(attid,Sep);
            case "blade number"
                tf = checkTF(attid,B_No);
            case "inflow"
                tf = checkTF(attid,Inflow);
            case "rotational speed"
                tf = checkTF(attid,RPM);
            case "phase"
                tf = checkTF(attid,phase);
            otherwise
                tf = true;
        end

        function [tf] = checkTF(attid,property)
            if ~isempty(property)
                tf = any(H5A.read(attid) == property);
            else
                tf = true;
            end
        end
    end

end

