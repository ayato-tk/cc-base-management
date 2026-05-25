local config  = require("config")
local util    = require("lib.util")
local display = require("lib.display")

local M = {}

function M.new()
    local self = {
        bridge = peripheral.find("me_bridge"),
        data   = nil,
    }

    function self:read()
        if not self.bridge then
            self.data = nil
            return
        end
        self.data = {
            energyUsage = util.safeCall(self.bridge, "getEnergyUsage"),
            itemUsed    = util.safeCall(self.bridge, "getUsedItemStorage"),
            itemTotal   = util.safeCall(self.bridge, "getTotalItemStorage"),
            fluidUsed   = util.safeCall(self.bridge, "getUsedFluidStorage"),
            fluidTotal  = util.safeCall(self.bridge, "getTotalFluidStorage"),
            cpus        = util.safeCall(self.bridge, "getCraftingCPUs"),
        }
    end

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
            display.writeKV(ctx.mon, ctx.x, ctx.y, "Itens:   ",
                util.formatNumber(d.itemUsed) .. " / " .. util.formatNumber(d.itemTotal)
                .. string.format("  (%.0f%%)", p * 100))
            ctx.y = ctx.y + 1
            display.drawBar(ctx.mon, ctx.x, ctx.y, ctx.w - 3, p, util.colorForPct(p))
            ctx.y = ctx.y + 2
        end
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
