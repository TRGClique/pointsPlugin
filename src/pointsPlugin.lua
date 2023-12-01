---
--- Generated by EmmyLua(https://github.com/EmmyLua)
--- Created by James.
--- DateTime: 17/10/2023 23:04
---

local config = ac.configValues({
    enableLeaderboard = true
})

ac.debug("enableLeaderboard", config.enableLeaderboard)

-- Event configuration:
local requiredSpeed = 80

-- This function is called before event activates. Once it returns true, it’ll run:
function script.prepare(dt)
    ac.debug("speed", ac.getCarState(1).speedKmh)
    return ac.getCarState(1).speedKmh > 60
end

-- Event state:
local uiVisible = true
local xLvl = 0
local yLvl = 0
local scale = 200
local screenWidth = ac.getSim().windowWidth
local screenHeight = ac.getSim().windowHeight
local timePassed = 0
local totalScore = 0
local comboMeter = 1
local comboColor = 0
local highestScore = 0
local dangerouslySlowTimer = 0
local carsState = {}
local wheelsWarningTimeout = 0
local ownSessionId = ac.getCar(0).sessionID
local leaderboardUrl = "http://" .. ac.getServerIP() .. ":" .. ac.getServerPortHTTP() .. "/overtake?leaderboard=SRP"

function GetLeaderboard(callback)
    web.get(leaderboardUrl, function (err, response)
        callback(stringify.parse(response.body))
    end)
end

function GetOwnRanking(callback)
    web.get(leaderboardUrl .. "/" .. ac.getUserSteamID(), function (err, response)
        callback(stringify.parse(response.body))
    end)
end

function GetDriverNameBySessionId(sessionId)
    local count = ac.getSim().carsCount
    for i = 0, count do
        local car = ac.getCar(i)
        if car.sessionID == sessionId then
            return ac.getDriverName(car.index)
        end
    end
end

local raceStatusEvent = ac.OnlineEvent({
    eventType = ac.StructItem.byte(),
    eventData = ac.StructItem.int32(),
}, function (sender, data)
    -- only accept packets from server
    if sender ~= nil then
        return
    end

    ac.debug("eventType", data.eventType)
    ac.debug("eventData", data.eventData)

    if data.eventType == EventType.RaceChallenge then
        rivalHealth = 1.0
        rivalRate = 0
        ownHealth = 1.0
        rivalRate = 0

        rivalId = data.eventData
        rivalName = GetDriverNameBySessionId(data.eventData)
        ac.debug("rivalName", rivalName)
    end

    if data.eventType == EventType.RaceCountdown then
        raceStartTime = data.eventData
    end

    if data.eventType == EventType.RaceEnded then
        lastWinner = data.eventData
        raceEndTime = GetSessionTime()
    end

    lastEvent = data.eventType
end)

local raceUpdateEvent = ac.OnlineEvent({
    ownHealth = ac.StructItem.float(),
    ownRate = ac.StructItem.float(),
    rivalHealth = ac.StructItem.float(),
    rivalRate = ac.StructItem.float()
}, function (sender, data)
    -- only accept packets from server
    if sender ~= nil then
        return
    end

    ac.debug("sender", sender)

    ownHealth = data.ownHealth
    ownRate = data.ownRate
    rivalHealth = data.rivalHealth
    rivalRate = data.rivalRate

    ac.debug("ownHealth", ownHealth)
    ac.debug("ownRate", ownRate)
    ac.debug("rivalHealth", rivalHealth)
    ac.debug("rivalRate", rivalRate)
end)



function GetSessionTime()
    return ac.getSim().timeToSessionStart * -1
end

-- sending a new message:
--raceUpdateEvent{ ownHealth = 0.6, ownRate = -0.2, rivalHealth = 0.3, rivalRate = -0.5 }
--raceStatusEvent{ eventType = 1, eventData = 2 }

local lastUiUpdate = GetSessionTime()
function script.drawUI()

    ac.debug("lastEvent", lastEvent)
    ac.debug("rivalId", rivalId)

    local currentTime = GetSessionTime()
    local dt = currentTime - lastUiUpdate
    lastUiUpdate = currentTime
    local raceTimeElapsed = currentTime - raceStartTime

    ac.debug("raceTimeElapsed", raceTimeElapsed)
    ac.debug("dt", dt)

    if lastEvent == EventType.RaceCountdown then
        if raceTimeElapsed > -3000 and raceTimeElapsed < 0 then
            DrawHealthHud(0)
            local text = math.ceil(raceTimeElapsed / 1000 * -1)
            DrawTextCentered(text)
        elseif raceTimeElapsed > 0 then
            if raceTimeElapsed < 1000 then
                DrawTextCentered("Go!")
            end

            ownHealth = ownHealth + ownRate * (dt / 1000)
            rivalHealth = rivalHealth + rivalRate * (dt / 1000)

            DrawHealthHud(raceTimeElapsed)
        end
    end

    if lastEvent == EventType.RaceEnded and raceEndTime > currentTime - 3000 then
        DrawHealthHud(raceEndTime - raceStartTime)

        if lastWinner == 255 then
            DrawTextCentered("Race cancelled")
        elseif lastWinner == ownSessionId then
            DrawTextCentered("You won the race!")
        else
            DrawTextCentered("You lost the race.")
        end
    end
end


function DrawTextCentered(text)
    local uiState = ac.getUI()

    ui.transparentWindow('raceText', vec2(uiState.windowSize.x / 2 - 250, uiState.windowSize.y / 2 - 250), vec2(500,100), function ()
        ui.pushFont(ui.Font.Huge)

        local size = ui.measureText(text)
        ui.setCursorX(ui.getCursorX() + ui.availableSpaceX() / 2 - (size.x / 2))
        ui.text(text)

        ui.popFont()
    end)
end

local barColor = rgbm(1,1,1,1)
function HealthBar(size, progress, direction)
    progress = math.clamp(progress, 0, 1)

    barColor:setLerp(rgbm.colors.red, rgbm.colors.white, progress)
    ui.drawRect(ui.getCursor(), ui.getCursor() + size, barColor)

    local p1, p2
    if direction == -1 then
        p1 = ui.getCursor() + vec2(size.x * (1 - progress), 0)
        p2 = ui.getCursor() + size
    else
        p1 = ui.getCursor()
        p2 = ui.getCursor() + vec2(size.x * progress, size.y)
    end

    ui.drawRectFilled(p1, p2, barColor)

    ui.dummy(size)
end

function DrawHealthHud(time)
    local uiState = ac.getUI()

    ui.toolWindow('raceChallengeHUD', vec2(uiState.windowSize.x / 2 - 500, 25), vec2(1000, 120), function ()
        ui.pushFont(ui.Font.Title)

        ui.columns(3)
        ui.text("PLAYER")
        ui.nextColumn()

        local laptime = ac.lapTimeToString(time)
        local size = ui.measureText(laptime)

        ui.setCursorX(ui.getCursorX() + ui.availableSpaceX() / 2 - (size.x / 2))
        ui.text(laptime)
        ui.nextColumn()
        ui.textAligned("RIVAL", ui.Alignment.End, vec2(-1,0))

        ui.columns(2)
        HealthBar(vec2(ui.availableSpaceX(), 30), ownHealth, -1)
        ui.textAligned(ac.getDriverName(0), ui.Alignment.Start, vec2(-1,0))
        ui.nextColumn()
        HealthBar(vec2(ui.availableSpaceX(), 30), rivalHealth, 1)
        ui.textAligned(rivalName, ui.Alignment.End, vec2(-1,0))

        ui.popFont()
    end)
end


local image_0 = {
    ['src'] = 'https://i.imgur.com/QttPuh0.png',
    ['sizeX'] = 743, --size of your image in pixels
    ['sizeY'] = 744, --size of your image in pixels
    ['paddingX'] = screenWidth/2-744/2, --this makes it sit in the centre
    ['paddingY'] = -50 --this moves it up 50 pixels
}

function script.update(dt)
    if timePassed == 0 then
        addMessage("Let’s go!", 0)
    end

    local player = ac.getCarState(1)
    if player.engineLifeLeft < 1 then
        if totalScore > score then
            score = math.floor(totalScore)
            ac.sendChatMessage("scored " .. totalScore .. " points.")
        end
        totalScore = 0
        comboMeter = 1
        return
    end

    timePassed = timePassed + dt

    local comboFadingRate = 0.5 * math.lerp(1, 0.1, math.lerpInvSat(player.speedKmh, 80, 200)) + player.wheelsOutside
    comboMeter = math.max(1, comboMeter - dt * comboFadingRate)

    local sim = ac.getSimState()
    while sim.carsCount > #carsState do
        carsState[#carsState + 1] = {}
    end

    if wheelsWarningTimeout > 0 then
        wheelsWarningTimeout = wheelsWarningTimeout - dt
    elseif player.wheelsOutside > 0 then
        if wheelsWarningTimeout == 0 then
        end
        addMessage("Car is outside", -1)
        wheelsWarningTimeout = 60
    end

    if player.speedKmh < requiredSpeed then
        if dangerouslySlowTimer > 3 then
            if totalScore > score then
                score = math.floor(totalScore)
                ac.sendChatMessage("scored " .. totalScore .. " points.")
            end
            totalScore = 0
            comboMeter = 1
        else
            if dangerouslySlowTimer == 0 then
                addMessage("Too slow!", -1)
            end
        end
        dangerouslySlowTimer = dangerouslySlowTimer + dt
        comboMeter = 1
        return
    else
        dangerouslySlowTimer = 0
    end

    for i = 1, ac.getSimState().carsCount do
        local car = ac.getCarState(i)
        local state = carsState[i]

        if car.pos:closerToThan(player.pos, 10) then
            local drivingAlong = math.dot(car.look, player.look) > 0.2
            if not drivingAlong then
                state.drivingAlong = false

                if not state.nearMiss and car.pos:closerToThan(player.pos, 3) then
                    state.nearMiss = true

                    if car.pos:closerToThan(player.pos, 2.5) then
                        comboMeter = comboMeter + 3
                        addMessage("Very close near miss!", 1)
                    else
                        comboMeter = comboMeter + 1
                        addMessage("Near miss: bonus combo", 0)
                    end
                end
            end

            if car.collidedWith == 0 then
                addMessage("Collision", -1)
                state.collided = true

                if totalScore > score then
                    score = math.floor(totalScore)
                    ac.sendChatMessage("scored " .. totalScore .. " points.")
                end
                totalScore = 0
                comboMeter = 1
            end

            if not state.overtaken and not state.collided and state.drivingAlong then
                local posDir = (car.pos - player.pos):normalize()
                local posDot = math.dot(posDir, car.look)
                state.maxPosDot = math.max(state.maxPosDot, posDot)
                if posDot < -0.5 and state.maxPosDot > 0.5 then
                    totalScore = totalScore + math.ceil(10 * comboMeter)
                    comboMeter = comboMeter + 1
                    comboColor = comboColor + 90
                    addMessage("Overtake", comboMeter > 20 and 1 or 0)
                    state.overtaken = true
                end
            end
        else
            state.maxPosDot = -1
            state.overtaken = false
            state.collided = false
            state.drivingAlong = true
            state.nearMiss = false
        end
    end



end

-- For various reasons, this is the most questionable part, some UI. I don’t really like
-- this way though. So, yeah, still thinking about the best way to do it.
local messages = {}
local glitter = {}
local glitterCount = 0

function addMessage(text, mood)
    for i = math.min(#messages + 1, 4), 2, -1 do
        messages[i] = messages[i - 1]
        messages[i].targetPos = i
    end
    messages[1] = {text = text, age = 0, targetPos = 1, currentPos = 1, mood = mood}
    if mood == 1 then
        for i = 1, 60 do
            local dir = vec2(math.random() - 0.5, math.random() - 0.5)
            glitterCount = glitterCount + 1
            glitter[glitterCount] = {
                color = rgbm.new(hsv(math.random() * 360, 1, 1):rgb(), 1),
                pos = vec2(80, 140) + dir * vec2(40, 20),
                velocity = dir:normalize():scale(0.2 + math.random()),
                life = 0.5 + 0.5 * math.random()
            }
        end
    end
end

local function updateMessages(dt)
    comboColor = comboColor + dt * 10 * comboMeter
    if comboColor > 360 then
        comboColor = comboColor - 360
    end
    for i = 1, #messages do
        local m = messages[i]
        m.age = m.age + dt
        m.currentPos = math.applyLag(m.currentPos, m.targetPos, 0.8, dt)
    end
    for i = glitterCount, 1, -1 do
        local g = glitter[i]
        g.pos:add(g.velocity)
        g.velocity.y = g.velocity.y + 0.02
        g.life = g.life - dt
        g.color.mult = math.saturate(g.life * 4)
        if g.life < 0 then
            if i < glitterCount then
                glitter[i] = glitter[glitterCount]
            end
            glitterCount = glitterCount - 1
        end
    end
    if comboMeter > 10 and math.random() > 0.98 then
        for i = 1, math.floor(comboMeter) do
            local dir = vec2(math.random() - 0.5, math.random() - 0.5)
            glitterCount = glitterCount + 1
            glitter[glitterCount] = {
                color = rgbm.new(hsv(math.random() * 360, 1, 1):rgb(), 1),
                pos = vec2(195, 75) + dir * vec2(40, 20),
                velocity = dir:normalize():scale(0.2 + math.random()),
                life = 0.5 + 0.5 * math.random()
            }
        end
    end
end

local speedWarning = 0
function script.drawUI()
    if uiVisible then
        local uiState = ac.getUiState()
        updateMessages(uiState.dt)

        local speedRelative = math.saturate(math.floor(ac.getCarState(1).speedKmh) / requiredSpeed)
        speedWarning = math.applyLag(speedWarning, speedRelative < 1 and 1 or 0, 0.5, uiState.dt)

        local colorDark = rgbm(0.4, 0.4, 0.4, 1)
        local colorGrey = rgbm(0.7, 0.7, 0.7, 1)
        local colorAccent = rgbm.new(hsv(speedRelative * 120, 1, 1):rgb(), 1)
        local colorCombo =
        rgbm.new(hsv(comboColor, math.saturate(comboMeter / 10), 1):rgb(), math.saturate(comboMeter / 4))

        local function speedMeter(ref)
            ui.drawRectFilled((ref) + vec2(0, -4), ref + vec2(180, 5), colorDark, 1)
            ui.drawLine(ref + vec2(0, -4), ref + vec2(0, 4), colorGrey, 1)
            ui.drawLine(ref + vec2(requiredSpeed, -4), ref + vec2(requiredSpeed, 4), colorGrey, 1)

            local speed = math.min(ac.getCarState(1).speedKmh, 180)
            if speed > 1 then
                ui.drawLine(ref + vec2(0, 0), ref + vec2(speed, 0), colorAccent, 4)
            end
        end

        -- Background

        ui.beginTransparentWindow("overtakeScore", vec2(100 +  xLvl, 100 + yLvl), vec2(100 +  xLvl + scale, 100 + yLvl + scale))
        ui.beginOutline()

        ui.drawImage(image_0.src, vec2(0, 0), vec2(scale, scale), true)

        ui.pushStyleVar(ui.StyleVar.Alpha, 1 - speedWarning)
        ui.pushFont(ui.Font.Main)
        ui.textAligned("Highest Score: " .. highestScore .. " pts", vec2(50, 50))
        ui.popFont()
        ui.popStyleVar()

        ui.pushFont(ui.Font.Title)
        ui.textAligned(totalScore .. " pts", vec2(50, 50))
        ui.text(totalScore .. " pts")
        ui.sameLine(0, 20)
        ui.beginRotation()
        ui.textColored(math.ceil(comboMeter * 10) / 10 .. "x", colorCombo)
        if comboMeter > 20 then
            ui.endRotation(math.sin(comboMeter / 180 * 3141.5) * 3 * math.lerpInvSat(comboMeter, 20, 30) + 90)
        end
        ui.popFont()
        ui.endOutline(rgbm(0, 0, 0, 0.3))

        ui.offsetCursorY(20)
        ui.pushFont(ui.Font.Main)
        local startPos = ui.getCursor()
        for i = 1, #messages do
            local m = messages[i]
            local f = math.saturate(4 - m.currentPos) * math.saturate(8 - m.age)
            ui.setCursor(startPos + vec2(20 * 0.5 + math.saturate(1 - m.age * 10) ^ 2 * 50, (m.currentPos - 1) * 15))
            ui.textColored(
                    m.text,
                    m.mood == 1 and rgbm(0, 1, 0, f) or m.mood == -1 and rgbm(1, 0, 0, f) or rgbm(1, 1, 1, f)
            )
        end
        for i = 1, glitterCount do
            local g = glitter[i]
            if g ~= nil then
                ui.drawLine(g.pos, g.pos + g.velocity * 4, g.color, 2)
            end
        end
        ui.popFont()
        ui.setCursor(startPos + vec2(0 , 4 * 30))

        ui.pushStyleVar(ui.StyleVar.Alpha, speedWarning)
        ui.setCursorY(0)
        ui.pushFont(ui.Font.Main)
        ui.textColored("Keep speed above " .. requiredSpeed .. " km/h:", colorAccent)
        speedMeter(ui.getCursor() + vec2(-9 * 0.5, 4 * 0.2))

        ui.popFont()
        ui.popStyleVar()

        ui.endTransparentWindow()
    end
end

-- Extras menu app
local function pointsHUD()
    if ui.checkbox("Toggle App", uiVisible) then
        uiVisible = not uiVisible
    end

    -- X Position
    ui.newLine(1)
    ui.text('HUD X Position')
    local curXLvl, newXLvl = ui.slider("X Position", xLvl, -screenWidth, screenWidth)
    if newXLvl then
        xLvl = curXLvl
    end

    -- Y Position
    ui.newLine(1)
    ui.text('HUD Y Position')
    local curYLvl, newYLvl = ui.slider("Y Position", yLvl, -screenHeight, screenHeight)
    if newYLvl then
        yLvl = curYLvl
    end

    -- Scale
    ui.newLine(1)
    ui.text('HUD Scale')
    local curScale, newScale = ui.slider("Scale", scale, 0, 500)
    if newScale then
        scale = curScale
    end
end

local function pointsHUDClosed()

end

-- Register the app to the extras menu
ui.registerOnlineExtra(ui.Icons.FastForward,
        'Points UI',
        nil,
        pointsHUD,
        pointsHUDClosed)

function PrintLeaderboardRow(rank, name, score)
    ui.text(tostring(rank))
    ui.nextColumn()
    ui.text(name)
    ui.nextColumn()
    ui.text(tostring(score))
    ui.nextColumn()
end

local loadingLeaderboard = false
local leaderboard = nil
local ownRanking = nil

if config.enableLeaderboard then
    ui.registerOnlineExtra(ui.Icons.Leaderboard, "Points Leaderboard", function () return true end, function ()
        if not loadingLeaderboard then
            loadingLeaderboard = true
            GetLeaderboard(function (response)
                leaderboard = response
            end)
            GetOwnRanking(function (response)
                ownRanking = response
            end)
        end

        local close = false
        ui.childWindow("overtakeLeaderboard", vec2(0, 275), false, ui.WindowFlags.None, function ()
            if leaderboard == nil or ownRanking == nil then
                ui.text("Loading...")
            else
                ui.columns(3)
                ui.setColumnWidth(0, 45)
                ui.setColumnWidth(1, 200)

                PrintLeaderboardRow("#", "Name", "Score")

                for i, player in ipairs(leaderboard) do
                    PrintLeaderboardRow(tostring(i) .. ".", player.Name, player.Score)
                end

                PrintLeaderboardRow("...", "", "")
                PrintLeaderboardRow(ownRanking.Rank .. ".", ac.getDriverName(0), ownRanking.Rating)

                ui.columns()
            end

            ui.offsetCursorY(ui.availableSpaceY() - 32)
            if ui.button("Close") then
                close = true
                loadingLeaderboard = false
            end
        end)

        return close
    end)
end
