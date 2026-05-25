local config  = require("config")
local util    = require("lib.util")
local display = require("lib.display")

local M = {}

local function snapshotItems(bridge)
    local items = util.safeCall(bridge, "listItems")
    if not items then return nil end
    local total = 0
    local byId = {}
    local names = {}
    for _, it in ipairs(items) do
        local n = it.amount or it.count or 0
        total = total + n
        byId[it.name] = (byId[it.name] or 0) + n
        if it.displayName then names[it.name] = it.displayName end
    end
    return { total = total, byId = byId, names = names, time = os.clock() }
end

local function rateColor(r)
    if not r or r == 0 then return config.colors.label end
    if r > 0 then return config.colors.good end
    return config.colors.bad
end

local function fmtRate(r)
    if not r then return "..." end
    local sign = r >= 0 and "+" or ""
    return sign .. util.formatNumber(r) .. "/s"
end

function M.new()
    local self = {
        bridge       = peripheral.find("me_bridge"),
        data         = nil,
        prevSnapshot = nil,
    }

    function self:read()
        if not self.bridge then self.data = nil; return end

        local snap = snapshotItems(self.bridge)
        local netTotal, netById = nil, {}

        if snap and self.prevSnapshot then
            local dt = snap.time - self.prevSnapshot.time
            if dt > 0 then
                netTotal = (snap.total - self.prevSnapshot.total) / dt
                for id, curr in pairs(snap.byId) do
                    local prev = self.prevSnapshot.byId[id] or 0
                    local r = (curr - prev) / dt
                    if r ~= 0 then netById[id] = r end
                end
                for id, prev in pairs(self.prevSnapshot.byId) do
                    if not snap.byId[id] then
                        netById[id] = -prev / dt
                    end
                end
            end
        end

        if snap then self.prevSnapshot = snap end

        self.data = {
            energyUsage = util.safeCall(self.bridge, "getEnergyUsage"),
            itemUsed    = util.safeCall(self.bridge, "getUsedItemStorage"),
            itemTotal   = util.safeCall(self.bridge, "getTotalItemStorage"),
            fluidUsed   = util.safeCall(self.bridge, "getUsedFluidStorage"),
            fluidTotal  = util.safeCall(self.bridge, "getTotalFluidStorage"),
            cpus        = util.safeCall(self.bridge, "getCraftingCPUs"),
            totalItems  = snap and snap.total,
            netTotal    = netTotal,
            netById     = netById,
            names       = snap and snap.names or {},
            byId        = snap and snap.byId or {},
        }
    end

    local function topItems(d, mode, limit)
        local list = {}
        if mode == "flow" then
            for id, rate in pairs(d.netById) do
                table.insert(list, {
                    id = id, rate = rate,
                    count = d.byId[id] or 0,
                    name = d.names[id] or id,
                })
            end
            table.sort(list, function(a, b)
                return math.abs(a.rate) > math.abs(b.rate)
            end)
        else
            for id, count in pairs(d.byId) do
                table.insert(list, {
                    id = id, count = count,
                    rate = d.netById[id] or 0,
                    name = d.names[id] or id,
                })
            end
            table.sort(list, function(a, b) return a.count > b.count end)
        end
        local result = {}
        for i = 1, math.min(limit, #list) do result[i] = list[i] end
        return result
    end
    self._topItems = topItems

    function self:render(ctx)
        display.writeSectionHeader(ctx.mon, ctx.x, ctx.y, "[Armazenamento - AE2]")
        ctx.y = ctx.y + 1
        if not self.data then
            display.writeMissing(ctx.mon, ctx.x, ctx.y, "ME Bridge nao detectado")
            ctx.y = ctx.y + 1
            return
        end

        local d = self.data

        if d.itemTotal then
            local p = util.pct(d.itemUsed, d.itemTotal)
            display.writeKV(ctx.mon, ctx.x, ctx.y, "Bytes:   ",
                util.formatNumber(d.itemUsed) .. " / " .. util.formatNumber(d.itemTotal)
                .. string.format("  (%.0f%%)", p * 100))
            ctx.y = ctx.y + 1
            display.drawBar(ctx.mon, ctx.x, ctx.y, ctx.w - 3, p, util.colorForPct(p))
            ctx.y = ctx.y + 1
        end

        if d.totalItems then
            display.writeKV(ctx.mon, ctx.x, ctx.y, "Itens:   ",
                util.formatNumber(d.totalItems))
            ctx.y = ctx.y + 1
            display.writeKV(ctx.mon, ctx.x, ctx.y, "Fluxo:   ",
                fmtRate(d.netTotal), rateColor(d.netTotal))
            ctx.y = ctx.y + 1
        end

        local available = ctx.h - ctx.y - 6
        local limit = math.min(config.itemListLimit or 10, math.max(0, available))
        if limit > 0 then
            local mode = config.itemListMode or "flow"
            local top = self._topItems(d, mode, limit)
            if #top > 0 then
                local headerText = mode == "flow"
                    and string.format("Top %d mais ativos:", #top)
                    or  string.format("Top %d estoques:",   #top)
                ctx.mon.setCursorPos(ctx.x, ctx.y)
                ctx.mon.setTextColor(config.colors.title)
                ctx.mon.write(headerText)
                ctx.y = ctx.y + 1
                for _, it in ipairs(top) do
                    local label = it.name
                    if #label > 18 then label = label:sub(1, 17) .. "." end
                    display.writeKV(ctx.mon, ctx.x, ctx.y,
                        string.format("  %-18s ", label),
                        string.format("%s  (%s)", fmtRate(it.rate), util.formatNumber(it.count)),
                        rateColor(it.rate))
                    ctx.y = ctx.y + 1
                end
            end
        end

        ctx.y = ctx.y + 1

        if d.fluidTotal then
            local p = util.pct(d.fluidUsed, d.fluidTotal)
            display.writeKV(ctx.mon, ctx.x, ctx.y, "Fluidos: ",
                util.formatNumber(d.fluidUsed) .. " / " .. util.formatNumber(d.fluidTotal)
                .. string.format("  (%.0f%%)", p * 100))
            ctx.y = ctx.y + 1
            display.drawBar(ctx.mon, ctx.x, ctx.y, ctx.w - 3, p, util.colorForPct(p))
            ctx.y = ctx.y + 2
        end
        if d.energyUsage then
            display.writeKV(ctx.mon, ctx.x, ctx.y, "Consumo ME: ",
                util.formatNumber(d.energyUsage) .. " AE/t")
            ctx.y = ctx.y + 1
        end
        if d.cpus then
            display.writeKV(ctx.mon, ctx.x, ctx.y, "CPUs craft: ", tostring(#d.cpus))
            ctx.y = ctx.y + 1
        end
    end

    return self
end

return M
