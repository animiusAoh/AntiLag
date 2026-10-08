local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")

local antiLagEnabled = false
local connections = {}

local saved = {
    particles = {},
    trails = {},
    beams = {},
    lights = {},
    shadows = {},
    postEffects = {},
    atmosphere = {}
}

local function optimizeObject(obj)
    if obj:IsA("ParticleEmitter") then
        if saved.particles[obj] == nil then
            saved.particles[obj] = obj.Enabled
        end
        obj.Enabled = false

    elseif obj:IsA("Trail") then
        if saved.trails[obj] == nil then
            saved.trails[obj] = obj.Enabled
        end
        obj.Enabled = false

    elseif obj:IsA("Beam") then
        if saved.beams[obj] == nil then
            saved.beams[obj] = obj.Enabled
        end
        obj.Enabled = false

    elseif obj:IsA("PointLight")
        or obj:IsA("SpotLight")
        or obj:IsA("SurfaceLight") then

        if saved.lights[obj] == nil then
            saved.lights[obj] = obj.Enabled
        end
        obj.Enabled = false

    elseif obj:IsA("BasePart") then
        if saved.shadows[obj] == nil then
            saved.shadows[obj] = obj.CastShadow
        end
        obj.CastShadow = false

    elseif obj:IsA("PostEffect") then
        if saved.postEffects[obj] == nil then
            saved.postEffects[obj] = obj.Enabled
        end
        obj.Enabled = false
    end
end

local function optimizeLighting()
    for _, obj in ipairs(Lighting:GetChildren()) do

        if obj:IsA("Atmosphere") then
            if saved.atmosphere[obj] == nil then
                saved.atmosphere[obj] = {
                    Density = obj.Density,
                    Haze = obj.Haze,
                    Glare = obj.Glare
                }
            end

            obj.Density = 0
            obj.Haze = 0
            obj.Glare = 0
        end

        optimizeObject(obj)
    end
end

local function enableAntiLag()
    if antiLagEnabled then return end

    antiLagEnabled = true

    -- Optimización inicial
    for _, obj in ipairs(Workspace:GetDescendants()) do
        optimizeObject(obj)
    end

    optimizeLighting()

    -- Detectar efectos nuevos durante la partida
    connections.workspace = Workspace.DescendantAdded:Connect(function(obj)
        if antiLagEnabled then
            task.defer(function()
                if obj.Parent then
                    optimizeObject(obj)
                end
            end)
        end
    end)

    connections.lighting = Lighting.ChildAdded:Connect(function(obj)
        if antiLagEnabled then
            task.defer(function()
                if obj.Parent then
                    optimizeObject(obj)

                    if obj:IsA("Atmosphere") then
                        obj.Density = 0
                        obj.Haze = 0
                        obj.Glare = 0
                    end
                end
            end)
        end
    end)

    print("🚀 ANTI LAG ACTIVADO")
end

local function restoreTable(tbl)
    for obj, value in pairs(tbl) do
        if obj and obj.Parent then
            obj.Enabled = value
        end
    end
end

local function disableAntiLag()
    if not antiLagEnabled then return end

    antiLagEnabled = false

    -- Detener vigilancia de objetos nuevos
    for _, connection in pairs(connections) do
        connection:Disconnect()
    end

    connections = {}

    restoreTable(saved.particles)
    restoreTable(saved.trails)
    restoreTable(saved.beams)
    restoreTable(saved.lights)
    restoreTable(saved.postEffects)

    -- Restaurar sombras
    for obj, value in pairs(saved.shadows) do
        if obj and obj.Parent then
            obj.CastShadow = value
        end
    end

    -- Restaurar Atmosphere
    for obj, data in pairs(saved.atmosphere) do
        if obj and obj.Parent then
            obj.Density = data.Density
            obj.Haze = data.Haze
            obj.Glare = data.Glare
        end
    end

    print("🟢 ANTI LAG DESACTIVADO")
end

UniTab:CreateButton({
    Name = "🚀 ANTI LAG",

    Callback = function()
        if antiLagEnabled then
            disableAntiLag()
        else
            enableAntiLag()
        end
    end
})
