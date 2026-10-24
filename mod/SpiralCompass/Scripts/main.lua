-- Spiral Compass: lado do jogo (mod Lua para UE4SS). Le comandos de cmd.txt (escrito pelo painel) e publica estado em state.txt.
local DIR = "ue4ss/Mods/SpiralCompass/"
local CMD_FILE = DIR .. "cmd.txt"
local STATE_FILE = DIR .. "state.txt"
local ST = "/Game/DataTable/ST_StringTable.ST_StringTable"

local cfg = { stamina = false, god = false, speed = 1.0, freeze = false, unseen = false, traps = false }
local seqSeen = {} -- ultima sequencia vista por acao (tp/bring/give)
local applied = { pawnAddr = nil, speed = 1.0, unseen = false, freeze = false, god = false }
local base = nil
local targets, guide = {}, {}
local quest = nil
local lastMsg = ""
local tick = 0

local function safe(f, ...)
    local ok, r = pcall(f, ...)
    if ok then return r end
    return nil
end

local function valid(o)
    return o ~= nil and safe(function() return o:IsValid() end) == true
end

local function str(v)
    if v == nil then return nil end
    if type(v) == "string" then return v end
    return safe(function() return v:ToString() end)
end

local function clean(s)
    return (tostring(s or ""):gsub("[\r|]", " "):gsub("\n", "\\n"))
end

---------------------------------------------------------------------------
-- Andares e salas (calibrado a partir do widget do mapa do jogo)
---------------------------------------------------------------------------
local function floorNum(z)
    if z < -400 then return -1 end
    if z < 250 then return 1 end
    if z < 730 then return 2 end
    return 3
end

local FLOOR_NAME = { [-1] = "Subsolo", [1] = "1º andar", [2] = "2º andar", [3] = "3º andar (sótão)" }

-- Centro dos rotulos de sala no canvas do mapa (WBP_FloorMapPanel_*), em pixels
local ROOMS = {
    [1] = {
        { "Sala de Recepção", 1332, 1061 }, { "Sala de Exposição", 1151, 1075 }, { "Restaurante", 1458, 1039 },
        { "Cozinha", 1668, 1039 }, { "Bar", 1106, 1331 }, { "Sala de Bilhar", 1106, 1431 },
        { "Saguão - Frente", 1282, 1272 }, { "Galeria de Arte", 1458, 1254 }, { "Quarto", 1091, 943 },
        { "Depósito", 991, 886 }, { "Corredor dos Fundos", 1304, 981 }, { "Sala de Conferências", 1016, 1225 },
        { "Saguão - Fundos", 1282, 1157 }, { "Salão", 1458, 1365 }, { "Escritório", 1596, 1214 },
    },
    [2] = {
        { "Quarto Principal", 1281, 1113 }, { "Quarto Principal", 1428, 919 }, { "Escritório (centro)", 1456, 1100 },
        { "Alojamentos dos Serviçais", 1662, 1314 }, { "Corredor Central", 1281, 1249 }, { "Quarto de Hóspedes", 1055, 1257 },
        { "Quarto de Hóspedes", 975, 1294 }, { "Sala de Estar", 1112, 1040 }, { "Sala de Brunch", 1091, 886 },
        { "Escritório (oeste)", 955, 898 }, { "Sala", 1491, 1365 }, { "Quarto", 1478, 1260 },
        { "Sala Vazia A", 1690, 981 }, { "Sala Vazia B", 1668, 1063 }, { "Café", 1397, 1275 },
        { "Quarto Principal", 1352, 1000 }, { "Quarto Principal", 1242, 1010 }, { "Sala de Estar", 1005, 1025 },
        { "Quarto de Hóspedes", 1129, 1289 }, { "Corredor Sul", 1280, 1337 },
    },
}

local function roomOf(x, y, z)
    local f = floorNum(z)
    local list = ROOMS[f]
    if not list then return FLOOR_NAME[f] end
    local u, v = 0.15268 * x + 1276.12, 0.13421 * y + 811.36
    local best, bd = nil, 1e18
    for _, r in ipairs(list) do
        local d = (r[2] - u) ^ 2 + (r[3] - v) ^ 2
        if d < bd then best, bd = r[1], d end
    end
    return best or FLOOR_NAME[f]
end

local function where(x, y, z)
    local f = floorNum(z)
    if not ROOMS[f] then return FLOOR_NAME[f] end
    return roomOf(x, y, z) .. " · " .. FLOOR_NAME[f]
end

---------------------------------------------------------------------------
-- Dados do jogo (tabelas + textos traduzidos), carregados uma vez
---------------------------------------------------------------------------
local data = nil

local function text(key)
    if not key or key == "" or key == "0" then return nil end
    local ktl = StaticFindObject("/Script/Engine.Default__KismetTextLibrary")
    local t = safe(function() return ktl:TextFromStringTable(FName(ST), key):ToString() end)
    if t == nil or t == "" or t:find("MISSING STRING", 1, true) then return nil end
    return t
end

local function loadData()
    local d = { itemName = {}, inter = {}, quests = {} }
    local dtItem = StaticFindObject("/Game/DataTable/DT_Item.DT_Item")
    if not valid(dtItem) then return nil end
    safe(function()
        dtItem:ForEachRow(function(_, row)
            local id = tostring(safe(function() return row.ID end))
            d.itemName[id] = text(str(row.NameSID)) or ("Item " .. id)
        end)
    end)
    local dtInter = StaticFindObject("/Game/DataTable/DT_InteractableActor.DT_InteractableActor")
    safe(function()
        dtInter:ForEachRow(function(_, row)
            local id = str(row.ID)
            if id and id ~= "" then
                local uses = {}
                safe(function() row.UseItemIDs:ForEach(function(_, e) uses[#uses + 1] = str(e:get()) end) end)
                d.inter[id] = { item = str(row.ItemID), uses = uses }
            end
        end)
    end)
    local dtQuest = StaticFindObject("/Game/DataTable/DT_Quest.DT_Quest")
    safe(function()
        dtQuest:ForEachRow(function(_, row)
            local title = text(tostring(safe(function() return row.QuestStrID end)))
            local desc = text(tostring(safe(function() return row.DescStrID end)))
            local guid = safe(function() return row.Guid end)
            if title then d.quests[#d.quests + 1] = { title = title, desc = desc or "", id = guid } end
        end)
    end)
    return d
end

local function itemName(id)
    return (data and data.itemName[tostring(id)]) or ("Item " .. tostring(id))
end

-- Missao atual: (1) evento do jogo ao iniciar missao, (2) titulo exibido no painel de missao,
-- (3) ultima missao conhecida salva em arquivo (sobrevive a reinicios do jogo).
local QUEST_FILE = DIR .. "last_quest.txt"
local questBlock = nil

local function setQuestById(id)
    local title = text("513" .. tostring(id))
    if not title then return end
    quest = { title = title, desc = text("514" .. tostring(id)) or "" }
    local f = io.open(QUEST_FILE, "w")
    if f then f:write(tostring(id)) f:close() end
end

local function loadLastQuest()
    local f = io.open(QUEST_FILE, "r")
    if f then
        local id = f:read("l")
        f:close()
        if id and id:match("%d+") then
            local ok, err = pcall(setQuestById, id:match("%d+"))
            if not ok then print("[SpiralCompass] quest erro: " .. tostring(err) .. "\n") end
        end
    end
end

pcall(function()
    RegisterHook("/Script/JIM.ExploreState:HandleQuestBegin", function(_, groupId, questId)
        local id = safe(function() return questId:get() end)
        if id then pcall(setQuestById, id) end
    end)
end)

local function detectQuest()
    if not data or #data.quests == 0 then return end
    local byTitle = {}
    for _, q in ipairs(data.quests) do byTitle[q.title] = q end
    if not valid(questBlock) then
        questBlock = nil
        for _, tb in ipairs(FindAllOf("TextBlock") or {}) do
            local fn = safe(function() return tb:GetFullName() end) or ""
            if fn:find("WBP_QuestMessagePanel", 1, true) and fn:find("TitleTextBlock", 1, true)
                and not fn:find(" /Game/", 1, true) then
                local s = safe(function() return tb:GetText():ToString() end)
                if s and byTitle[s] then questBlock = tb break end
            end
        end
    end
    if questBlock then
        local s = safe(function() return questBlock:GetText():ToString() end)
        if s and byTitle[s] and (not quest or quest.title ~= s) then
            if byTitle[s].id then pcall(setQuestById, byTitle[s].id) else quest = byTitle[s] end
        end
    end
end

---------------------------------------------------------------------------
-- Estado do mundo: inventario, mecanismos, atores por ID
---------------------------------------------------------------------------
local world = { pawn = nil, have = {}, mech = {}, byId = {} }

local function have(id)
    id = tonumber(id)
    if world.have[id] == nil then
        local ifl = StaticFindObject("/Script/JIM.Default__ItemFunctionLibrary")
        world.have[id] = safe(function() return ifl:CheckItemNumber(world.pawn, id, 1) end) == true
    end
    return world.have[id]
end

local function refreshWorld(pawn)
    world.pawn = pawn
    world.have = {}
    world.mech = {}
    local ms = FindFirstOf("MechanicSystem")
    if valid(ms) then
        safe(function() ms.MechanicStateMap:ForEach(function(k, v) world.mech[k:get():ToString()] = v:get() end) end)
    end
    world.byId = {}
    for _, a in ipairs(FindAllOf("InteractableActor") or {}) do
        if valid(a) then
            local id = safe(function() return a.InteractActorID:ToString() end)
            if id and id ~= "" then
                local l = safe(function() return a:K2_GetActorLocation() end)
                if l then
                    world.byId[id] = {
                        actor = a, x = l.X, y = l.Y, z = l.Z,
                        hidden = safe(function() return a.bHidden end) == true,
                        can = safe(function() return a.bCanInteract end) ~= false,
                        locked = safe(function() return a.bIsLocked end) == true,
                        cls = safe(function() return a:GetClass():GetFName():ToString() end) or "",
                    }
                end
            end
        end
    end
end

local function mech(name) return world.mech[name] or 0 end
local function act(id) return world.byId[tostring(id)] end

-- Onde esta um item: com voce / no mapa (sala) / ainda nao disponivel
local function itemStatus(id)
    if have(id) then return "have", "✔ com você" end
    for _, a in pairs(world.byId) do
        local info = data and data.inter[safe(function() return a.actor.InteractActorID:ToString() end) or ""]
        local itemId = info and info.item
        if (itemId == tostring(id)) and not a.hidden and a.can and a.cls ~= "" then
            return "map", "no mapa: " .. where(a.x, a.y, a.z), a
        end
    end
    local a = act(id)
    if a and not a.hidden and a.can then return "map", "no mapa: " .. where(a.x, a.y, a.z), a end
    return "none", "ainda não disponível (aparece mais adiante, ou já foi usado)"
end

---------------------------------------------------------------------------
-- Guia do capitulo (enigmas conhecidos + solucoes extraidas dos dados do jogo)
---------------------------------------------------------------------------
local COMPANION_SPOTS = {
    ["130111"] = "Caixa do Palhaço", ["130112"] = "Balança", ["130113"] = "investigação (Distintivo de Polícia)",
    ["130121"] = "Máscaras Noh", ["130122"] = "Máquina de golfe do 2º andar", ["130123"] = "próxima investigação",
}

local PUZZLES = {
    {
        key = "clown", title = "Caixa do Palhaço", actor = "57051", reward = { 57003 },
        solution = "Três anéis giratórios. Pelos dados do jogo os anéis começam em 120°, 240° e 120° e cada giro soma 120°: "
            .. "gire o anel 1 duas vezes, o anel 2 uma vez e o anel 3 duas vezes para alinhar a figura do palhaço.",
        done = function() return mech("PuzzleBox") > 0 or have(57003) end,
    },
    {
        key = "libra", title = "Balança dos pesos", actor = "57101", needs = { 57102, 57103, 57104 }, reward = { 50106, 57152 },
        solution = "O prato esquerdo pesa 125. Coloque no prato direito: Dedo (70) + Nariz (45) + Orelha (10) = 125. "
            .. "NÃO coloque o Olho (30). A gaveta abre com a Chave: Sala do 2º Andar e a Adaga Oculta.",
        done = function() return mech("Mech_Libra") > 0 or have(50106) end,
    },
    {
        key = "door2f", title = "Porta trancada da Sala (2º andar)", actor = "54116", needs = { 50106 }, reward = { 60122 },
        solution = "Use a Chave: Sala do 2º Andar (vem da Balança). Lá dentro estão as Notas do Mordomo - 4.",
        done = function() local a = act("54116"); return a ~= nil and not a.locked end,
    },
    {
        key = "masks", title = "Máscaras Noh", actor = "58053", reward = {},
        solution = "Notas do Mordomo 5: três máscaras Noh na parede do escritório; a Hannya representa ciúme e ressentimento. "
            .. "Examine as máscaras (Feminina, Masculina e Hannya) — a Hannya é a chave do enigma.",
        done = function() return mech("Mask3") > 0 end,
    },
    {
        key = "golf2", title = "Máquina de golfe (2º andar)", actor = "58101", needs = { 58102 }, reward = { 58004 },
        solution = "Notas do Mordomo 3: role a bola até o verde para terminar a rodada. Recompensa: Componente Prateado: Triângulo.",
        done = function() return mech("Mech_RollingPlatform_2") > 0 or have(58004) end,
    },
    {
        key = "gold", title = "Encaixe dourado (1º andar)", actor = "57001", needs = { 57003, 57004 }, reward = {},
        solution = "Encaixe os dois Componentes Dourados: Lua (da Caixa do Palhaço) e Rastro de Estrelas.",
        done = function() local a = act("57001"); return a ~= nil and not a.can end,
    },
    {
        key = "silver", title = "Encaixe prateado (1º andar)", actor = "58001", needs = { 58003, 58004 }, reward = {},
        solution = "Encaixe os dois Componentes Prateados: Flecha e Triângulo (da máquina de golfe do 2º andar).",
        done = function() local a = act("58001"); return a ~= nil and not a.can end,
    },
    {
        key = "pig", title = "Cofrinho (perto da escada da cozinha)", actor = "56151", needs = { 56153, 56154, 56155 }, reward = {},
        solution = "Notas do Mordomo 2: coloque as três moedas no cofrinho antes de ir para a adega.",
        done = function() local a = act("56151"); return a ~= nil and not a.can end,
    },
}

local function companionNear(x, y, z)
    for _, cn in ipairs({ { "BPC_Kawakami_C", "Tomie" }, { "BPC_Rin_C", "Rin" } }) do
        for _, c in ipairs(FindAllOf(cn[1]) or {}) do
            local l = safe(function() return c:K2_GetActorLocation() end)
            if l and math.abs(l.X - x) + math.abs(l.Y - y) < 250 then return cn[2] end
        end
    end
    return nil
end

local function buildGuide(pl)
    local g = {}
    local function add(e)
        local dx, dy, dz = e.x - pl.X, e.y - pl.Y, e.z - pl.Z
        e.dist = math.sqrt(dx * dx + dy * dy + dz * dz)
        g[#g + 1] = e
    end

    -- 1) Companheiras esperando (indica a etapa atual da historia)
    for id, label in pairs(COMPANION_SPOTS) do
        local a = act(id)
        if a and not a.hidden and a.can then
            local who = companionNear(a.x, a.y, a.z) or "Uma companheira"
            add({
                status = "agora", title = who .. " te espera: " .. label, x = a.x, y = a.y, z = a.z,
                detail = who .. " está parada em " .. where(a.x, a.y, a.z) .. " esperando você.\nVá até ela e interaja para começar: " .. label .. ".",
                give = "",
            })
        end
    end

    -- 2) Enigmas conhecidos
    for _, p in ipairs(PUZZLES) do
        local a = act(p.actor)
        if a then
            local isDone = safe(p.done) == true
            local lines, missing, giveIds = {}, 0, {}
            for _, n in ipairs(p.needs or {}) do
                local st, txt = itemStatus(n)
                if st ~= "have" then missing = missing + 1 end
                lines[#lines + 1] = "• " .. itemName(n) .. " — " .. txt
                if st ~= "have" then giveIds[#giveIds + 1] = tostring(n) end
            end
            local status
            if isDone then status = "feito"
            elseif missing == 0 then status = "pronto"
            else status = "falta" end
            local detail = "Local: " .. where(a.x, a.y, a.z)
            if #lines > 0 and not isDone then detail = detail .. "\n\nPrecisa de:\n" .. table.concat(lines, "\n") end
            detail = detail .. "\n\nComo resolver:\n" .. p.solution
            if p.reward and #p.reward > 0 then
                local r = {}
                for _, id in ipairs(p.reward) do r[#r + 1] = itemName(id) end
                detail = detail .. "\n\nRecompensa: " .. table.concat(r, ", ")
            end
            if status == "feito" then detail = "✔ Já resolvido.\n\n" .. detail end
            -- "Receber" = itens que faltam (se falta) ou recompensa (se travado no enigma)
            local give = (status == "falta") and giveIds or {}
            if status == "pronto" and p.reward then for _, id in ipairs(p.reward) do give[#give + 1] = tostring(id) end end
            add({ status = status, title = p.title, x = a.x, y = a.y, z = a.z, detail = detail, give = table.concat(give, ",") })
        end
    end

    -- 3) Automatico: qualquer outro lugar do jogo que pede itens (funciona em capitulos novos)
    local known = {}
    for _, p in ipairs(PUZZLES) do known[p.actor] = true end
    for id, a in pairs(world.byId) do
        local info = data and data.inter[id]
        if not known[id] and info and #info.uses > 0 and not a.hidden then
            local lines, missing, giveIds, names, traceable = {}, 0, {}, {}, 0
            for _, n in ipairs(info.uses) do
                local st, txt = itemStatus(n)
                if st ~= "have" then missing = missing + 1 giveIds[#giveIds + 1] = tostring(n) end
                if st ~= "none" then traceable = traceable + 1 end
                lines[#lines + 1] = "• " .. itemName(n) .. " — " .. txt
                names[#names + 1] = itemName(n)
            end
            local isDoor = a.cls:find("Door", 1, true) ~= nil
            local status
            if (not a.can and not a.locked) or (traceable == 0 and not a.locked) then
                status = "feito" -- nenhum item no mapa nem com voce: ja foi usado
            elseif missing == 0 then
                status = "pronto"
            else
                status = "falta"
            end
            local title = (isDoor and "Porta: usar " or "Usar ") .. table.concat(names, " + ")
            local detail = "Local: " .. where(a.x, a.y, a.z)
            if status == "feito" then
                detail = "✔ Provavelmente já resolvido (não dá mais para interagir).\n\n" .. detail
            else
                detail = detail .. "\n\nPrecisa de:\n" .. table.concat(lines, "\n")
                    .. "\n\n(Detectado automaticamente pelos dados do jogo — sem solução escrita para este enigma.)"
            end
            add({ status = status, title = title, x = a.x, y = a.y, z = a.z, detail = detail,
                give = (status == "falta") and table.concat(giveIds, ",") or "" })
        end
    end

    local order = { agora = 1, pronto = 2, falta = 3, feito = 4 }
    table.sort(g, function(p, q)
        if order[p.status] ~= order[q.status] then return order[p.status] < order[q.status] end
        return p.dist < q.dist
    end)
    return g
end

---------------------------------------------------------------------------
-- Portas trancadas: aviso de "atras de porta trancada"
---------------------------------------------------------------------------
local function lockedDoors()
    local list = {}
    for id, a in pairs(world.byId) do
        if a.locked and not a.hidden and a.cls:find("Door", 1, true) then
            local fwd = safe(function() return a.actor:GetActorForwardVector() end)
            local need = {}
            local info = data and data.inter[id]
            if info then for _, u in ipairs(info.uses) do need[#need + 1] = itemName(u) end end
            list[#list + 1] = { x = a.x, y = a.y, z = a.z, fx = fwd and fwd.X or 1, fy = fwd and fwd.Y or 0,
                need = (#need > 0) and table.concat(need, ", ") or "abre pela história" }
        end
    end
    return list
end

local function lockWarning(doors, pl, x, y, z)
    for _, d in ipairs(doors) do
        if floorNum(d.z + 50) == floorNum(z) then
            local dist = math.sqrt((x - d.x) ^ 2 + (y - d.y) ^ 2)
            if dist < 900 then
                local sideT = (x - d.x) * d.fx + (y - d.y) * d.fy
                local sideP = (pl.X - d.x) * d.fx + (pl.Y - d.y) * d.fy
                local playerFar = floorNum(pl.Z) ~= floorNum(z) or math.sqrt((pl.X - d.x) ^ 2 + (pl.Y - d.y) ^ 2) > 1200
                if (sideT * sideP < 0) or (playerFar and roomOf(x, y, z) == roomOf(d.x + d.fx * 200, d.y + d.fy * 200, d.z + 50)) then
                    return "Pode estar atrás de uma porta trancada (precisa: " .. d.need .. ")"
                end
            end
        end
    end
    return ""
end

---------------------------------------------------------------------------
-- Localizador de itens
---------------------------------------------------------------------------
local function scanTargets(pl)
    local list = {}
    local doors = lockedDoors()
    for _, a in ipairs(FindAllOf("CollectableActor") or {}) do
        if valid(a) and safe(function() return a.bHidden end) ~= true and safe(function() return a.bCanInteract end) ~= false then
            local id = safe(function() return a.InteractActorID:ToString() end) or ""
            local info = data and data.inter[id]
            local itemId = (info and info.item and info.item ~= "") and info.item or id
            local l = safe(function() return a:K2_GetActorLocation() end)
            if l then
                local isTrap = itemId == "40001"
                if not isTrap or cfg.traps then
                    local dx, dy, dz = l.X - pl.X, l.Y - pl.Y, l.Z - pl.Z
                    local warn = lockWarning(doors, pl, l.X, l.Y, l.Z)
                    list[#list + 1] = {
                        cat = isTrap and "Armadilha" or "Item", name = itemName(itemId),
                        x = l.X, y = l.Y, z = l.Z, dist = math.sqrt(dx * dx + dy * dy + dz * dz),
                        room = where(l.X, l.Y, l.Z), warn = warn, id = itemId,
                    }
                end
            end
        end
    end
    table.sort(list, function(p, q) return p.dist < q.dist end)
    return list
end

---------------------------------------------------------------------------
-- Acoes vindas do painel
---------------------------------------------------------------------------
-- Altura do chao de cada andar (FLOOR_HEIGHTS do mapa do jogo) + meia altura da capsula do personagem
local FLOOR_Z = { [-1] = -795, [1] = 2, [2] = 502, [3] = 952 }

-- Lugares para teleporte rapido. Salas: centro do rotulo no mapa do jogo convertido para o mundo.
-- Areas externas: pontos de cena/renascimento do proprio jogo (Z ja e a altura do personagem).
local AREAS = {
    { "Mansão · 1º andar", "Saguão - Frente", 38, 3432, 87 }, { "Mansão · 1º andar", "Saguão - Fundos", 38, 2575, 87 },
    { "Mansão · 1º andar", "Galeria de Arte", 1191, 3298, 87 }, { "Mansão · 1º andar", "Salão", 1191, 4125, 87 },
    { "Mansão · 1º andar", "Escritório", 2095, 2999, 87 }, { "Mansão · 1º andar", "Restaurante", 1191, 1696, 87 },
    { "Mansão · 1º andar", "Cozinha", 2567, 1696, 87 }, { "Mansão · 1º andar", "Sala de Recepção", 366, 1860, 87 },
    { "Mansão · 1º andar", "Sala de Exposição", -819, 1964, 87 }, { "Mansão · 1º andar", "Corredor dos Fundos", 182, 1264, 87 },
    { "Mansão · 1º andar", "Quarto", -1213, 981, 87 }, { "Mansão · 1º andar", "Depósito", -1868, 556, 87 },
    { "Mansão · 1º andar", "Sala de Conferências", -1704, 3082, 87 }, { "Mansão · 1º andar", "Bar", -1115, 3872, 87 },
    { "Mansão · 1º andar", "Sala de Bilhar", -1115, 4617, 87 }, { "Mansão · 1º andar", "Quarto seguro (1º andar)", -1519, 1078, 87 },
    { "Mansão · 2º andar", "Corredor Central", 34, 3261, 587 }, { "Mansão · 2º andar", "Corredor Sul", 25, 3917, 587 },
    { "Mansão · 2º andar", "Quarto Principal", 34, 2248, 587 }, { "Mansão · 2º andar", "Escritório (centro)", 1180, 2151, 587 },
    { "Mansão · 2º andar", "Escritório (oeste)", -2104, 646, 587 }, { "Mansão · 2º andar", "Sala de Brunch", -1213, 556, 587 },
    { "Mansão · 2º andar", "Sala de Estar", -1076, 1704, 587 }, { "Mansão · 2º andar", "Quarto de Hóspedes", -1449, 3321, 587 },
    { "Mansão · 2º andar", "Café", 791, 3455, 587 }, { "Mansão · 2º andar", "Quarto", 1322, 3343, 587 },
    { "Mansão · 2º andar", "Sala", 1407, 4125, 587 }, { "Mansão · 2º andar", "Sala Vazia A", 2711, 1264, 587 },
    { "Mansão · 2º andar", "Sala Vazia B", 2567, 1875, 587 }, { "Mansão · 2º andar", "Alojamentos dos Serviçais", 2529, 3741, 587 },
    { "Mansão · 2º andar", "Quarto seguro (2º andar)", 1156, 1484, 587 },
    { "Sótão", "Sótão (quarto seguro)", 1189, 3479, 1037 }, { "Sótão", "Sótão (início do jogo)", 1383, 3567, 1037 },
    { "Fora da mansão", "Jardim (frente)", 915, -1511, -100 }, { "Fora da mansão", "Jardim (estátuas)", 255, -2951, -100 },
    { "Fora da mansão", "Chalé do Jardim", 2272, -397, 90 },
    { "Subsolo", "Porão (sala do cabelo)", 1600, 2000, -700 }, { "Subsolo", "Porão Oculto", -2451, 6454, -710 },
}

local function teleportTo(pawn, x, y, z, exact)
    local pl = safe(function() return pawn:K2_GetActorLocation() end)
    if not pl then return end
    local standZ = exact and z or ((FLOOR_Z[floorNum(z)] or z) + 95)
    -- Direcao preferida: do alvo para o jogador; depois as outras 7 direcoes
    local base = math.atan(pl.Y - y, pl.X - x)
    for _, dist in ipairs(exact and { 0, 90, 150, 220, 300 } or { 90, 150, 220, 300 }) do
        for k = 0, 7 do
            local ang = base + (k % 2 == 0 and 1 or -1) * math.ceil(k / 2) * math.pi / 4
            local cx, cy = x + math.cos(ang) * dist, y + math.sin(ang) * dist
            local yaw = math.deg(math.atan(y - cy, x - cx))
            for _, cz in ipairs({ standZ, standZ + 40 }) do
                local ok = safe(function()
                    return pawn:K2_TeleportTo({ X = cx, Y = cy, Z = cz }, { Pitch = 0, Yaw = yaw, Roll = 0 })
                end)
                if ok ~= false then
                    -- vira a camera para o alvo
                    safe(function() FindFirstOf("GamePlayerController"):SetControlRotation({ Pitch = 0, Yaw = yaw, Roll = 0 }) end)
                    lastMsg = "Teleportado para " .. (exact and (FLOOR_NAME[floorNum(z)] or "") or where(x, y, z))
                    return
                end
            end
        end
    end
    lastMsg = "Teleporte bloqueado: não achei espaço livre perto do alvo (use \"Trazer item até mim\")"
end

local function bringItem(pawn, x, y, z)
    local best, bd = nil, 1e18
    for _, a in ipairs(FindAllOf("CollectableActor") or {}) do
        local l = valid(a) and safe(function() return a:K2_GetActorLocation() end)
        if l then
            local d = (l.X - x) ^ 2 + (l.Y - y) ^ 2 + (l.Z - z) ^ 2
            if d < bd then best, bd = a, d end
        end
    end
    if not best or bd > 100 * 100 then lastMsg = "Item não encontrado" return end
    local pl = pawn:K2_GetActorLocation()
    local fwd = safe(function() return pawn:GetActorForwardVector() end) or { X = 1, Y = 0 }
    local dest = { X = pl.X + fwd.X * 110, Y = pl.Y + fwd.Y * 110, Z = pl.Z - 20 }
    local ok = safe(function() return best:K2_TeleportTo(dest, { Pitch = 0, Yaw = 0, Roll = 0 }) end)
    if ok == false then
        safe(function() best:K2_SetActorLocation(dest, false, {}, true) end)
    end
    local nl = safe(function() return best:K2_GetActorLocation() end)
    if nl and math.abs(nl.X - dest.X) < 50 then
        lastMsg = "Item trazido até você — olhe para frente e pegue normalmente"
    else
        lastMsg = "Este item está preso ao cenário e não pode ser movido; use o teleporte"
    end
end

local function giveItems(pc, ids)
    local cm = safe(function() return pc.CheatManager end)
    if not valid(cm) then lastMsg = "CheatManager indisponível" return end
    local names = {}
    for id in ids:gmatch("%d+") do
        safe(function() cm:AddItem(tonumber(id), 1) end)
        names[#names + 1] = itemName(id)
    end
    lastMsg = "Recebido: " .. table.concat(names, ", ")
end

local function action(c, key)
    local v = c and c[key]
    if not v or v == "" then return nil end
    local seq, rest = v:match("^(%d+):(.*)$")
    if not seq then return nil end
    local prev = seqSeen[key]
    seqSeen[key] = seq
    -- ignora o primeiro valor visto (evita repetir acao antiga ao recarregar o mod)
    if prev == nil or prev == seq or seq == "0" then return nil end
    return rest
end

local function xyz(s)
    local x, y, z, e = (s or ""):match("^(%-?[%d%.]+),(%-?[%d%.]+),(%-?[%d%.]+)(,?e?)$")
    if x then return tonumber(x), tonumber(y), tonumber(z), e == ",e" end
end

---------------------------------------------------------------------------
-- Cheats
---------------------------------------------------------------------------
local function readCmd()
    local f = io.open(CMD_FILE, "r")
    if not f then return nil end
    local t = {}
    for line in f:lines() do
        local k, v = line:match("^(%w+)=(.*)$")
        if k then t[k] = v end
    end
    f:close()
    return t
end

local function getPlayer()
    local pc = FindFirstOf("GamePlayerController")
    if not valid(pc) then return nil, nil end
    local pawn = safe(function() return pc.Pawn end)
    if not valid(pawn) then return pc, nil end
    return pc, pawn
end

local function applySpeed(pc, pawn)
    if not base then
        base = {
            pcWalk = safe(function() return pc.WalkSpeed end) or 180,
            pcRun = safe(function() return pc.RunSpeed end) or 300,
            walk = safe(function() return pawn.WalkSpeed end) or 140,
            run = safe(function() return pawn.RunSpeed end) or 250,
        }
    end
    local m = cfg.speed
    safe(function() pc.WalkSpeed = base.pcWalk * m end)
    safe(function() pc.RunSpeed = base.pcRun * m end)
    safe(function() pawn.WalkSpeed = base.walk * m end)
    safe(function() pawn.RunSpeed = base.run * m end)
    local running = safe(function() return pc.bIsCharacterRunning end)
    local want = (running and base.pcRun or base.pcWalk) * m
    local cmc = safe(function() return pawn.CharacterMovement end)
    if valid(cmc) then
        safe(function() cmc.MaxWalkSpeed = want end)
        safe(function() cmc.MaxWalkSpeedCrouched = 150 * m end)
        if m > 1 then safe(function() cmc.MaxAcceleration = 2048 * m end) end
    end
end

local function setEnemiesFrozen(pawn, frozen)
    local paddr = safe(function() return pawn:GetAddress() end)
    for _, ch in ipairs(FindAllOf("GameCharacter") or {}) do
        if valid(ch) and safe(function() return ch:GetAddress() end) ~= paddr then
            local cn = safe(function() return ch:GetClass():GetFName():ToString() end) or ""
            -- Rin e Tomie so congelam quando sao inimigas (fora dos pontos de espera da historia)
            safe(function() ch.CustomTimeDilation = frozen and 0.0 or 1.0 end)
        end
    end
end

local function step()
    local c = readCmd()
    if c then
        cfg.stamina = c.stamina == "1"
        cfg.god = c.god == "1"
        cfg.freeze = c.freeze == "1"
        cfg.unseen = c.unseen == "1"
        cfg.traps = c.traps == "1"
        cfg.speed = tonumber(c.speed or "1") or 1.0
    end

    local pc, pawn = getPlayer()
    if not pawn then
        local f = io.open(STATE_FILE, "w")
        if f then f:write("time=" .. os.time() .. "\ningame=0") f:close() end
        return
    end

    if not data then data = loadData() end

    local addr = safe(function() return pawn:GetAddress() end)
    if addr ~= applied.pawnAddr then
        applied.pawnAddr = addr
        base = nil
        applied.speed = 1.0
        applied.unseen = false
        applied.freeze = false
    end

    if cfg.stamina then
        local mx = safe(function() return pawn:GetMaxStamina() end) or 10000
        if (safe(function() return pawn:GetStamina() end) or 0) < mx then
            safe(function() pawn:SetStamina(mx) end)
        end
    end

    if cfg.god then
        local mx = safe(function() return pawn:GetMaxHealthPoint() end) or 100
        local hp = safe(function() return pawn:GetHealthPoint() end) or mx
        if hp < mx then safe(function() pawn:AddHealthPoint(mx - hp) end) end
        safe(function() pawn.bCanBeDamaged = false end)
    elseif applied.god then
        safe(function() pawn.bCanBeDamaged = true end)
    end
    applied.god = cfg.god

    if cfg.speed ~= 1.0 or applied.speed ~= 1.0 then
        applySpeed(pc, pawn)
        applied.speed = cfg.speed
    end

    if cfg.unseen then
        safe(function() pawn.AISightNeedNum = 999 end)
        safe(function() pawn.bDebugAICanSeePlayer = false end)
    elseif applied.unseen then
        safe(function() pawn.AISightNeedNum = 2 end)
        safe(function() pawn.bDebugAICanSeePlayer = true end)
    end
    applied.unseen = cfg.unseen

    if cfg.freeze then
        if not applied.freeze or tick % 4 == 0 then setEnemiesFrozen(pawn, true) end
    elseif applied.freeze then
        setEnemiesFrozen(pawn, false)
    end
    applied.freeze = cfg.freeze

    tick = tick + 1
    local pl = safe(function() return pawn:K2_GetActorLocation() end)
    if pl and (tick % 6 == 1 or #targets == 0) then
        refreshWorld(pawn)
        targets = scanTargets(pl)
        guide = buildGuide(pl)
    elseif pl then
        for _, list in ipairs({ targets, guide }) do
            for _, t in ipairs(list) do
                local dx, dy, dz = t.x - pl.X, t.y - pl.Y, t.z - pl.Z
                t.dist = math.sqrt(dx * dx + dy * dy + dz * dz)
            end
        end
    end
    if not quest then loadLastQuest() end
    if tick % 8 == 1 then detectQuest() end

    -- Acoes
    local tp = action(c, "tp")
    if tp then local x, y, z, e = xyz(tp); if x then teleportTo(pawn, x, y, z, e) end end
    local br = action(c, "bring")
    if br then local x, y, z = xyz(br); if x then bringItem(pawn, x, y, z) end end
    local gv = action(c, "give")
    if gv then giveItems(pc, gv) end

    -- Estado para o painel
    local out = { "time=" .. os.time(), "ingame=1" }
    out[#out + 1] = "stamina=" .. tostring(safe(function() return pawn:GetStamina() end) or "?")
    out[#out + 1] = "maxstamina=" .. tostring(safe(function() return pawn:GetMaxStamina() end) or "?")
    out[#out + 1] = "hp=" .. tostring(safe(function() return pawn:GetHealthPoint() end) or "?")
    out[#out + 1] = "maxhp=" .. tostring(safe(function() return pawn:GetMaxHealthPoint() end) or "?")
    if pl then
        out[#out + 1] = string.format("pos=%.0f,%.0f,%.0f", pl.X, pl.Y, pl.Z)
        out[#out + 1] = "where=" .. clean(where(pl.X, pl.Y, pl.Z))
    end
    local r = safe(function() return pc:GetControlRotation() end)
    if r then out[#out + 1] = string.format("yaw=%.1f", r.Yaw) end
    if quest then
        out[#out + 1] = "quest=" .. clean(quest.title)
        out[#out + 1] = "questdesc=" .. clean(quest.desc)
    end
    out[#out + 1] = "msg=" .. clean(lastMsg)
    for _, t in ipairs(targets) do
        out[#out + 1] = string.format("t=%s|%s|%.0f|%.0f|%.0f|%.0f|%s|%s|%s", t.cat, clean(t.name),
            t.x, t.y, t.z, t.dist, clean(t.room), clean(t.warn), t.id)
    end
    if pl then
        for _, a in ipairs(AREAS) do
            local d = math.sqrt((a[3] - pl.X) ^ 2 + (a[4] - pl.Y) ^ 2 + (a[5] - pl.Z) ^ 2)
            out[#out + 1] = string.format("a=%s|%s|%.0f|%.0f|%.0f|%.0f", a[1], a[2], a[3], a[4], a[5], d)
        end
    end
    for _, e in ipairs(guide) do
        out[#out + 1] = string.format("g=%s|%s|%.0f|%.0f|%.0f|%.0f|%s|%s|%s", e.status, clean(e.title),
            e.x, e.y, e.z, e.dist, clean(where(e.x, e.y, e.z)), clean(e.detail), e.give or "")
    end
    local f = io.open(STATE_FILE .. ".tmp", "w")
    if f then
        f:write(table.concat(out, "\n"))
        f:close()
        os.remove(STATE_FILE)
        os.rename(STATE_FILE .. ".tmp", STATE_FILE)
    end
end

-- Diagnostico: se existir probe.lua na pasta do mod, executa uma vez (no thread do jogo) e apaga.
local function runProbe()
    local path = DIR .. "probe.lua"
    local f = io.open(path, "r")
    if not f then return end
    local src = f:read("a")
    f:close()
    os.remove(path)
    local out = {}
    local env = setmetatable({ w = function(s) out[#out + 1] = tostring(s) end, safe = safe, valid = valid, str = str }, { __index = _G })
    local chunk, err = load(src, "probe", "t", env)
    if chunk then
        local ok, e = pcall(chunk)
        if not ok then out[#out + 1] = "ERRO: " .. tostring(e) end
    else
        out[#out + 1] = "ERRO load: " .. tostring(err)
    end
    local o = io.open(DIR .. "probe_out.txt", "w")
    if o then o:write(table.concat(out, "\n")) o:close() end
end

LoopAsync(250, function()
    ExecuteInGameThread(function()
        local ok, err = pcall(step)
        if not ok then print("[SpiralCompass] erro: " .. tostring(err) .. "\n") end
        local ok2, err2 = pcall(runProbe)
        if not ok2 then print("[SpiralCompass] probe erro: " .. tostring(err2) .. "\n") end
    end)
    return false
end)

print("[SpiralCompass] carregado\n")
