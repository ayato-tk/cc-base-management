local config = require("config")

local M = {}

function M.drawBar(mon, x, y, width, p, color)
    mon.setBackgroundColor(config.colors.barBg)
    mon.setCursorPos(x, y)
    mon.write(string.rep(" ", width))
    local filled = math.floor(width * p + 0.5)
    if filled > 0 then
        mon.setBackgroundColor(color)
        mon.setCursorPos(x, y)
        mon.write(string.rep(" ", filled))
    end
    mon.setBackgroundColor(config.colors.bg)
end

function M.writeKV(mon, x, y, label, value, valueColor)
    mon.setCursorPos(x, y)
    mon.setTextColor(config.colors.label)
    mon.write(label)
    mon.setTextColor(valueColor or config.colors.value)
    mon.write(value)
end

function M.writeSectionHeader(mon, x, y, title)
    mon.setCursorPos(x, y)
    mon.setTextColor(config.colors.title)
    mon.write(title)
end

function M.writeMissing(mon, x, y, text)
    mon.setCursorPos(x, y)
    mon.setTextColor(config.colors.bad)
    mon.write(text)
end

return M
