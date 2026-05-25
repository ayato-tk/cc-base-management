local config = require("config")

local M = {}

function M.formatNumber(n)
    if not n then return "n/a" end
    local abs = math.abs(n)
    if abs >= 1e12 then return string.format("%.2fT", n / 1e12) end
    if abs >= 1e9  then return string.format("%.2fG", n / 1e9)  end
    if abs >= 1e6  then return string.format("%.2fM", n / 1e6)  end
    if abs >= 1e3  then return string.format("%.2fk", n / 1e3)  end
    return tostring(math.floor(n))
end

function M.pct(used, total)
    if not total or total == 0 then return 0 end
    return math.min(1, math.max(0, used / total))
end

function M.colorForPct(p)
    if p >= 0.90 then return config.colors.bad  end
    if p >= 0.70 then return config.colors.warn end
    return config.colors.good
end

function M.safeCall(obj, method, ...)
    if not obj or not obj[method] then return nil end
    local ok, v = pcall(obj[method], ...)
    if ok then return v end
    return nil
end

function M.fromJoules(j)
    if not j then return nil end
    if config.energyUnit == "FE" then return j * 0.4 end
    return j
end

function M.unitLabel()
    return config.energyUnit
end

return M
