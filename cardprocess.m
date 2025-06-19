%% process_cardD_data.m
% Description:
%   Imports, validates, and processes raw cardD .dat files from the gotpsi dataset.
%   Applies date-based sorting, file size smoothing, and merges all valid entries
%   into a combined dataset written to a Parquet file.
%
% Inputs:
%   - Files from '/System/Volumes/Data/data/IONS/gotpsi_old_data/raw data zipped/cardD'
%
% Outputs:
%   - 'cardD_combined_data.parquet': combined dataset of valid trials
%   - 'cardD_import_errors.log': log of any file-level import errors
%
% Dependencies:
%   - processCardDFile.m (must be in MATLAB path)
%
% Author: Arnaud Delorme
% Date: May 2025

clear

plotFlag = false;
folderPath = '/System/Volumes/Data/data/IONS/gotpsi_old_data/raw_data_zipped/card_release/card_data';
files = dir(fullfile(folderPath,'*.dat'));
fileNames = fullfile({files.folder},{files.name});
fileSizes = [files.bytes];

% extract dates from filenames
nFiles = numel(fileNames);
allDates = NaT(nFiles,1);
for i = 1:nFiles
    [~, name, ~] = fileparts(fileNames{i});
    year  = name(5:6);
    month = name(7:8);
    day   = name(9:10);
    allDates(i) = datetime(['20' year month day],'InputFormat','yyyyMMdd');
end

% optional histogram
if plotFlag
    histogram(allDates,1000);
    xlabel('Date'); ylabel('Count');
    return
end

% sort by date
[sortedDates, idx]   = sort(allDates);
sortedFileSizes      = fileSizes(idx);
sortedFileNames      = fileNames(idx);

% moving‐average of file sizes
window = 10;
fileSizesSmoothed = movmean(sortedFileSizes,window);
if plotFlag
    plot(sortedDates(window:end), fileSizesSmoothed);
    xlabel('Date'); ylabel('Smoothed file size');
end

% initialize log
logFile = 'cardD_import_errors.log';
fid = fopen(logFile,'w');
fprintf(fid,'Import Errors Log\n%s\nStarted at: %s\n\n', ...
    repmat('=',1,50), datestr(now,'yyyy-mm-dd HH:MM:SS'));
fclose(fid);

% define expected columns and types
colDefs.user_id               = struct('type','string',   'required',true);
colDefs.condition_code        = struct('type','int',      'required',true, 'min',0);
colDefs.reserved_flag         = struct('type','int',      'required',true, 'min',0, 'max',0);
colDefs.trials_per_run        = struct('type','int',      'required',true, 'min',1);
colDefs.click_x               = struct('type','int',      'required',true, 'min',0, 'max',130);
colDefs.click_y               = struct('type','int',      'required',true, 'min',0, 'max',157);
colDefs.bias_level            = struct('type','int',      'required',true, 'min',1, 'max',20);
colDefs.original_target_id    = struct('type','int',      'required',true, 'min',1, 'max',5);
colDefs.displayed_target_id   = struct('type','int',      'required',true, 'min',1, 'max',5);
colDefs.response_choice       = struct('type','int',      'required',true, 'min',1, 'max',5);
colDefs.cumulative_hits       = struct('type','int',      'required',true, 'min',0);
colDefs.trial_number          = struct('type','int',      'required',true, 'min',1);
colDefs.timestamp             = struct('type','datetime', 'required',true);
colDefs.displayed_image_path  = struct('type','string',   'required',true);

columns    = fieldnames(colDefs);
oldColumns = [columns(1:8); columns(10:end)];  % skip markov_bits1

% start parallel pool
if 0
    pool = gcp('nocreate');
    if isempty(pool)
        parpool(max(feature('numcores')-1,1));
    end
end

% process each file in parallel
results = cell(nFiles,1);
for iFile = 1987:nFiles
    results{iFile} = processCardFile(sortedFileNames{iFile}, colDefs, columns, logFile);
end

delete(gcp('nocreate'));

% combine all valid tables
tables = results(~cellfun('isempty',results));
allData = vertcat(tables{:});

% save outputs
parquetwrite('cardD_combined_data.parquet', allData);

% final log summary
fid = fopen(logFile,'a');
fprintf(fid,'\n%s\nImport completed at: %s\nTotal files: %d\nImported: %d\nFailed: %d\nTotal rows: %d\n', ...
    repmat('=',1,50), datestr(now,'yyyy-mm-dd HH:MM:SS'), nFiles, numel(tables), nFiles-numel(tables), height(allData));
fclose(fid);

fprintf('Import complete. See %s for details.\n', logFile);
fprintf('Total trials: %d\nTotal hits: %d\nAverage hit rate: %.2f%%\nUnique users: %d\n', ...
    height(allData), sum(allData.is_hit), mean(allData.is_hit)*100, numel(unique(allData.user_id)));



