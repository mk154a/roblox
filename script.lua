-- Carrega as bibliotecas Fluent
local Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()
local SaveManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/SaveManager.lua"))()
local InterfaceManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/InterfaceManager.lua"))()

-- Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Camera = workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer

-- Variáveis do ESP
local PlayerHighlights = {}
local PlayerBillboards = {}
local DroneHighlights = {}
local ESPEnabled = false
local ESPConnections = {}
local MainESPConnections = {}

-- Função para obter o time do jogador
local function GetPlayerTeam(player)
    if not player then return nil end
    
    local teamsFolder = workspace:FindFirstChild("___teams_")
    if not teamsFolder then return nil end
    
    -- Verifica defenders
    local defenders = teamsFolder:FindFirstChild("defenders")
    if defenders then
        local playerInTeam = defenders:FindFirstChild(player.Name)
        if playerInTeam then
            return "defenders"
        end
    end
    
    -- Verifica attackers
    local attackers = teamsFolder:FindFirstChild("attackers")
    if attackers then
        local playerInTeam = attackers:FindFirstChild(player.Name)
        if playerInTeam then
            return "attackers"
        end
    end
    
    return nil
end

-- Função para obter a cor baseada no time (aliado = verde, inimigo = vermelho)
local function GetTeamColor(playerTeam, player)
    -- Obtém o time do LocalPlayer
    local myTeam = GetPlayerTeam(LocalPlayer)
    
    -- Se o jogador é o próprio LocalPlayer, não deve ter ESP
    if player == LocalPlayer then
        return Color3.new(1, 1, 1) -- Branco (não usado)
    end
    
    -- Se não tem time definido para mim, considera todos como inimigos
    if not myTeam or myTeam == nil then
        return Color3.new(1, 0, 0) -- Vermelho (inimigo)
    end
    
    -- Se o jogador não tem time definido, considera como inimigo
    if not playerTeam or playerTeam == nil then
        return Color3.new(1, 0, 0) -- Vermelho (inimigo)
    end
    
    -- Garante que ambos são strings e compara
    local myTeamStr = tostring(myTeam)
    local playerTeamStr = tostring(playerTeam)
    
    -- Compara os times (deve ser exatamente igual)
    if myTeamStr == playerTeamStr then
        return Color3.new(0, 1, 0) -- Verde (aliado)
    else
        return Color3.new(1, 0, 0) -- Vermelho (inimigo)
    end
end

-- Função para criar ESP de um jogador
local function CreatePlayerESP(player)
    if player == LocalPlayer then return end
    
    local function SetupESP(character)
        if not character then return end
        
        -- Remove ESP antigo se existir
        if PlayerHighlights[player] then
            PlayerHighlights[player]:Destroy()
            PlayerHighlights[player] = nil
        end
        if PlayerBillboards[player] then
            PlayerBillboards[player]:Destroy()
            PlayerBillboards[player] = nil
        end
        
        -- Cria Highlight
        local highlight = Instance.new("Highlight")
        highlight.Name = "ESP"
        highlight.Adornee = character
        highlight.Parent = character
        highlight.FillTransparency = 1
        highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        
        -- Cria BillboardGui
        local head = character:WaitForChild("Head", 5)
        if not head then return end
        
        local billboard = Instance.new("BillboardGui")
        billboard.Name = "PlayerNameESP"
        billboard.Adornee = head
        billboard.Size = UDim2.new(0, 200, 0, 50)
        billboard.StudsOffset = Vector3.new(0, 3, 0)
        billboard.AlwaysOnTop = true
        billboard.MaxDistance = 100
        billboard.Parent = character
        
        local textLabel = Instance.new("TextLabel")
        textLabel.Name = "PlayerName"
        textLabel.Size = UDim2.new(1, 0, 1, 0)
        textLabel.BackgroundTransparency = 1
        textLabel.Text = player.Name
        textLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
        textLabel.TextStrokeTransparency = 0
        textLabel.TextSize = 20
        textLabel.Font = Enum.Font.GothamBold
        textLabel.Parent = billboard
        
        PlayerHighlights[player] = highlight
        PlayerBillboards[player] = billboard
        
        -- Função para atualizar cor baseada no time
        local function UpdateTeamColor()
            if not ESPEnabled then return end
            if not character or not character.Parent then return end
            if not highlight or not highlight.Parent then return end
            if not textLabel or not textLabel.Parent then return end
            
            -- Obtém o time do jogador e do LocalPlayer
            local playerTeam = GetPlayerTeam(player)
            local myTeam = GetPlayerTeam(LocalPlayer)
            
            -- Determina a cor baseada na comparação
            local color
            if not myTeam then
                -- Se não tem time definido, considera como inimigo
                color = Color3.new(1, 0, 0) -- Vermelho
            elseif not playerTeam then
                -- Se o jogador não tem time, considera como inimigo
                color = Color3.new(1, 0, 0) -- Vermelho
            elseif tostring(playerTeam) == tostring(myTeam) then
                -- Mesmo time = aliado
                color = Color3.new(0, 1, 0) -- Verde
            else
                -- Time diferente = inimigo
                color = Color3.new(1, 0, 0) -- Vermelho
            end
            
            -- Atualiza as cores
            highlight.OutlineColor = color
            textLabel.TextColor3 = color
            
            -- Atualiza o texto com o prefixo do time
            if playerTeam then
                if playerTeam == "defenders" then
                    textLabel.Text = "[D] " .. player.Name
                elseif playerTeam == "attackers" then
                    textLabel.Text = "[A] " .. player.Name
                else
                    textLabel.Text = player.Name
                end
            else
                textLabel.Text = player.Name
            end
        end
        
        -- Atualiza a cor a cada 500ms
        local updateRunning = true
        local updateThread = task.spawn(function()
            while updateRunning and ESPEnabled do
                if character and character.Parent and highlight.Parent and textLabel.Parent then
                    UpdateTeamColor()
                else
                    updateRunning = false
                    break
                end
                task.wait(0.5) -- Atualiza a cada 500ms
            end
        end)
        
        -- Monitora quando o character é removido
        local connection
        connection = RunService.Heartbeat:Connect(function()
            if not character or not character.Parent then
                updateRunning = false
                if connection then connection:Disconnect() end
                return
            end
        end)
        
        table.insert(ESPConnections, connection)
        
        -- Armazena o thread para limpeza
        table.insert(ESPConnections, {
            Disconnect = function()
                updateRunning = false
            end
        })
        
        -- Limpa quando o character é removido
        character.AncestryChanged:Connect(function(_, parent)
            if parent == nil then
                updateRunning = false
                if PlayerHighlights[player] then
                    PlayerHighlights[player]:Destroy()
                    PlayerHighlights[player] = nil
                end
                if PlayerBillboards[player] then
                    PlayerBillboards[player]:Destroy()
                    PlayerBillboards[player] = nil
                end
                if connection then
                    connection:Disconnect()
                end
            end
        end)
    end
    
    if player.Character then
        SetupESP(player.Character)
    end
    
    player.CharacterAdded:Connect(SetupESP)
end

-- Função para criar ESP de drones
local function CreateDroneESP()
    local dronesFolder = workspace:FindFirstChild("drones")
    if not dronesFolder then return end
    
    for _, drone in pairs(dronesFolder:GetChildren()) do
        if not DroneHighlights[drone] then
            local highlight = Instance.new("Highlight")
            highlight.Name = "DroneESP"
            highlight.Adornee = drone
            highlight.Parent = drone
            highlight.FillTransparency = 1
            highlight.OutlineColor = Color3.new(0, 1, 0) -- Verde
            highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
            
            local head = drone:FindFirstChild("Head") or drone:FindFirstChildWhichIsA("BasePart")
            if head then
                local billboard = Instance.new("BillboardGui")
                billboard.Name = "DroneNameESP"
                billboard.Adornee = head
                billboard.Size = UDim2.new(0, 150, 0, 30)
                billboard.StudsOffset = Vector3.new(0, 2, 0)
                billboard.AlwaysOnTop = true
                billboard.MaxDistance = 80
                billboard.Parent = drone
                
                local textLabel = Instance.new("TextLabel")
                textLabel.Name = "DroneName"
                textLabel.Size = UDim2.new(1, 0, 1, 0)
                textLabel.BackgroundTransparency = 1
                textLabel.Text = "Drone"
                textLabel.TextColor3 = Color3.new(0, 1, 0)
                textLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
                textLabel.TextStrokeTransparency = 0
                textLabel.TextSize = 16
                textLabel.Font = Enum.Font.GothamBold
                textLabel.Parent = billboard
            end
            
            DroneHighlights[drone] = highlight
            end
        end
    end
    
-- Função para limpar todo o ESP
local function CleanupESP()
    for player, highlight in pairs(PlayerHighlights) do
        if highlight then highlight:Destroy() end
    end
    for player, billboard in pairs(PlayerBillboards) do
        if billboard then billboard:Destroy() end
    end
    for drone, highlight in pairs(DroneHighlights) do
        if highlight then highlight:Destroy() end
    end
    
    PlayerHighlights = {}
    PlayerBillboards = {}
    DroneHighlights = {}
    
    for _, connection in pairs(ESPConnections) do
        if connection then connection:Disconnect() end
    end
    ESPConnections = {}
    
    for _, connection in pairs(MainESPConnections) do
        if connection then connection:Disconnect() end
    end
    MainESPConnections = {}
end

-- Função para ativar ESP
local function EnableESP()
    if ESPEnabled then return end
    ESPEnabled = true
    
    -- Cria ESP para todos os jogadores
    for _, player in pairs(Players:GetPlayers()) do
        CreatePlayerESP(player)
    end
    
    -- Cria ESP para drones
    CreateDroneESP()
    
    -- Monitora novos jogadores
    local playerAddedConnection = Players.PlayerAdded:Connect(function(player)
        CreatePlayerESP(player)
    end)
    table.insert(MainESPConnections, playerAddedConnection)
    
    -- Limpa quando jogador sai
    local playerRemovingConnection = Players.PlayerRemoving:Connect(function(player)
        if PlayerHighlights[player] then
            PlayerHighlights[player]:Destroy()
            PlayerHighlights[player] = nil
        end
        if PlayerBillboards[player] then
            PlayerBillboards[player]:Destroy()
            PlayerBillboards[player] = nil
        end
    end)
    table.insert(MainESPConnections, playerRemovingConnection)
    
    -- Monitora drones
    local droneConnection = RunService.Heartbeat:Connect(function()
        if ESPEnabled then
            CreateDroneESP()
        else
            if droneConnection then droneConnection:Disconnect() end
        end
    end)
    table.insert(MainESPConnections, droneConnection)
    
    -- Monitora quando pasta de drones é criada
    local dronesConnection = workspace.ChildAdded:Connect(function(child)
        if child.Name == "drones" then
            CreateDroneESP()
        end
    end)
    table.insert(MainESPConnections, dronesConnection)
end

-- Função para desativar ESP
local function DisableESP()
    if not ESPEnabled then return end
    ESPEnabled = false
    CleanupESP()
end

-- Cria a janela principal
local Window = Fluent:CreateWindow({
    Title = "Omega Cheats",
    SubTitle = "by Keller",
    TabWidth = 160,
    Size = UDim2.fromOffset(580, 460),
    Acrylic = false,
    Theme = "Dark",
    MinimizeKey = Enum.KeyCode.RightControl
})

-- Cria as tabs
local Tabs = {
    Visuals = Window:AddTab({ Title = "Visuals", Icon = "eye" }),
    Settings = Window:AddTab({ Title = "Settings", Icon = "settings" }),
    Config = Window:AddTab({ Title = "Config", Icon = "save" })
}

-- Configuração do SaveManager e InterfaceManager
do
    SaveManager:SetLibrary(Fluent)
    InterfaceManager:SetLibrary(Fluent)
    SaveManager:IgnoreThemeSettings()
    SaveManager:SetIgnoreIndexes({})
    InterfaceManager:SetFolder("OmegaCheats")
    SaveManager:SetFolder("OmegaCheats/configs")
    
    InterfaceManager:BuildInterfaceSection(Tabs.Config)
    SaveManager:BuildConfigSection(Tabs.Config)
end

-- Tab Visuals - ESP
do
    local ESPSection = Tabs.Visuals:AddSection("ESP")
    
    local ESPToggle = ESPSection:AddToggle("ESPEnabled", {
        Title = "Enable ESP",
        Default = false
    })
    
    ESPToggle:OnChanged(function(value)
        if value then
            EnableESP()
        else
        DisableESP()
    end
end)
end

-- Seleciona a primeira tab
Window:SelectTab(1)

-- Notificação de carregamento
Fluent:Notify({
    Title = "Omega Panel",
    Content = "Painel carregado com sucesso!",
    Duration = 5
})
