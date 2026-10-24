-- Extrai todas as DataTables /Game/DataTable/* e a StringTable (pt-BR) para ue4ss/Mods/SpiralCompass/data/
-- Executado pelo mecanismo probe.lua do Spiral Compass (funcoes w/safe/valid/str vem do ambiente).
local OUTDIR = "ue4ss/Mods/SpiralCompass/data/"

local function scalar(v)
    local t = type(v)
    if t == "number" or t == "boolean" or t == "string" then return tostring(v) end
    if t == "userdata" then
        local s = safe(function() return v:ToString() end)
        if s then return s end
        local okArr = safe(function() return v:GetArrayNum() end)
        if okArr then
            local parts = {}
            safe(function()
                v:ForEach(function(_, e)
                    local ev = e:get()
                    parts[#parts + 1] = scalar(ev)
                end)
            end)
            return "[" .. table.concat(parts, ",") .. "]"
        end
        local full = safe(function() return v:GetFullName() end)
        if full then return "<" .. full .. ">" end
        return "<struct>"
    end
    return "nil"
end

local function dumpRow(rowStruct, row)
    local parts = {}
    local st = rowStruct
    while st and valid(st) do
        safe(function()
            st:ForEachProperty(function(p)
                local pn = p:GetFName():ToString()
                local v = safe(function() return row[pn] end)
                parts[#parts + 1] = pn .. "=" .. scalar(v)
            end)
        end)
        st = safe(function() return st:GetSuperStruct() end)
    end
    return table.concat(parts, " | ")
end

local count = 0
for _, dt in ipairs(FindAllOf("DataTable") or {}) do
    local full = safe(function() return dt:GetFullName() end) or ""
    local name = full:match("/Game/DataTable/([%w_]+)%.")
    if name then
        local rs = safe(function() return dt.RowStruct end)
        local lines = {}
        safe(function()
            dt:ForEachRow(function(rowName, row)
                lines[#lines + 1] = tostring(scalar(rowName)) .. " :: " .. dumpRow(rs, row)
            end)
        end)
        local f = io.open(OUTDIR .. name .. ".txt", "w")
        if f then
            f:write(table.concat(lines, "\n"))
            f:close()
        end
        w(name .. " rows=" .. #lines)
        count = count + 1
    end
end

-- StringTable completa
local ST = "/Game/DataTable/ST_StringTable.ST_StringTable"
local stl = StaticFindObject("/Script/Engine.Default__KismetStringTableLibrary")
local ktl = StaticFindObject("/Script/Engine.Default__KismetTextLibrary")
local keys = safe(function() return stl:GetKeysFromStringTable(FName(ST)) end)
local klist = {}
if type(keys) == "table" then
    for _, k in pairs(keys) do klist[#klist + 1] = str(k) or tostring(k) end
elseif keys then
    safe(function() keys:ForEach(function(_, e) klist[#klist + 1] = str(e:get()) end) end)
end
w("string keys=" .. #klist .. " type=" .. type(keys))
local f = io.open(OUTDIR .. "ST_StringTable.txt", "w")
if f then
    for _, k in ipairs(klist) do
        local t = safe(function() return ktl:TextFromStringTable(FName(ST), k):ToString() end) or ""
        f:write(k .. "\t" .. t:gsub("\r", ""):gsub("\n", "\\n") .. "\n")
    end
    f:close()
end
w("tables=" .. count)
