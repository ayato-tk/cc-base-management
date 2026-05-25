local config  = require("config")
local util    = require("lib.util")
local display = require("lib.display")

local M = {}

local function detect()
    local list = {}
    for _, name in ipairs(peripheral.getNames()) do
        if peripheral.hasType(name, "energy_detector") then
            table.insert(list, { name = name, p = peripheral.wrap(name) })
        end
    end
    return list
end

local function labelFor(name)
    return config.detectorLabels[name] or name
end

function M.new()
    local self = {
        detectors = detect(),
        data      = {},
    }

    function self:read()
        local results = {}
        for _, ed in ipairs(self.detectors) do
            table.insert(results, {
                label = labelFor(ed.name),
                rate  = util.safeCall(ed.p, "getTransferRate"),
                limit = util.safeCall(ed.p, "getTransferRateLimit"),
            })
        end
        self.data = results
    end

    function self:render(ctx)
        if #self.data == 0 then return end
        display.writeSectionHeader(ctx.mon, ctx.x, ctx.y, "[Detectores de Fluxo]")
        ctx.y = ctx.y + 1
        for _, d in ipairs(self.data) do
            local rate = d.rate or 0
            local color = rate > 0 and config.colors.good
                or (rate < 0 and config.colors.bad)
                or config.colors.label
            display.writeKV(ctx.mon, ctx.x, ctx.y, d.label .. ": ",
                util.formatNumber(rate) .. " FE/t", color)
            ctx.y = ctx.y + 1
        end
        ctx.y = ctx.y + 1
    end

    return self
end

return M
