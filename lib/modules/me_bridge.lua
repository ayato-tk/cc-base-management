local config  = require("config")
local util    = require("lib.util")
local display = require("lib.display")

local M = {}

local function snapshotItems(bridge)
    local items = util.safeCall(bridge, "getItems")
                or util.safeCall(bridge, "listItems")
                or util.safeCall(bridge, "listItem")
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

local function rateColor(d)
    if not d or d == 0 then return config.colors.label end
    if d > 0 then return config.colors.good end
    return config.colors.bad
end

local function fmtDelta(d)
    if not d then return "..." end
    local sign = d >= 0 and "+" or ""
    return sign .. util.formatNumber(d)
end

local function fmtDuration(s)
    if not s or s <= 0 then return "..." end
    s = math.floor(s)
    if s < 60 then return s .. "s" end
    if s < 3600 then return math.floor(s / 60) .. "min" end
    return string.format("%.1fh", s / 3600)
end

function M.new()
    local self = {
        bridge    = peripheral.find("me_bridge"),
        data      = nil,
        snapshots = {},
    }

    function self:read()
        if not self.bridge then self.data = nil; return end

        local window = config.itemListWindow or 600
        local refresh = config.refreshInterval or 1
        local sampleInterval = math.max(refresh, window / 30)
        local now = os.clock()

        local needSample = (#self.snapshots == 0)
            or (now - self.snapshots[#self.snapshots].time) >= sampleInterval

        if needSample then
            local snap = snapshotItems(self.bridge)
            if snap then
                table.insert(self.snapshots, snap)
                while #self.snapshots > 1
                    and (snap.time - self.snapshots[1].time) > window do
                    table.remove(self.snapshots, 1)
                end
            end
        end

        local current = self.snapshots[#self.snapshots]
        local netTotal, netById, effectiveWindow = nil, {}, 0

        if current and #self.snapshots >= 2 then
            local oldest = self.snapshots[1]
            effectiveWindow = current.time - oldest.time
            if effectiveWindow > 0 then
                netTotal = current.total - oldest.total
                for id, curr in pairs(current.byId) do
                    local prev = oldest.byId[id] or 0
                    local d = curr - prev
                    if d ~= 0 then netById[id] = d end
                end
                for id, prev in pairs(oldest.byId) do
                    if not current.byId[id] then
                        netById[id] = -prev
                    end
                end
            end
        end

        self.data = {
            energyUsage     = util.safeCall(self.bridge, "getEnergyUsage"),
            itemUsed        = util.safeCall(self.bridge, "getUsedItemStorage"),
            itemTotal       = util.safeCall(self.bridge, "getTotalItemStorage"),
            fluidUsed       = util.safeCall(self.bridge, "getUsedFluidStorage"),
            fluidTotal      = util.safeCall(self.bridge, "getTotalFluidStorage"),
            cpus            = util.safeCall(self.bridge, "getCraftingCPUs"),
            totalItems      = current and current.total,
            byId            = current and current.byId or {},
            names           = current and current.names or {},
            netTotal        = netTotal,
            netById         = netById,
            effectiveWindow = effectiveWindow,
        }
    end

    local function topItems(d, mode, limit)
        local list = {}
        for id, count in pairs(d.byId) do
            table.insert(list, {
                id    = id,
                count = count,
                delta = d.netById[id] or 0,
                name  = d.names[id] or id,
            })
        end
        if mode == "flow" then
            table.sort(list, function(a, b)
                local da, db = math.abs(a.delta), math.abs(b.delta)
                if da ~= db then return da > db end
                return a.count > b.count
            end)
        else
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
            if d.effectiveWindow > 0 then
                display.writeKV(ctx.mon, ctx.x, ctx.y, "Fluxo:   ",
                    fmtDelta(d.netTotal) .. " (" .. fmtDuration(d.effectiveWindow) .. ")",
                    rateColor(d.netTotal))
            else
                display.writeKV(ctx.mon, ctx.x, ctx.y, "Fluxo:   ",
                    "calculando...", config.colors.label)
            end
            ctx.y = ctx.y + 1
        end

        local reserve = 1
        if d.fluidTotal then reserve = reserve + 3 end
        if d.energyUsage then reserve = reserve + 1 end
        if d.cpus       then reserve = reserve + 1 end
        local available = ctx.h - ctx.y - reserve - 1
        local limit = math.min(config.itemListLimit or 5, math.max(0, available))

        if limit > 0 then
            local mode = config.itemListMode or "flow"
            local top = self._topItems(d, mode, limit)
            local headerText
            if mode == "flow" then
                if d.effectiveWindow > 0 then
                    headerText = string.format("Top %d (ultimos %s):",
                        #top, fmtDuration(d.effectiveWindow))
                else
                    headerText = string.format("Top %d (calculando...):", #top)
                end
            else
                headerText = string.format("Top %d estoques:", #top)
            end
            ctx.mon.setCursorPos(ctx.x, ctx.y)
            ctx.mon.setTextColor(config.colors.title)
            ctx.mon.write(headerText)
            ctx.y = ctx.y + 1
            if #top == 0 then
                ctx.mon.setCursorPos(ctx.x, ctx.y)
                ctx.mon.setTextColor(config.colors.label)
                ctx.mon.write("  (sem itens no ME)")
                ctx.y = ctx.y + 1
            else
                for _, it in ipairs(top) do
                    local label = it.name
                    if #label > 18 then label = label:sub(1, 17) .. "." end
                    display.writeKV(ctx.mon, ctx.x, ctx.y,
                        string.format("  %-18s ", label),
                        string.format("%s  (%s)", fmtDelta(it.delta), util.formatNumber(it.count)),
                        rateColor(it.delta))
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
