local REPO = {
    owner  = "ayato-tk",
    repo   = "cc-base-management",
    branch = "main",
}

local EXCLUDE = {
    "^%.gitignore$",
    "^secrets",
    "^README",
    ".vscode/"
}

local function isExcluded(path)
    for _, pat in ipairs(EXCLUDE) do
        if string.match(path, pat) then return true end
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
print()

local files = listRepoFiles()
if not files then return end

local ok, fail = 0, 0
for _, path in ipairs(files) do
    if download(path) then ok = ok + 1 else fail = fail + 1 end
end

print()
print(string.format("Concluido: %d ok, %d falhas", ok, fail))
if fail == 0 then
    print("Use 'reboot' pra rodar o startup atualizado.")
end
