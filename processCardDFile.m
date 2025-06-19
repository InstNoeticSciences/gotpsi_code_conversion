function T = processCardDFile(fileName, colDefs, columns, oldColumns, logFile)
    
    T = readtable(fileName, 'Delimiter',',','ReadVariableNames',false);
    nVar = width(T);
    
    if isempty(T)
        return
    end

    % detect format
    if any(~ismissing(T{:,end})), fileType = 'new'; else fileType = ''; end
    if nVar>=14 && all(contains(string(T{:,14}),'20'))
        T.Properties.VariableNames = columns;
        fileType = 'new';
    elseif nVar>=13 && all(contains(string(T{:,13}),'20'))
        T.Properties.VariableNames = oldColumns;
        T = [T(:,1:8) table(nan(height(T),1), 'VariableNames', {columns{9}}) T(:,9:end)];
        fileType = 'old';
    else
        fid = fopen(logFile,'a');
        fprintf(fid,'Failed to import %s - timestamp column not found\n', fileName);
        fclose(fid);
        T = []; return
    end
    
    % add date from filename
    [~, name, ~] = fileparts(fileName);
    year  = name(6:7); month = name(8:9); day = name(10:11);
    dateVal = datetime(['20' year month day],'InputFormat','yyyyMMdd');
    T.date = repmat(dateVal, height(T),1);
    
    % bulk type conversion & check for anomalies
    needCheck = false;
    vars = T.Properties.VariableNames;
    for k = 1:numel(vars)
        col = vars{k};
        if isfield(colDefs,col)
            def = colDefs.(col);
            switch def.type
                case 'datetime'
                    if any(cellfun(@isempty, T.(col)))
                        error('Some empty values')
                    end
                    T.(col) = datetime(T.(col), 'InputFormat','eee MMM dd HH:mm:ss yyyy', 'Locale','en_US');
                    if any(T.(col) > datetime('now')), needCheck = true; end
                case 'int'
                    T.(col) = round(double(T.(col)));
                    if any(T.(col) < 0), needCheck = true; end
                case 'bool'
                    T.(col) = logical(T.(col));
                case 'string'
                    T.(col) = string(T.(col));
            end
        end
    end
    
    % row‐by‐row validation if needed
    if needCheck
        validIdx = true(height(T),1);
        for r = 1:height(T)
            errs = validateRow(T(r,:),colDefs);
            if ~isempty(errs)
                validIdx(r) = false;
                fid = fopen(logFile,'a');
                fprintf(fid,'Row %d in %s: %s\n', r, fileName, strjoin(errs,', '));
                fclose(fid);
            end
        end
        T = T(validIdx,:);
        validCount   = sum(validIdx);
        invalidCount = sum(~validIdx);
    else
        validCount   = height(T);
        invalidCount = 0;
    end
    
    % log success
    fid = fopen(logFile,'a');
    if invalidCount>0
        fprintf(fid,'Successfully imported %s (%d valid, %d invalid)\n', fileName, validCount, invalidCount);
        fprintf(    'Successfully imported %s (%d valid, %d invalid)\n', fileName, validCount, invalidCount);
    else
        fprintf(fid,'Successfully imported %s\n', fileName);
        fprintf(    'Successfully imported %s\n', fileName);
    end
    fclose(fid);
end


function errs = validateRow(row, colDefs)
    errs = {};
    vars = fieldnames(colDefs);
    for i = 1:numel(vars)
        col = vars{i};
        def = colDefs.(col);
        if def.required && ~ismember(col, row.Properties.VariableNames)
            errs{end+1} = ['Missing required column: ' col]; continue
        end
        val = row.(col);
        switch def.type
            case 'int'
                if ~isnumeric(val)
                    errs{end+1} = ['Invalid int for ' col];
                else
                    if isfield(def,'min') && val < def.min
                        errs{end+1} = [col ' below minimum ' num2str(def.min)];
                    end
                    if isfield(def,'max') && val > def.max
                        errs{end+1} = [col ' above maximum ' num2str(def.max)];
                    end
                end
            case 'bool'
                if ~islogical(val)
                    errs{end+1} = ['Invalid bool for ' col];
                end
            case 'datetime'
                if ~isdatetime(val)
                    errs{end+1} = ['Invalid datetime for ' col];
                end
            case 'string'
                if ~(isstring(val)||ischar(val))
                    errs{end+1} = ['Invalid string for ' col];
                end
        end
    end
end