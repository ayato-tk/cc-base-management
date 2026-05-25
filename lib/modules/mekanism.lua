local config  = require("config")
local util    = require("lib.util")
local display = require("lib.display")

local M = {}

local function detect()
    local list = {}
    for _, name in ipairs(peripheral.getNames()) do
        local p = peripheral.wrap(name)
        if p and p.getEnergy and p.getMaxEnergy then
            table.insert(list, { name = name, p = p })
        end
    end
    return list
end

local function labelFor(name)
    return config.cubeLabels[name] or name
end

function M.new()
    local self = {
        cubes        = detect(),
        prevReadings = {},
        data         = {},
    }

    function self:read()
        local results = {}
        local now = os.clock()
        for _, c in ipairs(self.cubes) do
            local energy  = util.safeCall(c.p, "getEnergy")
            local maxE    = util.safeCall(c.p, "getMaxEnergy")
            local lastIn  = util.safeCall(c.p, "getLastInput")
            local lastOut = util.safeCall(c.p, "getLastOutput")

            local netRate = nil
            if not lastIn and not lastOut and energy then
                local prev = self.prevReadings[c.name]
                if prev then
                    local dt = now - prev.time
                    if dt > 0 then
                        netRate = util.fromJoules((energy - prev.energy) / dt / 20)
                    end
                end
                self.prevReadings[c.name] = { energy = energy, time = now }
            end

            table.insert(results, {
                label   = labelFor(c.name),
                energy  = util.fromJoules(energy),
                maxE    = util.fromJoules(maxE),
                input   = util.fromJoules(lastIn),
                output  = util.fromJoules(lastOut),
                netRate = netRate,
            })
        end
        self.data = results
    end

    function self:render(ctx)
        local u = util.unitLabel()
        display.writeSectionHeader(ctx.mon, ctx.x, ctx.y, "[Energia]")
        ctx.y = ctx.y + 1

        if #self.data == 0 then
            display.writeMissing(ctx.mon, ctx.x, ctx.y, "Nenhum Energy Cube/Matrix detectado")
            ctx.y = ctx.y + 2
            return
        end

        for _, c in ipairs(self.data) do
            display.writeKV(ctx.mon, ctx.x, ctx.y, c.label, "")
            ctx.y = ctx.y + 1

            if c.energy and c.maxE then
                local p = util.pct(c.energy, c.maxE)
                display.writeKV(ctx.mon, ctx.x, ctx.y, "  Estoque: ",
                    util.formatNumber(c.energy) .. " / " .. util.formatNumber(c.maxE) .. " " .. u
                    .. string.format("  (%.0f%%)", p * 100))
                ctx.y = ctx.y + 1
                display.drawBar(ctx.mon, ctx.x, ctx.y, ctx.w - 3, p, util.colorForPct(p))
                ctx.y = ctx.y + 1
            end
            if c.input then
                display.writeKV(ctx.mon, ctx.x, ctx.y, "  Entrada: ",
                    util.formatNumber(c.input) .. " " .. u .. "/t", config.colors.good)
                ctx.y = ctx.y + 1
            end
            if c.output then
                display.writeKV(ctx.mon, ctx.x, ctx.y, "  Saida:   ",
                    util.formatNumber(c.output) .. " " .. u .. "/t", config.colors.warn)
                ctx.y = ctx.y + 1
            end
            if c.netRate ~= nil then
                local color = c.netRate > 0 and config.colors.good
                    or (c.netRate < 0 and config.colors.bad)
                    or config.colors.label
                local sign = c.netRate >= 0 and "+" or ""
                display.writeKV(ctx.mon, ctx.x, ctx.y, "  Saldo/t: ",
                    sign .. util.formatNumber(c.netRate) .. " " .. u .. "/t", color)
                ctx.y = ctx.y + 1
            end
            ctx.y = ctx.y + 1
        end
    end

    return self
end

return M
