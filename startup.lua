local config    = require("config")
local mekanism  = require("lib.modules.mekanism")
local detector  = require("lib.modules.energy_detector")
local me_bridge = require("lib.modules.me_bridge")

local monitor = peripheral.find("monitor")
if not monitor then
    error("Nenhum monitor encontrado.")
end

local sources = {
    mekanism.new(),
    detector.new(),
    me_bridge.new(),
}

monitor.setTextScale(config.monitorTextScale)

while true do
    for _, s in ipairs(sources) do
        local ok, err = pcall(function() s:read() end)
        if not ok then print("Erro no read: " .. tostring(err)) end
    end

    monitor.setBackgroundColor(config.colors.bg)
    monitor.clear()
    local w, h = monitor.getSize()
    local ctx = { mon = monitor, x = 2, y = 1, w = w, h = h }

    for _, s in ipairs(sources) do
        local ok, err = pcall(function() s:render(ctx) end)
        if not ok then print("Erro no render: " .. tostring(err)) end
    end

    monitor.setCursorPos(2, h)
    monitor.setTextColor(config.colors.label)
    monitor.write("tick " .. os.clock())

    sleep(config.refreshInterval)
end
