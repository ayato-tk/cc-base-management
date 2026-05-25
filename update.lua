local FILES = {
    "startup.lua",
    "update.lua",
    "config.lua",
    "lib/util.lua",
    "lib/display.lua",
    "lib/modules/mekanism.lua",
    "lib/modules/energy_detector.lua",
    "lib/modules/me_bridge.lua",
}

if not fs.exists("secrets.lua") then
    print("ERRO: secrets.lua nao encontrado.")
    print("Crie o arquivo com 'edit secrets' e use o template do repo.")
    return
end
local secrets = dofile("secrets.lua")

local function rawUrl(path)
    return string.format(
        "https://raw.githubusercontent.com/%s/%s/%s/%s",
        secrets.owner, secrets.repo, secrets.branch, path
    )
end

local function ensureDir(path)
    local dir = fs.getDir(path)
    if dir ~= "" and dir ~= "/" and not fs.exists(dir) then
        fs.makeDir(dir)
    end
end

local function download(path)
    local url = rawUrl(path)
    local headers = {
        ["Authorization"] = "token " .. secrets.token,
        ["User-Agent"]    = "CC-Updater",
        ["Accept"]        = "application/vnd.github.raw",
    }
    write("Baixando " .. path .. " ... ")
    local resp, err = http.get(url, headers)
    if not resp then
        print("FALHOU (" .. tostring(err) .. ")")
        return false
    end
    local code = resp.getResponseCode()
    if code ~= 200 then
        print("FALHOU (HTTP " .. code .. ")")
        resp.close()
        return false
    end
    local content = resp.readAll()
    resp.close()

    ensureDir(path)
    local f, ferr = fs.open(path, "w")
    if not f then
        print("FALHOU (fs.open: " .. tostring(ferr) .. ")")
        return false
    end
    f.write(content)
    f.close()
    print("OK")
    return true
end

print("== Atualizando do GitHub ==")
print("Repo: " .. secrets.owner .. "/" .. secrets.repo .. " @ " .. secrets.branch)
print()

local ok = 0
local fail = 0
for _, path in ipairs(FILES) do
    if download(path) then ok = ok + 1 else fail = fail + 1 end
end

print()
print(string.format("Concluido: %d ok, %d falhas", ok, fail))
if fail == 0 then
    print("Use 'reboot' pra rodar o startup atualizado.")
end
