-- PrimeUI subset bundled from MCJack123/PrimeUI
-- Source: https://github.com/MCJack123/PrimeUI
-- PrimeUI is CC0/public domain.

local expect = require "cc.expect".expect
local PrimeUI = {}
do
    local coros = {}
    local restoreCursor

    function PrimeUI.addTask(func)
        expect(1, func, "function")
        local t = {coro = coroutine.create(func)}
        coros[#coros+1] = t
        _, t.filter = coroutine.resume(t.coro)
    end

    function PrimeUI.resolve(...)
        coroutine.yield(coros, ...)
    end

    function PrimeUI.clear()
        term.setCursorPos(1, 1)
        term.setCursorBlink(false)
        term.setBackgroundColor(colors.black)
        term.setTextColor(colors.white)
        term.clear()
        coros = {}
        restoreCursor = nil
    end

    function PrimeUI.setCursorWindow(win)
        expect(1, win, "table", "nil")
        restoreCursor = win and win.restoreCursor
    end

    function PrimeUI.getWindowPos(win, x, y)
        if win == term then return x, y end
        while win ~= term.native() and win ~= term.current() do
            if not win.getPosition then return x, y end
            local wx, wy = win.getPosition()
            x, y = x + wx - 1, y + wy - 1
            _, win = debug.getupvalue(select(2, debug.getupvalue(win.isColor, 1)), 1)
        end
        return x, y
    end

    function PrimeUI.run()
        while true do
            if restoreCursor then restoreCursor() end
            local ev = table.pack(os.pullEvent())
            for _, v in ipairs(coros) do
                if v.filter == nil or v.filter == ev[1] then
                    local res = table.pack(coroutine.resume(v.coro, table.unpack(ev, 1, ev.n)))
                    if not res[1] then error(res[2], 2) end
                    if res[2] == coros then return table.unpack(res, 3, res.n) end
                    v.filter = res[2]
                end
            end
        end
    end
end

function PrimeUI.label(win, x, y, text, fgColor, bgColor)
    fgColor = fgColor or colors.white
    bgColor = bgColor or colors.black
    win.setCursorPos(x, y)
    win.setTextColor(fgColor)
    win.setBackgroundColor(bgColor)
    win.write(text)
end

function PrimeUI.button(win, x, y, text, action, fgColor, bgColor, clickedColor, periphName)
    fgColor = fgColor or colors.white
    bgColor = bgColor or colors.gray
    clickedColor = clickedColor or colors.lightGray
    win.setCursorPos(x, y)
    win.setBackgroundColor(bgColor)
    win.setTextColor(fgColor)
    win.write(" " .. text .. " ")

    PrimeUI.addTask(function()
        local screenX, screenY = PrimeUI.getWindowPos(win, x, y)
        local buttonDown = false
        while true do
            local event, button, clickX, clickY = os.pullEvent()
            if event == "mouse_click" and periphName == nil and button == 1
                and clickX >= screenX and clickX < screenX + #text + 2 and clickY == screenY then
                buttonDown = true
                win.setCursorPos(x, y)
                win.setBackgroundColor(clickedColor)
                win.setTextColor(fgColor)
                win.write(" " .. text .. " ")
            elseif (event == "monitor_touch" and periphName == button
                and clickX >= screenX and clickX < screenX + #text + 2 and clickY == screenY)
                or (event == "mouse_up" and button == 1 and buttonDown) then
                if clickX >= screenX and clickX < screenX + #text + 2 and clickY == screenY then
                    if type(action) == "string" then
                        PrimeUI.resolve("button", action)
                    else
                        action()
                    end
                end
                win.setCursorPos(x, y)
                win.setBackgroundColor(bgColor)
                win.setTextColor(fgColor)
                win.write(" " .. text .. " ")
            end
        end
    end)
end

function PrimeUI.clickRegion(win, x, y, width, height, action, periphName)
    PrimeUI.addTask(function()
        local screenX, screenY = PrimeUI.getWindowPos(win, x, y)
        while true do
            local event, button, clickX, clickY = os.pullEvent()
            if (event == "monitor_touch" and periphName == button)
                or (event == "mouse_click" and button == 1 and periphName == nil) then
                if clickX >= screenX and clickX < screenX + width
                    and clickY >= screenY and clickY < screenY + height then
                    if type(action) == "string" then
                        PrimeUI.resolve("clickRegion", action)
                    else
                        action()
                    end
                end
            end
        end
    end)
end

function PrimeUI.keyAction(key, action)
    PrimeUI.addTask(function()
        while true do
            local _, param1 = os.pullEvent("key")
            if param1 == key then
                if type(action) == "string" then PrimeUI.resolve("keyAction", action)
                else action() end
            end
        end
    end)
end

function PrimeUI.timeout(time, action)
    local timer = os.startTimer(time)
    PrimeUI.addTask(function()
        while true do
            local _, tm = os.pullEvent("timer")
            if tm == timer then
                if type(action) == "string" then PrimeUI.resolve("timeout", action)
                else action() end
            end
        end
    end)
    return function() os.cancelTimer(timer) end
end

return PrimeUI
