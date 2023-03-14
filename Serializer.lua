local HttpService = game:GetService('HttpService');

local PASTE_API_KEY = 'API key for paste.ee goes here';

local function hasExtraDecimals(num)
    local str = tostring(num)
    local _, decimalPos = string.find(str, '%.');
    if decimalPos then
        local decimals = string.sub(str, decimalPos + 1);
        return #decimals > 3;
    end;
    return false;
end;

local function truncateNumber(number)
    return hasExtraDecimals(number) and tonumber(string.format('%.3f', number)) or number;
end;

local function truncateTableNumbers(tbl)
    if typeof(tbl) ~= 'table' then return tbl; end;

    local res = table.create(#tbl);

    for i, v in next, tbl do
        res[i] = truncateNumber(v);
    end;

    return res;
end;

local function vector3ToTableOrNumber(vec)
    local x = vec.X;
    local y = vec.Y;
    local z = vec.Z;

    if (x == y) and (y == z) and (z == x) then
        return x;
    end;

    return {x, y, z};
end;

local res = {variables = {}, data = {}};

for i, v in next, workspace:GetDescendants() do
	if v:IsA('BasePart') then
        if v.Transparency == 1 then continue; end; -- Invisible objects wouldn't be shown in the renderer and there's no support for decals, so no reason to include them.

		table.insert(res.data, {
			s = truncateTableNumbers(vector3ToTableOrNumber(v.Size)),
			p = truncateTableNumbers(vector3ToTableOrNumber(v.Position)),
			o = (v.Orientation.Magnitude ~= 0) and truncateTableNumbers(vector3ToTableOrNumber(v.Orientation)) or (nil),
			c = v.Color:ToHex(),
            t = (v.Transparency ~= 0) and truncateNumber(v.Transparency) or (nil),
		});
	end;
end;

do -- Color optimization with variables.
    local colorUses = {};

    for i, v in next, res.data do -- Record the number of times colors are used.
        if not colorUses[v.c] then colorUses[v.c] = 0; end;
        colorUses[v.c] += 1;
    end;

    for i, v in next, res.data do
        if colorUses[v.c] > 5 then
            local index = table.find(res.variables, v.c);
            if not index then
                table.insert(res.variables, v.c);
                index = #res.variables;
            end;
            v.c = `!{index - 1}`; -- Doing -1 because of arrays in JS.
        end;
    end;
end;

local payloadJson = HttpService:JSONEncode(res);

local function upload(content)
    local res = {}; -- Table of urls.

    local suc, pasteRes = pcall(function()
        return HttpService:PostAsync('https://api.paste.ee/v1/pastes', HttpService:JSONEncode({description = '', sections = {{name = 'Section1', syntax = 'autodetect', contents = content}}}), Enum.HttpContentType.ApplicationJson, nil, {['X-Auth-Token'] = PASTE_API_KEY});
    end);
    if suc then
        local pasteData = HttpService:JSONDecode(pasteRes);
        table.insert(res, 'https://paste.ee/r/' .. pasteData.id);
    elseif pasteRes:find('Post data too large') then
        local length = #content;
        local half1 = content:sub(1, length / 2);
        local half2 = content:sub((length / 2) + 1, length);
        table.insert(res, table.concat(upload(half1), ' '));
        table.insert(res, table.concat(upload(half2), ' '));
    else
        error(pasteRes);
    end;

    return res;
end;

local urls = upload(payloadJson);
print(table.concat(urls, ' '));