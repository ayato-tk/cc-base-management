local REPO = {
    owner  = "ayato-tk",
    repo   = "cc-base-management",
    branch = "main",
}

local ok, cfg = pcall(require, "update_config")
if not ok then cfg = {} end

local EXCLUDE = cfg.exclude or {
    "^%.gitignore$",
    "^secrets",
    "^README",
    "^%.vscode/",
}

local PROTECTED = cfg.protected or {
    "config.lua",
    "ranks.lua",
    "update_config.lua",
}

local args     = { ... }
local forceAll = false
for _, a in ipairs(args) do
    if a == "-a" then forceAll = true end
end

local function isExcluded(path)
    for _, pat in ipairs(EXCLUDE) do
        if string.match(path, pat) then return true end
    end
    return false
end

local function isProtected(path)
    for _, p in ipairs(PROTECTED) do
        if path == p then return true end
    end
    return false
end

local function listRepoFiles()
    local url = string.format(
        "https://api.github.com/repos/%s/%s/git/trees/%s?recursive=1",
        REPO.owner, REPO.repo, REPO.branch
    )
    write("Listando arquivos do repo... ")
    local resp, err = http.get(url, { ["User-Agent"] = "CC-Updater" })
    if not resp then print("FALHOU (" .. tostring(err) .. ")") return nil end
    if resp.getResponseCode() ~= 200 then
        print("FALHOU (HTTP " .. resp.getResponseCode() .. ")")
        resp.close()
        return nil
    end
    local body = resp.readAll()
    resp.close()

    local data = textutils.unserializeJSON(body)
    if not data or not data.tree then
        print("FALHOU (resposta invalida)")
        return nil
    end

    local files = {}
    for _, entry in ipairs(data.tree) do
        if entry.type == "blob" and not isExcluded(entry.path) then
            table.insert(files, entry.path)
        end
    end
    print("OK (" .. #files .. " arquivos)")
    return files
end

local function rawUrl(path)
    return string.format(
        "https://raw.githubusercontent.com/%s/%s/%s/%s",
        REPO.owner, REPO.repo, REPO.branch, path
    )
end

local function ensureDir(path)
    local dir = fs.getDir(path)
    if dir ~= "" and dir ~= "/" and not fs.exists(dir) then
        fs.makeDir(dir)
    end
end

local function download(path)
    write("Baixando " .. path .. " ... ")
    local resp, err = http.get(rawUrl(path))
    if not resp then print("FALHOU (" .. tostring(err) .. ")") return false end
    if resp.getResponseCode() ~= 200 then
        print("FALHOU (HTTP " .. resp.getResponseCode() .. ")")
        resp.close()
        return false
    end
    local content = resp.readAll()
    resp.close()

    ensureDir(path)
    local f, ferr = fs.open(path, "w")
    if not f then print("FALHOU (fs.open: " .. tostring(ferr) .. ")") return false end
    f.write(content)
    f.close()
    print("OK")
    return true
end

print("== Atualizando do GitHub ==")
print("Repo: " .. REPO.owner .. "/" .. REPO.repo .. " @ " .. REPO.branch)
if forceAll then
    print("Modo: completo (-a)")
else
    print("Modo: seguro (arquivos protegidos nao serao sobrescritos)")
end
print()

local files = listRepoFiles()
if not files then return end

local nok, fail, skipped = 0, 0, 0
for _, path in ipairs(files) do
    if not forceAll and isProtected(path) and fs.exists(path) then
        print("  " .. path .. " -> protegido, pulando")
        skipped = skipped + 1
    elseif download(path) then
        nok = nok + 1
    else
        fail = fail + 1
    end
end

print()
local summary = string.format("Concluido: %d ok, %d falhas", nok, fail)
if skipped > 0 then
    summary = summary .. string.format(", %d protegido(s) (use -a para sobrescrever)", skipped)
end
print(summary)
if fail == 0 then
    print("Use 'reboot' pra rodar o startup atualizado.")
end
