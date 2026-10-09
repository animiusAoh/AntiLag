--[[
    Roblox Optimizer Suite v1.3 - FIXED & ENHANCED
    Enhanced Player Rendering Management + Performance Optimization
    Features:
    - Hide/Show other players to improve performance
    - Real-time player count tracking with join/leave updates
    - Automatic graphics optimization based on FPS
    - Mobile and PC performance optimizations
    - Professional GUI with status indicators
    Author: Enhanced and Fixed
    Version: 1.3
--]]

-- ============================
-- CONFIGURATION CONSTANTS
-- ============================
local CONFIG = {
    SCRIPT_ID = "OptimizerSuite_" .. tostring(math.random(100000, 999999)),
    
    -- Performance Settings
    MAX_OPERATIONS_PER_FRAME = 5,
    PROCESSING_DELAY = 0.1,
    FPS_UPDATE_INTERVAL = 30,
    OPTIMIZATION_INTERVAL = 3600,
    
    -- Optimization Thresholds
    LOW_FPS_THRESHOLD = 25,
    EMERGENCY_FPS_THRESHOLD = 15,
    GOOD_FPS_THRESHOLD = 45,
    
    -- Distance Optimization
    FAR_DISTANCE = 800,
    MID_DISTANCE = 400,
    NEAR_DISTANCE = 200,
    BATCH_SIZE = 30,
    
    -- GUI Configuration
    GUI_SIZE = UDim2.new(0, 200, 0, 130),
    GUI_POSITION = UDim2.new(0, 10, 0, 10),
    MINIMIZED_SIZE = UDim2.new(0, 70, 0, 30),
    
    -- Device Detection
    IS_MOBILE = false
}

-- ============================
-- SERVICES AND VARIABLES
-- ============================
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")
local localPlayer = Players.LocalPlayer

-- Prevent multiple instances
if _G[CONFIG.SCRIPT_ID] then
    warn("Optimizer Suite already running! Instance ID: " .. CONFIG.SCRIPT_ID)
    return
end
_G[CONFIG.SCRIPT_ID] = true

-- FIXED: Improved mobile detection
CONFIG.IS_MOBILE = UserInputService.TouchEnabled and not UserInputService.MouseEnabled

-- Adjust settings for mobile
if CONFIG.IS_MOBILE then
    CONFIG.MAX_OPERATIONS_PER_FRAME = 3
    CONFIG.FAR_DISTANCE = 600
    CONFIG.MID_DISTANCE = 300
    CONFIG.BATCH_SIZE = 20
    CONFIG.GUI_SIZE = UDim2.new(0, 180, 0, 120)
    CONFIG.MINIMIZED_SIZE = UDim2.new(0, 60, 0, 25)
end

-- ============================
-- UTILITY FUNCTIONS
-- ============================
local Utils = {}

function Utils.safeCall(func, ...)
    local success, result = pcall(func, ...)
    if not success then
        warn("Utils.safeCall failed: " .. tostring(result))
        return false, result
    end
    return true, result
end

function Utils.isValidPlayer(player)
    return player and player.Parent and player ~= localPlayer
end

function Utils.isValidCharacter(character)
    return character and character.Parent and character:FindFirstChild("HumanoidRootPart")
end

function Utils.debounce(func, delay)
    local lastCall = 0
    return function(...)
        local now = tick()
        if now - lastCall >= delay then
            lastCall = now
            return func(...)
        end
    end
end

-- FIXED: Added proper cleanup utility
function Utils.cleanupConnections(connections)
    for key, connection in pairs(connections) do
        if typeof(connection) == "RBXScriptConnection" then
            connection:Disconnect()
        elseif type(connection) == "table" then
            Utils.cleanupConnections(connection)
        end
        connections[key] = nil
    end
end

-- ============================
-- PLAYER RENDER MANAGER
-- ============================
local PlayerRenderManager = {}
PlayerRenderManager.__index = PlayerRenderManager

function PlayerRenderManager.new()
    local self = setmetatable({}, PlayerRenderManager)
    self.isDisabled = false
    self.originalParents = {}
    self.connections = {}
    self.playerCount = 0
    self.updateCallbacks = {}
    self.lastCountUpdate = 0
    self:_initialize()
    return self
end

function PlayerRenderManager:_initialize()
    self:_setupEventHandlers()
    self:_updatePlayerCount()
    
    -- Setup existing players
    for _, player in pairs(Players:GetPlayers()) do
        if Utils.isValidPlayer(player) then
            self:_setupPlayerConnection(player)
        end
    end
end

function PlayerRenderManager:_setupEventHandlers()
    -- Handle player joining
    self.connections.playerAdded = Players.PlayerAdded:Connect(function(player)
        self:_setupPlayerConnection(player)
        self:_scheduleCountUpdate()
    end)
    
    -- Handle player leaving
    self.connections.playerRemoving = Players.PlayerRemoving:Connect(function(player)
        self:_cleanupPlayer(player)
        self:_scheduleCountUpdate()
    end)
end

-- FIXED: Removed yield from event handlers
function PlayerRenderManager:_scheduleCountUpdate()
    local now = tick()
    if now - self.lastCountUpdate > 0.1 then
        self.lastCountUpdate = now
        spawn(function()
            wait(0.1)
            self:_updatePlayerCount()
        end)
    end
end

function PlayerRenderManager:_setupPlayerConnection(player)
    if not Utils.isValidPlayer(player) then return end
    
    if not self.connections[player] then
        self.connections[player] = {}
    end
    
    -- Clean up existing character connection
    if self.connections[player].character then
        self.connections[player].character:Disconnect()
    end
    
    -- Handle character spawning
    self.connections[player].character = player.CharacterAdded:Connect(function(character)
        spawn(function()
            wait(0.2)
            if self.isDisabled and Utils.isValidCharacter(character) then
                self:_hidePlayer(player)
            end
        end)
    end)
    
    -- Handle existing character
    if player.Character and self.isDisabled then
        self:_hidePlayer(player)
    end
end

function PlayerRenderManager:_hidePlayer(player)
    if not Utils.isValidPlayer(player) or not player.Character then return end
    
    Utils.safeCall(function()
        if not self.originalParents[player] then
            self.originalParents[player] = player.Character.Parent
        end
        player.Character.Parent = nil
    end)
end

function PlayerRenderManager:_showPlayer(player)
    if not Utils.isValidPlayer(player) or not player.Character then return end
    
    Utils.safeCall(function()
        if self.originalParents[player] then
            player.Character.Parent = self.originalParents[player]
            self.originalParents[player] = nil
        else
            player.Character.Parent = Workspace
        end
    end)
end

function PlayerRenderManager:_cleanupPlayer(player)
    if self.originalParents[player] then
        self:_showPlayer(player)
    end
    
    if self.connections[player] then
        Utils.cleanupConnections(self.connections[player])
        self.connections[player] = nil
    end
end

function PlayerRenderManager:_updatePlayerCount()
    local newCount = #Players:GetPlayers()
    
    if newCount ~= self.playerCount then
        self.playerCount = newCount
        
        for _, callback in pairs(self.updateCallbacks) do
            Utils.safeCall(callback, self.playerCount)
        end
    end
end

function PlayerRenderManager:onPlayerCountUpdate(callback)
    table.insert(self.updateCallbacks, callback)
end

function PlayerRenderManager:toggle()
    self.isDisabled = not self.isDisabled
    
    if self.isDisabled then
        for _, player in pairs(Players:GetPlayers()) do
            if Utils.isValidPlayer(player) then
                self:_hidePlayer(player)
            end
        end
    else
        for _, player in pairs(Players:GetPlayers()) do
            if Utils.isValidPlayer(player) then
                self:_showPlayer(player)
            end
        end
    end
    
    return self.isDisabled
end

function PlayerRenderManager:getPlayerCount()
    return self.playerCount
end

function PlayerRenderManager:isRenderingDisabled()
    return self.isDisabled
end

function PlayerRenderManager:destroy()
    if self.isDisabled then
        self:toggle()
    end
    
    Utils.cleanupConnections(self.connections)
    self.originalParents = {}
    self.updateCallbacks = {}
end

-- ============================
-- PERFORMANCE OPTIMIZER
-- ============================
local PerformanceOptimizer = {}
PerformanceOptimizer.__index = PerformanceOptimizer

function PerformanceOptimizer.new()
    local self = setmetatable({}, PerformanceOptimizer)
    self.processedObjects = setmetatable({}, {__mode = "k"})
    self.operationQueue = {}
    self.isProcessing = false
    self.frameCount = 0
    self.lastOptimizationFrame = 0
    self.fpsHistory = {}
    self.stats = {
        fps = 60,
        avgFps = 60,
        frameDrops = 0,
        status = "Initializing...",
        lastOptimization = 0
    }
    
    if CONFIG.IS_MOBILE then
        self:setGraphicsQuality("performance")
    else
        self:setGraphicsQuality("balanced")
    end
    
    return self
end

function PerformanceOptimizer:_addToQueue(operation, priority)
    if #self.operationQueue >= 100 then
        table.remove(self.operationQueue, 1)
    end
    
    table.insert(self.operationQueue, {
        func = operation,
        priority = priority or 1,
        timestamp = tick()
    })
end

function PerformanceOptimizer:_processQueue()
    if self.isProcessing or #self.operationQueue == 0 then return end
    
    self.isProcessing = true
    local processed = 0
    local startTime = tick()
    local maxTime = CONFIG.IS_MOBILE and 0.008 or 0.012
    
    table.sort(self.operationQueue, function(a, b)
        return a.priority > b.priority
    end)
    
    while processed < CONFIG.MAX_OPERATIONS_PER_FRAME and #self.operationQueue > 0 do
        local operation = table.remove(self.operationQueue, 1)
        
        if tick() - operation.timestamp <= 5 then
            Utils.safeCall(operation.func)
            processed = processed + 1
        end
        
        if tick() - startTime > maxTime then
            break
        end
    end
    
    self.isProcessing = false
end

-- FIXED: Improved optimization with better error handling
function PerformanceOptimizer:optimizeNearbyParts()
    if not localPlayer.Character or not localPlayer.Character:FindFirstChild("HumanoidRootPart") then
        return
    end
    
    local playerPosition = localPlayer.Character.HumanoidRootPart.Position
    local optimized = 0
    
    -- FIXED: Better region handling
    local success, parts = pcall(function()
        local region = Region3.new(
            playerPosition - Vector3.new(CONFIG.FAR_DISTANCE, 500, CONFIG.FAR_DISTANCE),
            playerPosition + Vector3.new(CONFIG.FAR_DISTANCE, 500, CONFIG.FAR_DISTANCE)
        )
        region = region:ExpandToGrid(4)
        return Workspace:FindPartsInRegion3(region, nil, CONFIG.BATCH_SIZE)
    end)
    
    if not success then
        -- Fallback to workspace children if region fails
        parts = {}
        for i, child in pairs(Workspace:GetChildren()) do
            if child:IsA("BasePart") and i <= CONFIG.BATCH_SIZE then
                table.insert(parts, child)
            end
        end
    end
    
    for _, part in pairs(parts) do
        if part:IsA("BasePart") and not self.processedObjects[part] then
            self:_addToQueue(function()
                if not part or not part.Parent then return end
                
                local distance = (part.Position - playerPosition).Magnitude
                
                if CONFIG.IS_MOBILE then
                    if distance > CONFIG.MID_DISTANCE then
                        part.CastShadow = false
                        part.Material = Enum.Material.SmoothPlastic
                        part.Reflectance = 0
                    elseif distance > CONFIG.NEAR_DISTANCE then
                        part.CastShadow = false
                    end
                else
                    if distance > CONFIG.FAR_DISTANCE then
                        part.CastShadow = false
                        if part.Material ~= Enum.Material.Plastic then
                            part.Material = Enum.Material.Plastic
                        end
                    elseif distance > CONFIG.MID_DISTANCE then
                        part.Reflectance = 0
                    end
                end
                
                self.processedObjects[part] = true
                optimized = optimized + 1
            end, 2)
        end
    end
    
    if optimized > 0 then
        self.stats.status = "Optimized " .. optimized .. " parts"
        self.stats.lastOptimization = tick()
    end
end

function PerformanceOptimizer:setGraphicsQuality(quality)
    local lighting = Lighting
    local settings = {
        performance = {
            globalShadows = false,
            fogEnd = CONFIG.IS_MOBILE and 250 or 300,
            fogStart = CONFIG.IS_MOBILE and 150 or 200,
            brightness = 1.5,
            atmosphereDensity = 0.1,
            sunRays = false,
            bloom = false,
            depthOfField = false
        },
        balanced = {
            globalShadows = not CONFIG.IS_MOBILE,
            fogEnd = CONFIG.IS_MOBILE and 400 or 600,
            fogStart = CONFIG.IS_MOBILE and 200 or 300,
            brightness = 1.5,
            atmosphereDensity = 0.2,
            sunRays = false,
            bloom = not CONFIG.IS_MOBILE,
            depthOfField = false
        },
        quality = {
            globalShadows = true,
            fogEnd = 1000,
            fogStart = 600,
            brightness = 2,
            atmosphereDensity = 0.4,
            sunRays = true,
            bloom = true,
            depthOfField = true
        }
    }
    
    local config = settings[quality] or settings.balanced
    
    Utils.safeCall(function()
        lighting.GlobalShadows = config.globalShadows
        lighting.FogEnd = config.fogEnd
        lighting.FogStart = config.fogStart
        lighting.Brightness = config.brightness
        
        for _, effect in pairs(lighting:GetChildren()) do
            if effect:IsA("Atmosphere") then
                effect.Density = config.atmosphereDensity
            elseif effect:IsA("SunRaysEffect") then
                effect.Enabled = config.sunRays
            elseif effect:IsA("BloomEffect") then
                effect.Enabled = config.bloom
            elseif effect:IsA("DepthOfFieldEffect") then
                effect.Enabled = config.depthOfField
            end
        end
    end)
    
    self.stats.status = "Graphics: " .. quality
end

-- FIXED: Better FPS calculation with history
function PerformanceOptimizer:updateStats(deltaTime)
    if not deltaTime or deltaTime <= 0 then return end
    
    self.frameCount = self.frameCount + 1
    
    local currentFPS = math.min(1 / deltaTime, 120) -- Cap at 120 FPS
    
    -- Maintain FPS history for better averaging
    table.insert(self.fpsHistory, currentFPS)
    if #self.fpsHistory > 60 then
        table.remove(self.fpsHistory, 1)
    end
    
    -- Calculate smoothed FPS
    local sum = 0
    for _, fps in pairs(self.fpsHistory) do
        sum = sum + fps
    end
    self.stats.fps = math.floor(sum / #self.fpsHistory + 0.5)
    
    -- Update average FPS every second
    if self.frameCount % 60 == 0 then
        self.stats.avgFps = self.stats.fps
    end
    
    -- Auto-adjust quality based on FPS
    if currentFPS < CONFIG.LOW_FPS_THRESHOLD then
        self.stats.frameDrops = self.stats.frameDrops + 1
        
        if self.stats.frameDrops > 5 then
            if currentFPS < CONFIG.EMERGENCY_FPS_THRESHOLD then
                self:_emergencyOptimize()
            else
                self:setGraphicsQuality("performance")
            end
            self.stats.frameDrops = 0
        end
    else
        self.stats.frameDrops = math.max(0, self.stats.frameDrops - 0.1)
        
        if self.stats.avgFps > CONFIG.GOOD_FPS_THRESHOLD and self.frameCount % 600 == 0 then
            if CONFIG.IS_MOBILE then
                self:setGraphicsQuality("performance")
            else
                self:setGraphicsQuality("balanced")
            end
        end
    end
    
    if self.frameCount - self.lastOptimizationFrame > CONFIG.OPTIMIZATION_INTERVAL then
        self:optimizeNearbyParts()
        self.lastOptimizationFrame = self.frameCount
    end
end

function PerformanceOptimizer:_emergencyOptimize()
    self.stats.status = "Emergency optimization!"
    self:setGraphicsQuality("performance")
    
    self:_addToQueue(function()
        for _, obj in pairs(Workspace:GetDescendants()) do
            if obj:IsA("Fire") or obj:IsA("Smoke") or obj:IsA("Explosion") or obj:IsA("ParticleEmitter") then
                obj.Enabled = false
            elseif obj:IsA("PointLight") or obj:IsA("SpotLight") then
                obj.Enabled = false
            end
        end
    end, 5)
    
    self.processedObjects = setmetatable({}, {__mode = "k"})
end

function PerformanceOptimizer:getStats()
    return {
        fps = self.stats.fps,
        avgFps = self.stats.avgFps,
        status = self.stats.status,
        frameDrops = math.floor(self.stats.frameDrops),
        queueSize = #self.operationQueue,
        lastOptimization = self.stats.lastOptimization
    }
end

function PerformanceOptimizer:destroy()
    self.operationQueue = {}
    self.processedObjects = {}
    self.fpsHistory = {}
    self.isProcessing = false
end

-- ============================
-- GUI MANAGER
-- ============================
local GUIManager = {}
GUIManager.__index = GUIManager

function GUIManager.new(playerRenderManager, performanceOptimizer)
    local self = setmetatable({}, GUIManager)
    self.playerRenderManager = playerRenderManager
    self.performanceOptimizer = performanceOptimizer
    self.isMinimized = false
    self.connections = {}
    self:_createGUI()
    return self
end

function GUIManager:_createGUI()
    local existingGUI = localPlayer.PlayerGui:FindFirstChild("OptimizerSuiteGUI")
    if existingGUI then
        existingGUI:Destroy()
    end
    
    self.screenGui = Instance.new("ScreenGui")
    self.screenGui.Name = "OptimizerSuiteGUI"
    self.screenGui.ResetOnSpawn = false
    self.screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    self.screenGui.Parent = localPlayer:WaitForChild("PlayerGui")
    
    self.mainFrame = Instance.new("Frame")
    self.mainFrame.Name = "MainFrame"
    self.mainFrame.Size = CONFIG.GUI_SIZE
    self.mainFrame.Position = CONFIG.GUI_POSITION
    self.mainFrame.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
    self.mainFrame.BorderSizePixel = 0
    self.mainFrame.Active = true
    self.mainFrame.Draggable = true
    self.mainFrame.Parent = self.screenGui
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = self.mainFrame
    
    self:_createTitleBar()
    self:_createControls()
    self:_createStatusIndicators()
    self:_setupEventHandlers()
    self:_setupUpdateLoop()
end

function GUIManager:_createTitleBar()
    local titleBar = Instance.new("Frame")
    titleBar.Name = "TitleBar"
    titleBar.Size = UDim2.new(1, 0, 0, 25)
    titleBar.Position = UDim2.new(0, 0, 0, 0)
    titleBar.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    titleBar.BorderSizePixel = 0
    titleBar.Parent = self.mainFrame
    
    local titleCorner = Instance.new("UICorner")
    titleCorner.CornerRadius = UDim.new(0, 8)
    titleCorner.Parent = titleBar
    
    self.titleLabel = Instance.new("TextLabel")
    self.titleLabel.Name = "TitleLabel"
    self.titleLabel.Size = UDim2.new(1, -50, 1, 0)
    self.titleLabel.Position = UDim2.new(0, 5, 0, 0)
    self.titleLabel.Text = CONFIG.IS_MOBILE and "Optimizer" or "Player Optimizer"
    self.titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    self.titleLabel.BackgroundTransparency = 1
    self.titleLabel.Font = Enum.Font.SourceSansBold
    self.titleLabel.TextSize = CONFIG.IS_MOBILE and 11 or 12
    self.titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    self.titleLabel.Parent = titleBar
    
    self.hideButton = Instance.new("TextButton")
    self.hideButton.Name = "HideButton"
    self.hideButton.Size = UDim2.new(0, 20, 0, 20)
    self.hideButton.Position = UDim2.new(1, -25, 0, 2.5)
    self.hideButton.Text = "−"
    self.hideButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    self.hideButton.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
    self.hideButton.Font = Enum.Font.SourceSansBold
    self.hideButton.TextSize = 14
    self.hideButton.BorderSizePixel = 0
    self.hideButton.Parent = titleBar
    
    local hideCorner = Instance.new("UICorner")
    hideCorner.CornerRadius = UDim.new(0, 4)
    hideCorner.Parent = self.hideButton
end

function GUIManager:_createControls()
    self.toggleButton = Instance.new("TextButton")
    self.toggleButton.Name = "ToggleButton"
    self.toggleButton.Size = UDim2.new(1, -10, 0, 25)
    self.toggleButton.Position = UDim2.new(0, 5, 0, 30)
    self.toggleButton.Text = "Hide Players"
    self.toggleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    self.toggleButton.BackgroundColor3 = Color3.fromRGB(55, 120, 55)
    self.toggleButton.Font = Enum.Font.SourceSans
    self.toggleButton.TextSize = CONFIG.IS_MOBILE and 10 or 11
    self.toggleButton.BorderSizePixel = 0
    self.toggleButton.Parent = self.mainFrame
    
    local toggleCorner = Instance.new("UICorner")
    toggleCorner.CornerRadius = UDim.new(0, 6)
    toggleCorner.Parent = self.toggleButton
    
    self.playerCountLabel = Instance.new("TextLabel")
    self.playerCountLabel.Name = "PlayerCountLabel"
    self.playerCountLabel.Size = UDim2.new(0.6, 0, 0, 15)
    self.playerCountLabel.Position = UDim2.new(0, 5, 0, 60)
    self.playerCountLabel.Text = "Players: " .. self.playerRenderManager:getPlayerCount()
    self.playerCountLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    self.playerCountLabel.BackgroundTransparency = 1
    self.playerCountLabel.Font = Enum.Font.SourceSans
    self.playerCountLabel.TextSize = CONFIG.IS_MOBILE and 9 or 10
    self.playerCountLabel.TextXAlignment = Enum.TextXAlignment.Left
    self.playerCountLabel.Parent = self.mainFrame
    
    self.fpsLabel = Instance.new("TextLabel")
    self.fpsLabel.Name = "FPSLabel"
    self.fpsLabel.Size = UDim2.new(0.4, -5, 0, 15)
    self.fpsLabel.Position = UDim2.new(0.6, -3, 0, 60)
    self.fpsLabel.Text = "FPS: 60"
    self.fpsLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    self.fpsLabel.BackgroundTransparency = 1
    self.fpsLabel.Font = Enum.Font.SourceSans
    self.fpsLabel.TextSize = CONFIG.IS_MOBILE and 9 or 10
    self.fpsLabel.TextXAlignment = Enum.TextXAlignment.Right
    self.fpsLabel.Parent = self.mainFrame
    
    self.statusLabel = Instance.new("TextLabel")
    self.statusLabel.Name = "StatusLabel"
    self.statusLabel.Size = UDim2.new(1, -10, 0, 15)
    self.statusLabel.Position = UDim2.new(0, 5, 0, 75)
    self.statusLabel.Text = "Status: Ready"
    self.statusLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
    self.statusLabel.BackgroundTransparency = 1
    self.statusLabel.Font = Enum.Font.SourceSans
    self.statusLabel.TextSize = CONFIG.IS_MOBILE and 8 or 9
    self.statusLabel.TextXAlignment = Enum.TextXAlignment.Left
    self.statusLabel.TextTruncate = Enum.TextTruncate.AtEnd
    self.statusLabel.Parent = self.mainFrame
    
    self.infoLabel = Instance.new("TextLabel")
    self.infoLabel.Name = "InfoLabel"
    self.infoLabel.Size = UDim2.new(1, -10, 0, 15)
    self.infoLabel.Position = UDim2.new(0, 5, 0, 90)
    self.infoLabel.Text = CONFIG.IS_MOBILE and "Mobile Mode" or "PC Mode"
    self.infoLabel.TextColor3 = Color3.fromRGB(100, 150, 255)
    self.infoLabel.BackgroundTransparency = 1
    self.infoLabel.Font = Enum.Font.SourceSans
    self.infoLabel.TextSize = CONFIG.IS_MOBILE and 8 or 9
    self.infoLabel.TextXAlignment = Enum.TextXAlignment.Left
    self.infoLabel.Parent = self.mainFrame
end

function GUIManager:_createStatusIndicators()
    local dotsFrame = Instance.new("Frame")
    dotsFrame.Name = "DotsFrame"
    dotsFrame.Size = UDim2.new(0, 30, 0, 6)
    dotsFrame.Position = UDim2.new(1, -35, 0, 105)
    dotsFrame.BackgroundTransparency = 1
    dotsFrame.Parent = self.mainFrame
    
    self.renderingDot = Instance.new("Frame")
    self.renderingDot.Name = "RenderingDot"
    self.renderingDot.Size = UDim2.new(0, 6, 0, 6)
    self.renderingDot.Position = UDim2.new(0, 0, 0, 0)
    self.renderingDot.BackgroundColor3 = Color3.fromRGB(255, 60, 60)
    self.renderingDot.BorderSizePixel = 0
    self.renderingDot.Parent = dotsFrame
    
    local renderingDotCorner = Instance.new("UICorner")
    renderingDotCorner.CornerRadius = UDim.new(0, 3)
    renderingDotCorner.Parent = self.renderingDot
    
    self.perfDot = Instance.new("Frame")
    self.perfDot.Name = "PerfDot"
    self.perfDot.Size = UDim2.new(0, 6, 0, 6)
    self.perfDot.Position = UDim2.new(0, 12, 0, 0)
    self.perfDot.BackgroundColor3 = Color3.fromRGB(60, 255, 60)
    self.perfDot.BorderSizePixel = 0
    self.perfDot.Parent = dotsFrame
    
    local perfDotCorner = Instance.new("UICorner")
    perfDotCorner.CornerRadius = UDim.new(0, 3)
    perfDotCorner.Parent = self.perfDot
    
    self.connectionDot = Instance.new("Frame")
    self.connectionDot.Name = "ConnectionDot"
    self.connectionDot.Size = UDim2.new(0, 6, 0, 6)
    self.connectionDot.Position = UDim2.new(0, 24, 0, 0)
    self.connectionDot.BackgroundColor3 = Color3.fromRGB(60, 255, 60)
    self.connectionDot.BorderSizePixel = 0
    self.connectionDot.Parent = dotsFrame
    
    local connectionDotCorner = Instance.new("UICorner")
    connectionDotCorner.CornerRadius = UDim.new(0, 3)
    connectionDotCorner.Parent = self.connectionDot
    
    -- Minimized dots
    self.miniRenderingDot = Instance.new("Frame")
    self.miniRenderingDot.Name = "MiniRenderingDot"
    self.miniRenderingDot.Size = UDim2.new(0, 6, 0, 6)
    self.miniRenderingDot.Position = UDim2.new(0, 10, 0, 12)
    self.miniRenderingDot.BackgroundColor3 = Color3.fromRGB(255, 60, 60)
    self.miniRenderingDot.BorderSizePixel = 0
    self.miniRenderingDot.Visible = false
    self.miniRenderingDot.Parent = self.mainFrame
    
    local miniRenderingDotCorner = Instance.new("UICorner")
    miniRenderingDotCorner.CornerRadius = UDim.new(0, 3)
    miniRenderingDotCorner.Parent = self.miniRenderingDot
    
    self.miniPerfDot = Instance.new("Frame")
    self.miniPerfDot.Name = "MiniPerfDot"
    self.miniPerfDot.Size = UDim2.new(0, 6, 0, 6)
    self.miniPerfDot.Position = UDim2.new(0, 20, 0, 12)
    self.miniPerfDot.BackgroundColor3 = Color3.fromRGB(60, 255, 60)
    self.miniPerfDot.BorderSizePixel = 0
    self.miniPerfDot.Visible = false
    self.miniPerfDot.Parent = self.mainFrame
    
    local miniPerfDotCorner = Instance.new("UICorner")
    miniPerfDotCorner.CornerRadius = UDim.new(0, 3)
    miniPerfDotCorner.Parent = self.miniPerfDot
end

function GUIManager:_setupEventHandlers()
    self.connections.toggleButton = self.toggleButton.MouseButton1Click:Connect(function()
        local isDisabled = self.playerRenderManager:toggle()
        self:_updateToggleButton(isDisabled)
        self:_updateStatusDots()
    end)
    
    self.connections.hideButton = self.hideButton.MouseButton1Click:Connect(function()
        self:_toggleMinimize()
    end)
    
    -- FIXED: Removed yield from callback
    self.playerRenderManager:onPlayerCountUpdate(function(count)
        self.playerCountLabel.Text = "Players: " .. count
        
        spawn(function()
            local originalColor = self.playerCountLabel.TextColor3
            self.playerCountLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
            wait(0.2)
            if self.playerCountLabel and self.playerCountLabel.Parent then
                self.playerCountLabel.TextColor3 = originalColor
            end
        end)
    end)
    
    -- Button hover effects
    self.connections.toggleEnter = self.toggleButton.MouseEnter:Connect(function()
        if not self.playerRenderManager:isRenderingDisabled() then
            self.toggleButton.BackgroundColor3 = Color3.fromRGB(75, 140, 75)
        else
            self.toggleButton.BackgroundColor3 = Color3.fromRGB(140, 75, 75)
        end
    end)
    
    self.connections.toggleLeave = self.toggleButton.MouseLeave:Connect(function()
        self:_updateToggleButton(self.playerRenderManager:isRenderingDisabled())
    end)
    
    self.connections.hideEnter = self.hideButton.MouseEnter:Connect(function()
        self.hideButton.BackgroundColor3 = Color3.fromRGB(90, 90, 90)
    end)
    
    self.connections.hideLeave = self.hideButton.MouseLeave:Connect(function()
        self.hideButton.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
    end)
end

function GUIManager:_setupUpdateLoop()
    self.connections.update = RunService.Heartbeat:Connect(Utils.debounce(function()
        local stats = self.performanceOptimizer:getStats()
        self.fpsLabel.Text = "FPS: " .. stats.fps
        
        if stats.fps >= CONFIG.GOOD_FPS_THRESHOLD then
            self.fpsLabel.TextColor3 = Color3.fromRGB(60, 255, 60)
        elseif stats.fps >= CONFIG.LOW_FPS_THRESHOLD then
            self.fpsLabel.TextColor3 = Color3.fromRGB(255, 200, 60)
        else
            self.fpsLabel.TextColor3 = Color3.fromRGB(255, 60, 60)
        end
        
        self.statusLabel.Text = "Status: " .. stats.status
        self:_updateStatusDots()
    end, 0.5))
end

-- FIXED: Single definition of _updateToggleButton
function GUIManager:_updateToggleButton(isDisabled)
    if isDisabled then
        self.toggleButton.Text = "Show Players"
        self.toggleButton.BackgroundColor3 = Color3.fromRGB(120, 55, 55)
    else
        self.toggleButton.Text = "Hide Players"
        self.toggleButton.BackgroundColor3 = Color3.fromRGB(55, 120, 55)
    end
end

function GUIManager:_updateStatusDots()
    if self.playerRenderManager:isRenderingDisabled() then
        self.renderingDot.BackgroundColor3 = Color3.fromRGB(60, 255, 60)
        if self.miniRenderingDot then
            self.miniRenderingDot.BackgroundColor3 = Color3.fromRGB(60, 255, 60)
        end
    else
        self.renderingDot.BackgroundColor3 = Color3.fromRGB(255, 60, 60)
        if self.miniRenderingDot then
            self.miniRenderingDot.BackgroundColor3 = Color3.fromRGB(255, 60, 60)
        end
    end
    
    local stats = self.performanceOptimizer:getStats()
    local perfColor
    if stats.fps >= CONFIG.GOOD_FPS_THRESHOLD then
        perfColor = Color3.fromRGB(60, 255, 60)
    elseif stats.fps >= CONFIG.LOW_FPS_THRESHOLD then
        perfColor = Color3.fromRGB(255, 200, 60)
    else
        perfColor = Color3.fromRGB(255, 60, 60)
    end
    
    self.perfDot.BackgroundColor3 = perfColor
    if self.miniPerfDot then
        self.miniPerfDot.BackgroundColor3 = perfColor
    end
    
    self.connectionDot.BackgroundColor3 = Color3.fromRGB(60, 255, 60)
end

function GUIManager:_toggleMinimize()
    self.isMinimized = not self.isMinimized
    
    if self.isMinimized then
        for _, child in pairs(self.mainFrame:GetChildren()) do
            if child.Name ~= "TitleBar" and not child:IsA("UICorner") then
                child.Visible = false
            end
        end
        
        if self.miniRenderingDot then
            self.miniRenderingDot.Visible = true
        end
        if self.miniPerfDot then
            self.miniPerfDot.Visible = true
        end
        
        self:_updateStatusDots()
        
        self.mainFrame:TweenSize(
            CONFIG.MINIMIZED_SIZE,
            Enum.EasingDirection.Out,
            Enum.EasingStyle.Quad,
            0.3,
            true
        )
        
        self.hideButton.Text = "+"
        self.titleLabel.Visible = false
    else
        self.mainFrame:TweenSize(
            CONFIG.GUI_SIZE,
            Enum.EasingDirection.Out,
            Enum.EasingStyle.Quad,
            0.3,
            true,
            function()
                for _, child in pairs(self.mainFrame:GetChildren()) do
                    if child.Name ~= "TitleBar" and not child:IsA("UICorner") then
                        child.Visible = true
                    end
                end
                
                self.titleLabel.Visible = true
                
                if self.miniRenderingDot then
                    self.miniRenderingDot.Visible = false
                end
                if self.miniPerfDot then
                    self.miniPerfDot.Visible = false
                end
            end
        )
        
        self.hideButton.Text = "−"
    end
end

function GUIManager:destroy()
    Utils.cleanupConnections(self.connections)
    
    if self.screenGui then
        self.screenGui:Destroy()
    end
end

-- ============================
-- MAIN SCRIPT INITIALIZATION
-- ============================
local OptimizerSuite = {}
OptimizerSuite.__index = OptimizerSuite

function OptimizerSuite.new()
    local self = setmetatable({}, OptimizerSuite)
    
    self.playerRenderManager = PlayerRenderManager.new()
    self.performanceOptimizer = PerformanceOptimizer.new()
    self.guiManager = GUIManager.new(self.playerRenderManager, self.performanceOptimizer)
    
    self.connections = {}
    self.isRunning = true
    
    self:_setupUpdateLoop()
    self:_setupCleanup()
    
    return self
end

function OptimizerSuite:_setupUpdateLoop()
    local frameCount = 0
    local lastUpdate = tick()
    
    self.connections.renderStepped = RunService.RenderStepped:Connect(function(deltaTime)
        if not self.isRunning then return end
        
        frameCount = frameCount + 1
        
        self.performanceOptimizer:updateStats(deltaTime)
        self.performanceOptimizer:_processQueue()
        
        if frameCount % CONFIG.OPTIMIZATION_INTERVAL == 0 then
            Utils.safeCall(function()
                self.performanceOptimizer:optimizeNearbyParts()
            end)
        end
    end)
    
    if localPlayer.Character then
        self:_onCharacterAdded(localPlayer.Character)
    end
    
    self.connections.characterAdded = localPlayer.CharacterAdded:Connect(function(character)
        self:_onCharacterAdded(character)
    end)
end

function OptimizerSuite:_onCharacterAdded(character)
    spawn(function()
        wait(2)
        if self.performanceOptimizer then
            self.performanceOptimizer.processedObjects = setmetatable({}, {__mode = "k"})
            self.performanceOptimizer.stats.status = "Character respawned"
        end
    end)
end

function OptimizerSuite:_setupCleanup()
    game:BindToClose(function()
        self:destroy()
    end)
    
    script.AncestryChanged:Connect(function()
        if not script.Parent then
            self:destroy()
        end
    end)
end

function OptimizerSuite:destroy()
    print("Shutting down Optimizer Suite...")
    
    self.isRunning = false
    
    Utils.cleanupConnections(self.connections)
    
    if self.playerRenderManager then
        self.playerRenderManager:destroy()
    end
    
    if self.performanceOptimizer then
        self.performanceOptimizer:destroy()
    end
    
    if self.guiManager then
        self.guiManager:destroy()
    end
    
    _G[CONFIG.SCRIPT_ID] = nil
    
    print("Optimizer Suite destroyed successfully")
end

-- Initialize the suite
print("Initializing Optimizer Suite v2.3 (Fixed)...")
print("Device Mode:", CONFIG.IS_MOBILE and "Mobile" or "PC")

local optimizerSuite = OptimizerSuite.new()

spawn(function()
    wait(3)
    if optimizerSuite and optimizerSuite.performanceOptimizer then
        optimizerSuite.performanceOptimizer:optimizeNearbyParts()
        
        wait(2)
        local stats = optimizerSuite.performanceOptimizer:getStats()
        if stats.avgFps < 30 then
            print("Low FPS detected, switching to performance mode")
            optimizerSuite.performanceOptimizer:setGraphicsQuality("performance")
        end
    end
end)

-- Export global API
_G.OptimizerSuite = {
    instance = optimizerSuite,
    setGraphicsQuality = function(quality)
        if optimizerSuite and optimizerSuite.performanceOptimizer then
            optimizerSuite.performanceOptimizer:setGraphicsQuality(quality)
        end
    end,
    getStats = function()
        if optimizerSuite and optimizerSuite.performanceOptimizer then
            return optimizerSuite.performanceOptimizer:getStats()
        end
        return {}
    end,
    destroy = function()
        if optimizerSuite then
            optimizerSuite:destroy()
            optimizerSuite = nil
        end
    end
}
