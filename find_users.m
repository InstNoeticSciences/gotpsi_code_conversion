cardData = parquetread('cardD_combined_data.parquet');
users = readtable('PSI_survey_clean.csv');

[cardUsers, iCards] = unique(cardData.user_id);
realUsers = users.Username;

% remove missing values
rmInds = zeros(1, length(cardUsers), 'logical');
for iItem = 1:length(cardUsers)
    if isequaln(cardUsers(iItem), cardUsers(80338))
        rmInds(iItem) = 1;
    end
end
cardUsers(rmInds) = [];
iCards(rmInds) = [];

% write correspondance
[lia, locb] = ismember(cardUsers, realUsers);
num_missing = sum(~lia);
fid = fopen('Mismatch.txt', 'w');
for iItem = 1:length(cardUsers)
    if locb(iItem) ~= 0
        %fprintf(fid, '%d\t%s\t%s\n', iItem, cardUsers{iItem}, realUsers{locb(iItem)});
    else
        fprintf(fid, '%d\t%s\t%s\n', iItem, cardUsers{iItem}, char(cardData.timestamp(iCards(iItem))));
    end
end
fclose(fid);

fprintf('%d users in card data\n', length(cardUsers))
fprintf('%d users in user data\n', length(realUsers))
fprintf('Card users not in real Users -> %d\n', num_missing)
