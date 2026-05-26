local config = require("config")
local ranks  = require("ranks")

local args         = { ... }
local DEFAULT_RANK = ranks._default or "stone"
local rankName     = args[1] or DEFAULT_RANK

local function listRanks()
    print("Ranks disponiveis:")
    for name in pairs(ranks) do
        if name:sub(1, 1) ~= "_" then
            print("  - " .. name)
        end
    end
end

if not ranks[rankName] or rankName:sub(1, 1) == "_" then
    print("Rank '" .. rankName .. "' nao existe.")
    listRanks()
    return
end

local function resolveRank(name, seen)
    seen = seen or {}
    if seen[name] then error("ciclo em ranks: " .. name) end
    seen[name] = true

    local rank = ranks[name]
    if not rank then error("rank '" .. name .. "' nao existe") end

    local items
    if rank.overwrite or not rank.parent then
        items = {}
    else
        items = resolveRank(rank.parent, seen)
    end

    for _, item in ipairs(rank.items or {}) do
        local replaced = false
        for i, existing in ipairs(items) do
            if existing.id == item.id then
                if item.remove then
                    table.remove(items, i)
                else
                    items[i] = item
                end
                replaced = true
                break
            end
        end
        if not replaced and not item.remove then
            table.insert(items, item)
        end
    end
    return items
end

local me = peripheral.find("me_bridge")
if not me then error("ME Bridge nao encontrado") end

local OUTPUT  = config.rankupOutput
local TIMEOUT = config.rankupTimeout or 300
local ITEMS   = resolveRank(rankName)

if not OUTPUT then error("config.rankupOutput nao configurado") end
if #ITEMS == 0 then error("rank '" .. rankName .. "' vazio") end

local function call(method, ...)
    local fn = me[method]
    if not fn then return nil, "metodo inexistente: " .. method end
    local ok, v = pcall(fn, ...)
    if ok then return v end
    return nil, v
end

local function getStock(id)
    local items = call("getItems") or {}
    for _, it in ipairs(items) do
        if it.name == id then return it.count or it.amount or 0 end
    end
    return 0
end

local function isCraftable(id)
    local items = call("getCraftableItems") or {}
    for _, it in ipairs(items) do
        if it.name == id then return true end
    end
    return false
end

print(string.format("== Rankup: %s (%d itens) ==", rankName, #ITEMS))
print("enter=default  numero=qtd  0/s=pular")
print()

local requests = {}
for _, item in ipairs(ITEMS) do
    while true do
        write(string.format("%-22s (%d): ", item.label, item.default))
        local input = read()
        if input == "" then
            table.insert(requests, { id = item.id, label = item.label, qty = item.default })
            break
        elseif input == "s" or input == "S" or input == "0" then
            break
        else
            local n = tonumber(input)
            if n and n > 0 then
                table.insert(requests, { id = item.id, label = item.label, qty = math.floor(n) })
                break
            else
                print("  invalido")
            end
        end
    end
end

if #requests == 0 then
    print()
    print("Nada solicitado.")
    return
end

print()
print("== Verificando estoques ==")
local failed  = {}
local pending = {}

for _, req in ipairs(requests) do
    local stock = getStock(req.id)
    if stock >= req.qty then
        print(string.format("  %-22s %d em estoque (ok)", req.label, stock))
        req.alreadyOk = true
    else
        local need = req.qty - stock
        if not isCraftable(req.id) then
            print(string.format("  %-22s %d/%d  SEM PADRAO",
                req.label, stock, req.qty))
            table.insert(failed, { req = req, reason = "sem padrao de craft" })
        else
            req.need = need
            table.insert(pending, req)
            print(string.format("  %-22s %d/%d  na fila (craftar %d)",
                req.label, stock, req.qty, need))
        end
    end
end

local function computeStuckLimit(reqs)
    local maxNeed = 0
    for _, r in ipairs(reqs) do
        if r.need and r.need > maxNeed then maxNeed = r.need end
    end
    return math.max(60, 30 + math.floor(maxNeed / 20))
end

if #pending > 0 then
    print()
    print(string.format("== Drenando %d craft(s) (retenta enquanto CPU/material faltar) ==",
        #pending))

    local STUCK_LIMIT = computeStuckLimit(requests)
    print(string.format("  (sem progresso por %ds = desiste; max %ds total)",
        STUCK_LIMIT, TIMEOUT))

    local start            = os.clock()
    local lastProgress     = os.clock()
    local prevTotalStock   = -1
    local prevPendingCount = -1
    local prevTaskCount    = -1

    while #pending > 0 and (os.clock() - start) < TIMEOUT do
        local items  = call("getItems") or {}
        local stocks = {}
        for _, it in ipairs(items) do
            stocks[it.name] = it.count or it.amount or 0
        end

        local newPending = {}
        local totalStock = 0
        local doneNow    = {}
        local schedNow   = {}
        for _, req in ipairs(pending) do
            local s = stocks[req.id] or 0
            totalStock = totalStock + s
            if s >= req.qty then
                req.crafting = true
                table.insert(doneNow, req.label)
            else
                req.need = req.qty - s
                local result = call("craftItem", { name = req.id, count = req.need })
                if result and not req.crafting then
                    table.insert(schedNow, req.label)
                end
                if result then req.crafting = true end
                table.insert(newPending, req)
            end
        end
        pending = newPending

        for _, lbl in ipairs(doneNow)  do print("  " .. lbl .. " -> pronto") end
        for _, lbl in ipairs(schedNow) do print("  " .. lbl .. " -> agendado") end

        local tasks      = call("getCraftingTasks") or {}
        local taskCount  = #tasks
        local progressed = (totalStock > prevTotalStock)
                        or (#pending  < prevPendingCount)
                        or (taskCount ~= prevTaskCount)
        if progressed then lastProgress = os.clock() end

        prevTotalStock   = totalStock
        prevPendingCount = #pending
        prevTaskCount    = taskCount

        if #pending == 0 then break end

        if (os.clock() - lastProgress) > STUCK_LIMIT then
            print(string.format("  Sem progresso ha %ds, desistindo de %d item(ns)",
                STUCK_LIMIT, #pending))
            for _, req in ipairs(pending) do
                table.insert(failed, { req = req,
                    reason = "sem progresso (CPU/materiais)" })
            end
            pending = {}
            break
        end

        local elapsed = math.floor(os.clock() - start)
        print(string.format("  ... %d aguardando, %d task(s) rodando, %ds",
            #pending, taskCount, elapsed))
        sleep(5)
    end

    if #pending > 0 then
        print("  TIMEOUT geral atingido")
        for _, req in ipairs(pending) do
            table.insert(failed, { req = req, reason = "timeout" })
        end
    end
end

print()
print("== Exportando para " .. OUTPUT .. " ==")
for _, req in ipairs(requests) do
    local isFailed = false
    for _, f in ipairs(failed) do
        if f.req == req then isFailed = true break end
    end
    if not isFailed then
        local remaining     = req.qty
        local stuckLimit    = math.max(60, 30 + math.floor(remaining / 20))
        local prevStock     = -1
        local lastStockGrow = os.clock()
        local lastChestWarn = -math.huge
        local craftLogged   = false

        print(string.format("  %-22s exportar %d", req.label, req.qty))

        while remaining > 0 do
            local exported, err = call("exportItem",
                { name = req.id, count = remaining }, OUTPUT)

            if exported == nil then
                print(string.format("    ERRO (%s)", tostring(err)))
                table.insert(failed, { req = req,
                    reason = "export: " .. tostring(err) })
                break
            end

            if exported > 0 then
                remaining     = remaining - exported
                lastChestWarn = -math.huge
                if remaining == 0 then
                    print(string.format("    -> ok (%d total)", req.qty))
                    break
                end
            end

            local stock = getStock(req.id)
            if stock > prevStock then lastStockGrow = os.clock() end
            prevStock = stock

            if stock <= 0 then
                if not craftLogged then
                    print(string.format("    faltam %d em estoque, craftando extras...",
                        remaining))
                    craftLogged = true
                end
                call("craftItem", { name = req.id, count = remaining })

                if (os.clock() - lastStockGrow) > stuckLimit then
                    print(string.format("    craft extra travou (%ds), abandonando %d",
                        stuckLimit, remaining))
                    table.insert(failed, { req = req,
                        reason = string.format("craft extra travou, faltam %d", remaining) })
                    break
                end
                sleep(3)
            else
                local now = os.clock()
                if (now - lastChestWarn) > 60 then
                    print(string.format("    bau cheio (faltam %d, estoque %d), aguardando espaco...",
                        remaining, stock))
                    lastChestWarn = now
                end
                sleep(5)
            end
        end
    end
end

print()
print("========== RESUMO ==========")
if #failed == 0 then
    print("Done!")
else
    print("Falhas:")
    for _, f in ipairs(failed) do
        print("  - " .. f.req.label .. ": " .. f.reason)
    end
end
