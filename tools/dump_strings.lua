local ST = "/Game/DataTable/ST_StringTable.ST_StringTable"
local stl = StaticFindObject("/Script/Engine.Default__KismetStringTableLibrary")
local ktl = StaticFindObject("/Script/Engine.Default__KismetTextLibrary")
local keys = stl:GetKeysFromStringTable(FName(ST))
local f = io.open("ue4ss/Mods/SpiralCompass/data/ST_StringTable.txt", "w")
local n = 0
for _, k in pairs(keys) do
  local ks = safe(function() return k:get():ToString() end) or safe(function() return k:ToString() end) or tostring(k)
  local t = safe(function() return ktl:TextFromStringTable(FName(ST), ks):ToString() end) or ""
  f:write(ks .. "\t" .. t:gsub("\r", ""):gsub("\n", "\n") .. "\n")
  n = n + 1
end
f:close()
w("strings=" .. n)
-- teste de caminho
local pc = FindFirstOf("GamePlayerController")
local pawn = pc.Pawn
local pl = pawn:K2_GetActorLocation()
local nav = StaticFindObject("/Script/NavigationSystem.Default__NavigationSystemV1")
local path = nav:FindPathToLocationSynchronously(pawn, pl, { X = 1625, Y = 4016, Z = 588 }, nil, nil)
local pp = path.PathPoints
w("PathPoints type=" .. type(pp))
w("len=" .. tostring(safe(function() return #pp end)) .. " num=" .. tostring(safe(function() return pp:GetArrayNum() end)))
safe(function()
  pp:ForEach(function(i, e)
    local v = e:get()
    w("  pt " .. i .. " " .. tostring(safe(function() return v.X end)) .. "," .. tostring(safe(function() return v.Y end)) .. "," .. tostring(safe(function() return v.Z end)))
  end)
end)
w("length=" .. tostring(safe(function() return path:GetPathLength() end)) .. " cost=" .. tostring(safe(function() return path:GetPathCost() end)))
local p2 = nav:FindPathToLocationSynchronously(pawn, pl, { X = 1347, Y = 3200, Z = 1039 }, nil, nil)
w("perto len=" .. tostring(safe(function() return p2:GetPathLength() end)) .. " partial=" .. tostring(safe(function() return p2:IsPartial() end)))
local ok = safe(function() return nav:K2_ProjectPointToNavigation(pawn, { X = 1625, Y = 4016, Z = 588 }, {}, nil, nil, { X = 50, Y = 50, Z = 200 }) end)
w("project=" .. tostring(ok))
