-- Carrega (como dados, sem entrar) todos os subniveis de capitulos e lista os atores de jogo com suas variaveis.
local PKGS = {
    "/Game/Map/MAP_Chapter_01", "/Game/Map/MAP_Chapter_03", "/Game/Map/MAP_Chapter_04", "/Game/Map/MAP_Chapter_04-2",
    "/Game/Map/Chapter_01/Chapter_01_LocSeq", "/Game/Map/Chapter_01/GameDesign/Ch01_A1_MainMission",
    "/Game/Map/Chapter_01/GameDesign/Ch01_Level_Mob", "/Game/Map/Chapter_01/GameDesign/Ch01_Level_Non_Seq_Dialogue",
    "/Game/Map/Chapter_01/GameDesign/Ch01_Level_SeqLocation",
    "/Game/Map/Chapter_03/Chapter_03_LocSeq", "/Game/Map/Chapter_03/GameDesign/Ch03_C1_MainMission",
    "/Game/Map/Chapter_03/GameDesign/Ch03_MiniGame_balloon",
    "/Game/Map/Chapter_04/Chapter_04_LocSeq", "/Game/Map/Chapter_04/Chapter_04_2_LocSeq",
    "/Game/Map/Chapter_04/GameDesign/Ch04_D1_MainMission", "/Game/Map/Chapter_04/GameDesign/Ch04_D2Level_Story_Mechanic",
    "/Game/Map/Chapter_04/GameDesign/Ch04_D2_MainMission", "/Game/Map/Chapter_04/GameDesign/Ch04_MiniGame_BossOkabe",
    "/Game/Map/Chapter_04/GameDesign/Ch04_MiniGame_BossRin",
    "/Game/Map/AllChapters/Level_CH03_MiniBoss_Rin", "/Game/Map/AllChapters/Level_Door_Ch4-2",
    "/Game/Map/AllChapters/Level_Side_Items_3F", "/Game/Map/AllChapters/Level_Side_Items_B1",
    "/Game/Map/AllChapters/Level_Side_Items_Classroom", "/Game/Map/AllChapters/HouseTrap",
    "/Game/Map/AllChapters/Level_SpecialPath",
    "/Game/Map/Level_Scenes/LV_04-2_Classroom", "/Game/Map/Level_Scenes/LV_04-2_Classroom_Furniture",
    "/Game/Map/Level_Scenes/Level_Ch3_Furnitures", "/Game/Map/Level_Scenes/Level_Ch4_B1_Ending",
    "/Game/Map/Level_Scenes/Level_Ch4_B1_IN_Ending", "/Game/Map/Level_Scenes/Level_Ch4_END_Blood",
    "/Game/Map/Level_Scenes/Level_Garden_Dig_Rin", "/Game/Map/Level_Scenes/Level_Garden_Dig_Yota",
    "/Game/Map/Level_Scenes/Level_SP_CH01_0101_D", "/Game/Map/Level_Scenes/Level_Ch2_B1_Hair",
}
for _, p in ipairs(PKGS) do
    local name = p:match("([^/]+)$")
    local o = safe(function() return LoadAsset(p .. "." .. name) end)
    w("load " .. p .. " = " .. tostring(o ~= nil and valid(o)))
end

local SKIP = {
    StaticMeshActor = true, PointLight = true, SpotLight = true, RectLight = true, DecalActor = true,
    BlockingVolume = true, NavModifierVolume = true, NavMeshBoundsVolume = true, AmbientSound = true,
    AudioVolume = true, PostProcessVolume = true, SkeletalMeshActor = true, WorldSettings = true,
    TriggerVolume = true, CineCameraActor = true, SphereReflectionCapture = true, InstancedFoliageActor = true,
    BP_MobAreaNode_C = true, BP_Sound_Occ_C = true, BP_LocationPoint_C = true, LevelSequenceActor = true,
    Note = true, TextRenderActor = true, BoxReflectionCapture = true, ExponentialHeightFog = true,
    LightmassImportanceVolume = true, PlayerStart = true, BP_Hide_WardrobeMesh_C = true,
}

local function scalar(v)
    local t = type(v)
    if t ~= "userdata" then return tostring(v) end
    local num = safe(function() return v:GetArrayNum() end)
    if not num then
        local s = safe(function() return v:ToString() end)
        if s then return s end
    end
    if num then
        local arr = {}
        safe(function() v:ForEach(function(_, e)
            local ev = e:get()
            arr[#arr + 1] = (type(ev) == "userdata") and (safe(function() return ev:ToString() end)
                or safe(function() return ev:GetFName():ToString() end) or "obj") or tostring(ev)
        end) end)
        return "[" .. table.concat(arr, ",") .. "]"
    end
    return nil
end

local function bpVars(a)
    local s = {}
    local c = a:GetClass()
    local d = 0
    while c and valid(c) and d < 4 do
        local cn = c:GetFName():ToString()
        if cn == "Actor" or cn == "Character" or cn == "Pawn" then break end
        safe(function() c:ForEachProperty(function(p)
            local n = p:GetFName():ToString()
            local t = p:GetClass():GetFName():ToString()
            if t ~= "ObjectProperty" and t ~= "StructProperty" and t ~= "MulticastInlineDelegateProperty"
                and t ~= "MulticastSparseDelegateProperty" and t ~= "DelegateProperty"
                and not n:find("Timeline") and not n:find("UberGraph") and not n:find("__Direction") then
                local v = scalar(safe(function() return a[n] end))
                if v and v ~= "" and v ~= "[]" then s[#s + 1] = n .. "=" .. v end
            end
        end) end)
        c = c:GetSuperStruct(); d = d + 1
    end
    return table.concat(s, " ; ")
end

local lines = {}
local count = 0
for _, a in ipairs(FindAllOf("Actor") or {}) do
    local cn = safe(function() return a:GetClass():GetFName():ToString() end) or "?"
    if not SKIP[cn] and not cn:find("^MC_") then
        local fn = safe(function() return a:GetFullName() end) or ""
        local pkg = fn:match(" (/[^%.]+)%.") or "?"
        if pkg ~= "/Engine/Transient" then
            -- So leitura de propriedade (sem chamar funcoes): atores de mapas carregados como dados nao estao inicializados
            local l = safe(function() return a.RootComponent.RelativeLocation end)
            local lx = l and safe(function() return l.X end)
            local loc = "?"
            if type(lx) == "number" then loc = string.format("%.0f,%.0f,%.0f", l.X, l.Y, l.Z) end
            local id = safe(function() return a.InteractActorID:ToString() end) or ""
            lines[#lines + 1] = pkg .. " | " .. cn .. " | " .. (safe(function() return a:GetFName():ToString() end) or "?")
                .. " | id=" .. id .. " | at=" .. loc .. " | " .. bpVars(a)
            count = count + 1
        end
    end
end
table.sort(lines)
local f = io.open("ue4ss/Mods/SpiralCompass/data/actors_all.txt", "w")
f:write(table.concat(lines, "\n"))
f:close()
w("actors=" .. count)
