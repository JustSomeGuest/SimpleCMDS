local Players = GetService("Players")
local RunService = GetService("RunService")

local AntiFlingActive = false
local AntiflingConn
local AntiflingPlayerConn
local LocalCharacterConn

local MaxLinearVelocity = 100
local MaxAngularVelocity = 100

local RubberbandVelocity = 150

local PlayerConnections = {}
local CharacterParts = {}
local OriginalCanCollide = {}

local LastSafeCFrame
local LastSafeTime = 0
local CurrentCharacter

local function Disconnect(Connection)
    if Connection then
        Connection:Disconnect()
    end
end

local function ClampVelocity(Part)
    if not Part or not Part.Parent then
        return
    end

    local LinearVelocity = Part.AssemblyLinearVelocity
    local LinearMagnitude = LinearVelocity.Magnitude

    if LinearMagnitude > MaxLinearVelocity then
        Part.AssemblyLinearVelocity =
            LinearVelocity * (MaxLinearVelocity / LinearMagnitude)
    end

    local AngularVelocity = Part.AssemblyAngularVelocity
    local AngularMagnitude = AngularVelocity.Magnitude

    if AngularMagnitude > MaxAngularVelocity then
        Part.AssemblyAngularVelocity =
            AngularVelocity * (MaxAngularVelocity / AngularMagnitude)
    end
end

local function TrackPart(Part)
    if not Part:IsA("BasePart") or CharacterParts[Part] then
        return
    end

    CharacterParts[Part] = true
    OriginalCanCollide[Part] = Part.CanCollide

    if Part.CanCollide then
        Part.CanCollide = false
    end
end

local function UntrackPart(Part)
    CharacterParts[Part] = nil
    OriginalCanCollide[Part] = nil
end

local function SetupCharacter(Character)
    if not Character then
        return
    end

    for _, Instance in ipairs(Character:GetDescendants()) do
        if Instance:IsA("BasePart") then
            TrackPart(Instance)
        end
    end

    local AddedConnection = Character.DescendantAdded:Connect(function(Instance)
        if AntiFlingActive and Instance:IsA("BasePart") then
            TrackPart(Instance)
        end
    end)

    local RemovingConnection = Character.DescendantRemoving:Connect(function(Instance)
        if Instance:IsA("BasePart") then
            UntrackPart(Instance)
        end
    end)

    PlayerConnections[Character] = {
        AddedConnection,
        RemovingConnection
    }
end

local function CleanupCharacter(Character)
    local Connections = PlayerConnections[Character]

    if Connections then
        for _, Connection in ipairs(Connections) do
            Disconnect(Connection)
        end

        PlayerConnections[Character] = nil
    end

    for Part in pairs(CharacterParts) do
        if not Part.Parent or Part:IsDescendantOf(Character) then
            UntrackPart(Part)
        end
    end
end

local function SetupPlayer(Player)
    if Player == Plr then
        return
    end

    if Player.Character then
        SetupCharacter(Player.Character)
    end

    local CharacterAddedConnection = Player.CharacterAdded:Connect(function(Character)
        if AntiFlingActive then
            SetupCharacter(Character)
        end
    end)

    local CharacterRemovingConnection = Player.CharacterRemoving:Connect(function(Character)
        CleanupCharacter(Character)
    end)

    PlayerConnections[Player] = {
        CharacterAddedConnection,
        CharacterRemovingConnection
    }
end

local function SetupLocalCharacter()
    CurrentCharacter = Plr.Character
    LastSafeCFrame = nil
    LastSafeTime = 0

    local Character = CurrentCharacter

    if not Character then
        return
    end

    local RootPart = Character:FindFirstChild("HumanoidRootPart")

    if RootPart and RootPart:IsA("BasePart") then
        LastSafeCFrame = RootPart.CFrame
        LastSafeTime = os.clock()
    end
end

local function RubberbandCharacter(RootPart)
    if not RootPart or not RootPart.Parent or not LastSafeCFrame then
        return
    end

    RootPart.CFrame = LastSafeCFrame
    RootPart.AssemblyLinearVelocity = Vector3.zero
    RootPart.AssemblyAngularVelocity = Vector3.zero
end

local function CheckLocalCharacter()
    local Character = Plr.Character

    if not Character then
        CurrentCharacter = nil
        LastSafeCFrame = nil
        LastSafeTime = 0
        return
    end

    if Character ~= CurrentCharacter then
        CurrentCharacter = Character
        LastSafeCFrame = nil
        LastSafeTime = 0
    end

    local RootPart = Character:FindFirstChild("HumanoidRootPart")

    if not RootPart or not RootPart:IsA("BasePart") then
        return
    end

    if not LastSafeCFrame then
        LastSafeCFrame = RootPart.CFrame
        LastSafeTime = os.clock()
        return
    end

    local Velocity = RootPart.AssemblyLinearVelocity
    local VelocityMagnitude = Velocity.Magnitude

    if VelocityMagnitude >= RubberbandVelocity then
        RubberbandCharacter(RootPart)
        return
    end

    if VelocityMagnitude <= MaxLinearVelocity then
        LastSafeCFrame = RootPart.CFrame
        LastSafeTime = os.clock()
    end
end

local function Antifling()
    if AntiFlingActive then
        Notify("AntiFling: Already active")
        return
    end

    AntiFlingActive = true

    SetupLocalCharacter()

    for _, Player in ipairs(Players:GetPlayers()) do
        SetupPlayer(Player)
    end

    AntiflingPlayerConn = Players.PlayerAdded:Connect(function(Player)
        if AntiFlingActive then
            SetupPlayer(Player)
        end
    end)

    LocalCharacterConn = Plr.CharacterAdded:Connect(function()
        if AntiFlingActive then
            task.wait()
            SetupLocalCharacter()
        end
    end)

    AntiflingConn = RunService.PreSimulation:Connect(function()
        for Part in pairs(CharacterParts) do
            if Part.Parent then
                if Part.CanCollide then
                    Part.CanCollide = false
                end

                ClampVelocity(Part)
            else
                UntrackPart(Part)
            end
        end

        CheckLocalCharacter()
    end)

    Notify("AntiFling: Enabled")
end

local function Unantifling()
    if not AntiFlingActive then
        Notify("AntiFling: Not active")
        return
    end

    AntiFlingActive = false

    Disconnect(AntiflingConn)
    Disconnect(AntiflingPlayerConn)
    Disconnect(LocalCharacterConn)

    AntiflingConn = nil
    AntiflingPlayerConn = nil
    LocalCharacterConn = nil

    for Object, Connections in pairs(PlayerConnections) do
        for _, Connection in ipairs(Connections) do
            Disconnect(Connection)
        end

        PlayerConnections[Object] = nil
    end

    for Part, OriginalCanCollideValue in pairs(OriginalCanCollide) do
        if Part.Parent then
            Part.CanCollide = OriginalCanCollideValue
        end
    end

    table.clear(CharacterParts)
    table.clear(OriginalCanCollide)

    CurrentCharacter = nil
    LastSafeCFrame = nil
    LastSafeTime = 0

    Notify("AntiFling: Disabled")
end

Cmd.new(
    {"antifling", "af"},
    "Prevents your character from being flung.",
    "antifling",
    function()
        Antifling()
    end
)

Cmd.new(
    {"unantifling", "unaf"},
    "Disables anti-fling.",
    "unantifling",
    function()
        Unantifling()
    end
)