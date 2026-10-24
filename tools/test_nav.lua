-- Testa inventario (CheckItemNumber) e caminho de navegacao ate alguns itens.
local pc = FindFirstOf("GamePlayerController")
local pawn = pc and pc.Pawn
if not valid(pawn) then w("sem pawn") return end
local pl = pawn:K2_GetActorLocation()
w(string.format("player=(%.0f,%.0f,%.0f)", pl.X, pl.Y, pl.Z))

local ifl = StaticFindObject("/Script/JIM.Default__ItemFunctionLibrary")
w("ItemFunctionLibrary=" .. tostring(valid(ifl)))
for _, id in ipairs({ 40001, 50001, 50101, 50106, 56002, 56003, 56004, 56052, 56108, 57003, 57004, 58102, 60122 }) do
    local r = safe(function() return ifl:CheckItemNumber(pawn, id, 1) end)
    w("  tem item " .. id .. " = " .. tostring(r))
end

local nav = StaticFindObject("/Script/NavigationSystem.Default__NavigationSystemV1")
w("NavigationSystemV1=" .. tostring(valid(nav)))
local function test(label, x, y, z)
    local path = safe(function() return nav:FindPathToLocationSynchronously(pawn, pl, { X = x, Y = y, Z = z }, nil, nil) end)
    if not valid(path) then w("  " .. label .. ": sem path") return end
    local partial = safe(function() return path:IsPartial() end)
    local ok = safe(function() return path:IsValid() end)
    local pts = {}
    safe(function()
        path.PathPoints:ForEach(function(_, e)
            local v = e:get()
            pts[#pts + 1] = string.format("(%.0f,%.0f,%.0f)", v.X, v.Y, v.Z)
        end)
    end)
    w(string.format("  %s: valid=%s partial=%s pontos=%d", label, tostring(ok), tostring(partial), #pts))
    if #pts > 0 then w("    fim=" .. pts[#pts] .. "  " .. table.concat(pts, " ", 1, math.min(#pts, 12))) end
end
test("Notas do Mordomo 4 (atras de porta?)", 1625, 4016, 588)
test("Bordo de Koka", 1091, 2371, 586)
test("Pagina Proposta 2", 2352, 1563, 89)
test("Saco de Sardinhas", -434, 2041, 587)
test("Diario 10 (subsolo)", -2216, 6750, -707)

-- Portas e estado
for _, d in ipairs(FindAllOf("BaseDoor") or {}) do
    if valid(d) then
        local id = safe(function() return d.InteractActorID:ToString() end) or ""
        local l = d:K2_GetActorLocation()
        w(string.format("  porta %s id=%s locked=%s can=%s at=(%.0f,%.0f,%.0f) state=%s",
            d:GetClass():GetFName():ToString(), id, tostring(safe(function() return d.bIsLocked end)),
            tostring(safe(function() return d.bCanInteract end)), l.X, l.Y, l.Z,
            tostring(safe(function() return d:GetMechanicStateIndex() end))))
    end
end
