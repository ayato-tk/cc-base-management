local config = require("config")

local me = peripheral.find("me_bridge")
if not me then error("ME Bridge nao encontrado") end

local OUTPUT  = config.rankupOutput
local TIMEOUT = config.rankupTimeout or 300
local ITEMS   = config.rankupItems or {}

if not OUTPUT then error("config.rankupOutput nao configurado") end
if #ITEMS == 0 then error("config.rankupItems vazio") end

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

print("== Rankup ==")
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
print("== Verificando estoques e agendando crafts ==")
local failed = {}

for _, req in ipairs(requests) do
    local stock = getStock(req.id)
    if stock >= req.qty then
        print(string.format("  %-22s %d em estoque (ok)", req.label, stock))
        req.alreadyOk = true
    else
        local need = req.qty - stock
        write(string.format("  %-22s %d/%d, craftando %d... ",
            req.label, stock, req.qty, need))
        if not isCraftable(req.id) then
            print("SEM PADRAO")
            table.insert(failed, { req = req, reason = "sem padrao de craft" })
        else
            local ok, err = call("craftItem", { name = req.id, count = need })
            if ok then
                print("agendado")
                req.crafting = true
            else
                print("FALHOU")
                table.insert(failed, { req = req, reason = "craftItem: " .. tostring(err) })
            end
        end
    end
end

local anyCrafting = false
for _, r in ipairs(requests) do if r.crafting then anyCrafting = true break end end

if anyCrafting then
    print()
    print("== Aguardando crafts (timeout " .. TIMEOUT .. "s) ==")
    local start = os.clock()
    while os.clock() - start < TIMEOUT do
        local tasks = call("getCraftingTasks") or {}
        local elapsed = math.floor(os.clock() - start)
        print(string.format("  %d tarefa(s) ativa(s), %ds passados", #tasks, elapsed))
        if #tasks == 0 then break end
        sleep(3)
    end
    if os.clock() - start >= TIMEOUT then
        print("  TIMEOUT atingido, seguindo mesmo assim")
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
        write(string.format("  %-22s %d... ", req.label, req.qty))
        local exported, err = call("exportItem",
            { name = req.id, count = req.qty }, OUTPUT)
        if not exported then
            print("ERRO (" .. tostring(err) .. ")")
            table.insert(failed, { req = req, reason = "export: " .. tostring(err) })
        elseif type(exported) == "number" and exported < req.qty then
            print(string.format("PARCIAL %d/%d", exported, req.qty))
            table.insert(failed, { req = req,
                reason = string.format("so saiu %d/%d", exported, req.qty) })
        else
            print("ok")
        end
    end
end

print()
print("========== RESUMO ==========")
if #failed == 0 then
    print("Tudo OK!")
else
    print("Falhas:")
    for _, f in ipairs(failed) do
        print("  - " .. f.req.label .. ": " .. f.reason)
    end
end
