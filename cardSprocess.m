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
folderPath = '/System/Volumes/Data/data/IONS/gotpsi_old_data/raw_data_zipped/cardS_release/cardS_data';
files = dir(fullfile(folderPath,'*.dat'));
fileNames = fullfile({files.folder},{files.name});
fileSizes = [files.bytes];

% extract dates from filenames
nFiles = numel(fileNames);
allDates = NaT(nFiles,1);
for i = 1:nFiles
    [~, name, ~] = fileparts(fileNames{i});
    year  = name(6:7);
    month = name(8:9);
    day   = name(10:11);
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
logFile = '../cardS_release/cardD_import_errors.log';
fid = fopen(logFile,'w');
fprintf(fid,'Import Errors Log\n%s\nStarted at: %s\n\n', ...
    repmat('=',1,50), datestr(now,'yyyy-mm-dd HH:MM:SS'));
fclose(fid);

% define expected columns and types (USE cardS2.pl)
% print LOG "$userid, $trial, $steps, $rarray, $im[$tarim], $timeval\n";
% print LOG "$userid, $trial, $response, $timeval\n";	# log the step
colDefs.user_id       = struct('type','string',  'required',true);
colDefs.trial         = struct('type','int',     'required',true);
colDefs.step          = struct('type','int',     'required',true);
colDefs.timestamp     = struct('type','datetime','required',true);
colDefs.guess1        = struct('type','int',     'required',true,'min',0,'max',5);
colDefs.guess2        = struct('type','int',     'required',true,'min',0,'max',5);
colDefs.guess3        = struct('type','int',     'required',true,'min',0,'max',5);
colDefs.guess4        = struct('type','int',     'required',true,'min',0,'max',5);
colDefs.guess5        = struct('type','int',     'required',true,'min',0,'max',5);
colDefs.target_image  = struct('type','string',  'required',true);
colDefs.timestamp2    = struct('type','datetime','required',true);
%colDefs.extra         = struct('type','string',  'required',false);

columns    = fieldnames(colDefs);

% start parallel pool
if true
    pool = gcp('nocreate');
    if isempty(pool)
        parpool(max(feature('numcores')-1,1));
    end
end

% process each file in parallel
results = cell(nFiles,1);
parfor iFile = 1:nFiles
    results{iFile} = processCardSFile(sortedFileNames{iFile}, colDefs, columns, logFile);
end

delete(gcp('nocreate'));

% combine all valid tables
tables = results(~cellfun('isempty',results));
allData = vertcat(tables{:});

% save outputs
parquetwrite('../cardS_release/cardD_combined_data.parquet', allData);

% final log summary
res = sprintf('\n%s\nImport completed at: %s\nTotal files: %d\nImported: %d\nFailed: %d\nTotal rows: %d\nTotal users: %d\n', ...
    repmat('=',1,50), datestr(now,'yyyy-mm-dd HH:MM:SS'), nFiles, numel(tables), nFiles-numel(tables), height(allData), numel(unique(allData.user_id)));
fid = fopen(logFile,'a');
fprintf(fid,'%s', res);
fprintf('%s', res);
fclose(fid);

fprintf('\nImport complete. See %s for details.\n', logFile);



