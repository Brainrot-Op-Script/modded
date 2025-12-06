local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local LocalPlayer = Players.LocalPlayer

local isTeleporting = false
local noclipEnabled = false
local noclipConn = nil

local fastStealOn = false
local fastStealLoop = nil
local fastStealConn = nil

local function getCharacter()
    local char = LocalPlayer.Character
    if not char or not char.Parent then
        char = LocalPlayer.CharacterAdded:Wait()
    end
    return char
end

local function getMyPlot()
    local plots = workspace:FindFirstChild("Plots")
    if not plots then return nil end
    for _, plot in ipairs(plots:GetChildren()) do
        local label = plot:FindFirstChild("PlotSign")
            and plot.PlotSign:FindFirstChild("SurfaceGui")
            and plot.PlotSign.SurfaceGui:FindFirstChild("Frame")
            and plot.PlotSign.SurfaceGui.Frame:FindFirstChild("TextLabel")
        if label then
            local t = (label.ContentText or label.Text or "")
            if t:find(LocalPlayer.DisplayName) and t:find("Base") then
                return plot
            end
        end
    end
    return nil
end

local function getDeliveryHitbox()
    local myPlot = getMyPlot()
    if not myPlot then return nil end
    local delivery = myPlot:FindFirstChild("DeliveryHitbox") or myPlot:FindFirstChild("DeliveryHitbox", true)
    if delivery and delivery:IsA("BasePart") then
        return delivery
    end
    return nil
end

local function setNoclip(on)
    noclipEnabled = on
    if on then
        if noclipConn then noclipConn:Disconnect() end
        noclipConn = RunService.Stepped:Connect(function()
            local char = LocalPlayer.Character
            if not char then return end
            for _, part in ipairs(char:GetDescendants()) do
                if part:IsA("BasePart") then
                    part.CanCollide = false
                end
            end
        end)
    else
        if noclipConn then
            noclipConn:Disconnect()
            noclipConn = nil
        end
        local char = LocalPlayer.Character
        if char then
            for _, part in ipairs(char:GetDescendants()) do
                if part:IsA("BasePart") then
                    part.CanCollide = true
                end
            end
        end
    end
end

local function shortTeleportFreezeCamera(targetCF, duration)
    if isTeleporting then return end
    isTeleporting = true
    duration = duration or 0.2
    if duration < 0.1 then duration = 0.1 end
    if duration > 0.5 then duration = 0.5 end
    local character = getCharacter()
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp then
        isTeleporting = false
        return
    end
    local camera = workspace.CurrentCamera
    if not camera then
        isTeleporting = false
        return
    end
    local originalCF = hrp.CFrame
    local originalCamType = camera.CameraType
    local originalCamSub = camera.CameraSubject
    local originalCamCFrame = camera.CFrame
    local function restoreCamera()
        local char = LocalPlayer.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if hum then
            camera.CameraSubject = hum
            camera.CameraType = Enum.CameraType.Custom
        else
            camera.CameraType = originalCamType or Enum.CameraType.Custom
            camera.CameraSubject = originalCamSub
        end
        camera.CFrame = originalCamCFrame
    end
    local ok = pcall(function()
        camera.CameraType = Enum.CameraType.Scriptable
        camera.CFrame = originalCamCFrame
        hrp.CFrame = targetCF
        task.wait(duration)
        hrp.CFrame = originalCF
    end)
    restoreCamera()
    isTeleporting = false
    if not ok then
        warn("[SAB UTILS] shortTeleport error")
    end
end

local function doInstantSteal()
    local character = getCharacter()
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    local delivery = getDeliveryHitbox()
    if not delivery then return end
    local targetCF = delivery.CFrame + delivery.CFrame.LookVector * 3 + Vector3.new(0, 3, 0)
    shortTeleportFreezeCamera(targetCF, 0.25)
end

local function doForwardTP()
    local character = getCharacter()
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    hrp.CFrame = hrp.CFrame + hrp.CFrame.LookVector * 8
end

local function patchPrompt(prompt)
    if not prompt:IsA("ProximityPrompt") then return end
    local ok = pcall(function()
        if prompt.HoldDuration > 0.01 then
            prompt.HoldDuration = 0.01
        end
    end)
end

local function setFastSteal(on)
    fastStealOn = on
    if on then
        task.spawn(function()
            for _, obj in ipairs(workspace:GetDescendants()) do
                if obj:IsA("ProximityPrompt") then
                    patchPrompt(obj)
                end
            end
        end)
        if not fastStealLoop then
            fastStealLoop = task.spawn(function()
                while fastStealOn do
                    local ok, err = pcall(function()
                        for _, obj in ipairs(workspace:GetDescendants()) do
                            if obj:IsA("ProximityPrompt") then
                                patchPrompt(obj)
                            end
                        end
                    end)
                    if not ok then
                        warn("[SAB UTILS] FastSteal loop error:", err)
                    end
                    task.wait(0.08)
                end
                fastStealLoop = nil
            end)
        end
        if fastStealConn then fastStealConn:Disconnect() end
        fastStealConn = workspace.DescendantAdded:Connect(function(obj)
            if fastStealOn and obj:IsA("ProximityPrompt") then
                patchPrompt(obj)
            end
        end)
    else
        if fastStealConn then
            fastStealConn:Disconnect()
            fastStealConn = nil
        end
    end
end

local function createUI()
    local guiParent = game:GetService("CoreGui")
    pcall(function()
        if gethui then
            local h = gethui()
            if h then guiParent = h end
        end
    end)
    
    local old = guiParent:FindFirstChild("SAB_Utils_UI")
    if old then old:Destroy() end
    
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "SAB_Utils_UI"
    screenGui.ResetOnSpawn = false
    screenGui.IgnoreGuiInset = true
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Global
    screenGui.Parent = guiParent
    
    screenGui.AncestryChanged:Connect(function(_, parent)
        if not parent then
            setNoclip(false)
            setFastSteal(false)
        end
    end)
    
    local mainFrame = Instance.new("Frame")
    mainFrame.Name = "MainFrame"
    mainFrame.Size = UDim2.new(0, 280, 0, 260)
    mainFrame.Position = UDim2.new(0.75, -140, 0.5, -130)
    mainFrame.BackgroundColor3 = Color3.fromRGB(15, 25, 45)
    mainFrame.BorderSizePixel = 0
    mainFrame.Visible = false
    mainFrame.Parent = screenGui
    mainFrame.ClipsDescendants = true
    
    local mainCorner = Instance.new("UICorner")
    mainCorner.CornerRadius = UDim.new(0, 16)
    mainCorner.Parent = mainFrame
    
    local mainGradient = Instance.new("UIGradient")
    mainGradient.Color = ColorSequence.new{
        ColorSequenceKeypoint.new(0.0, Color3.fromRGB(45, 20, 90)),
        ColorSequenceKeypoint.new(0.5, Color3.fromRGB(25, 15, 55)),
        ColorSequenceKeypoint.new(1.0, Color3.fromRGB(15, 25, 45))
    }
    mainGradient.Rotation = 135
    mainGradient.Parent = mainFrame
    
    local pulseEffect = Instance.new("UIStroke")
    pulseEffect.Color = Color3.fromRGB(100, 150, 255)
    pulseEffect.Thickness = 2.5
    pulseEffect.Transparency = 0.2
    pulseEffect.Parent = mainFrame
    
    -- Pulsing animation
    task.spawn(function()
        while mainFrame.Parent do
            for i = 0, 1, 0.05 do
                if not mainFrame.Parent then break end
                pulseEffect.Transparency = 0.2 + (math.sin(tick() * 3) * 0.1)
                task.wait()
            end
        end
    end)
    
    local header = Instance.new("Frame")
    header.Name = "Header"
    header.Size = UDim2.new(1, 0, 0, 50)
    header.BackgroundColor3 = Color3.fromRGB(35, 20, 75)
    header.BorderSizePixel = 0
    header.Parent = mainFrame
    
    local headerCorner = Instance.new("UICorner")
    headerCorner.CornerRadius = UDim.new(0, 16)
    headerCorner.Parent = header
    
    local headerGradient = Instance.new("UIGradient")
    headerGradient.Color = ColorSequence.new{
        ColorSequenceKeypoint.new(0, Color3.fromRGB(65, 30, 130)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(35, 20, 75))
    }
    headerGradient.Parent = header
    
    local title = Instance.new("TextLabel")
    title.BackgroundTransparency = 1
    title.Size = UDim2.new(0.7, 0, 0.6, 0)
    title.Position = UDim2.new(0, 20, 0, 8)
    title.Font = Enum.Font.GothamBlack
    title.Text = "💎 BRAINROT SCRIPTS"
    title.TextSize = 18
    title.TextColor3 = Color3.fromRGB(220, 220, 255)
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = header
    
    local subtitle = Instance.new("TextLabel")
    subtitle.BackgroundTransparency = 1
    subtitle.Size = UDim2.new(0.7, 0, 0.4, 0)
    subtitle.Position = UDim2.new(0, 20, 0, 28)
    subtitle.Font = Enum.Font.Gotham
    subtitle.Text = "YK KIYO"
    subtitle.TextSize = 13
    subtitle.TextColor3 = Color3.fromRGB(140, 180, 255)
    subtitle.TextXAlignment = Enum.TextXAlignment.Left
    subtitle.Parent = header
    
    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.new(0, 32, 0, 32)
    closeBtn.Position = UDim2.new(1, -40, 0.5, -16)
    closeBtn.BackgroundColor3 = Color3.fromRGB(240, 60, 60)
    closeBtn.Text = "❌"
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.TextSize = 18
    closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    closeBtn.Parent = header
    
    local closeCorner = Instance.new("UICorner")
    closeCorner.CornerRadius = UDim.new(0, 16)
    closeCorner.Parent = closeBtn
    
    closeBtn.MouseButton1Click:Connect(function()
        screenGui:Destroy()
    end)
    
    -- Enhanced dragging
    do
        local dragging = false
        local dragInput, dragStart, startPos
        local function update(input)
            local delta = input.Position - dragStart
            mainFrame.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + delta.X,
                startPos.Y.Scale, startPos.Y.Offset + delta.Y
            )
        end
        header.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                dragging = true
                dragStart = input.Position
                startPos = mainFrame.Position
                dragInput = input
                input.Changed:Connect(function(i)
                    if i.UserInputState == Enum.UserInputState.End then
                        dragging = false
                    end
                end)
            end
        end)
        header.InputChanged:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
                dragInput = input
            end
        end)
        UserInputService.InputChanged:Connect(function(input)
            if dragging and input == dragInput then
                update(input)
            end
        end)
    end
    
    local body = Instance.new("Frame")
    body.Size = UDim2.new(1, -24, 1, -65)
    body.Position = UDim2.new(0, 12, 0, 55)
    body.BackgroundTransparency = 1
    body.Parent = mainFrame
    
    local list = Instance.new("UIListLayout")
    list.FillDirection = Enum.FillDirection.Vertical
    list.SortOrder = Enum.SortOrder.LayoutOrder
    list.Padding = UDim.new(0, 10)
    list.Parent = body
    
    local function makeButton(text, color1, color2, textColor, onColor)
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(1, 0, 0, 42)
        btn.BackgroundColor3 = color1
        btn.AutoButtonColor = false
        btn.Font = Enum.Font.GothamBold
        btn.Text = text
        btn.TextSize = 15
        btn.TextColor3 = textColor
        btn.Parent = body
        
        local btnGradient = Instance.new("UIGradient")
        btnGradient.Color = ColorSequence.new{
            ColorSequenceKeypoint.new(0, color1),
            ColorSequenceKeypoint.new(1, color2)
        }
        btnGradient.Parent = btn
        
        local btnCorner = Instance.new("UICorner")
        btnCorner.CornerRadius = UDim.new(0, 14)
        btnCorner.Parent = btn
        
        local btnStroke = Instance.new("UIStroke")
        btnStroke.Color = Color3.fromRGB(255, 255, 255)
        btnStroke.Thickness = 1.5
        btnStroke.Transparency = 0.6
        btnStroke.Parent = btn
        
        local hoverTween = TweenService:Create(btn, TweenInfo.new(0.25), {BackgroundColor3 = onColor})
        btn.MouseEnter:Connect(function()
            hoverTween:Play()
        end)
        btn.MouseLeave:Connect(function()
            hoverTween = TweenService:Create(btn, TweenInfo.new(0.25), {BackgroundColor3 = color1})
            hoverTween:Play()
        end)
        
        return btn
    end
    
    local instantBtn = makeButton("⚡ INSTANT STEAL", Color3.fromRGB(80, 220, 255), Color3.fromRGB(40, 180, 220), 
                                 Color3.fromRGB(15, 25, 45), Color3.fromRGB(100, 240, 255))
    local forwardBtn = makeButton("🚀 TP FORWARD", Color3.fromRGB(80, 255, 120), Color3.fromRGB(40, 220, 100), 
                                  Color3.fromRGB(15, 35, 20), Color3.fromRGB(100, 255, 140))
    local noclipBtn = makeButton("👻 NOCLIP: OFF", Color3.fromRGB(200, 120, 255), Color3.fromRGB(160, 80, 220), 
                                 Color3.fromRGB(255, 255, 255), Color3.fromRGB(220, 140, 255))
    local fastBtn = makeButton("⏩ FAST STEAL: OFF", Color3.fromRGB(255, 200, 80), Color3.fromRGB(220, 160, 40), 
                               Color3.fromRGB(35, 20, 5), Color3.fromRGB(255, 220, 100))
    
    local toggleBtn = Instance.new("TextButton")
    toggleBtn.Name = "ToggleButton"
    toggleBtn.Size = UDim2.new(0, 48, 0, 48)
    toggleBtn.Position = UDim2.new(0.01, 0, 0.5, -24)
    toggleBtn.BackgroundColor3 = Color3.fromRGB(45, 20, 90)
    toggleBtn.Text = "▶"
    toggleBtn.Font = Enum.Font.GothamBold
    toggleBtn.TextSize = 22
    toggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    toggleBtn.Parent = screenGui
    
    local toggleGradient = Instance.new("UIGradient")
    toggleGradient.Color = ColorSequence.new{
        ColorSequenceKeypoint.new(0, Color3.fromRGB(75, 30, 140)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(45, 20, 90))
    }
    toggleGradient.Parent = toggleBtn
    
    local toggleCorner = Instance.new("UICorner")
    toggleCorner.CornerRadius = UDim.new(0, 24)
    toggleCorner.Parent = toggleBtn
    
    local toggleStroke = Instance.new("UIStroke")
    toggleStroke.Color = Color3.fromRGB(120, 100, 255)
    toggleStroke.Thickness = 3
    toggleStroke.Parent = toggleBtn
    
    toggleBtn.MouseButton1Click:Connect(function()
        mainFrame.Visible = not mainFrame.Visible
        toggleBtn.Text = mainFrame.Visible and "⏸" or "▶"
    end)
    
    local uiScale = Instance.new("UIScale")
    uiScale.Scale = 1
    uiScale.Parent = mainFrame
    
    local function updateScale()
        local cam = workspace.CurrentCamera
        if not cam then return end
        local vp = cam.ViewportSize
        local minSide = math.min(vp.X, vp.Y)
        uiScale.Scale = (minSide <= 720) and 0.85 or 1
    end
    updateScale()
    workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(updateScale)
    
    instantBtn.MouseButton1Click:Connect(doInstantSteal)
    forwardBtn.MouseButton1Click:Connect(doForwardTP)
    noclipBtn.MouseButton1Click:Connect(function()
        setNoclip(not noclipEnabled)
        noclipBtn.Text = noclipEnabled and "👻 NOCLIP: ON" or "👻 NOCLIP: OFF"
        local newColor = noclipEnabled and Color3.fromRGB(220, 140, 255) or Color3.fromRGB(200, 120, 255)
        TweenService:Create(noclipBtn, TweenInfo.new(0.2), {BackgroundColor3 = newColor}):Play()
    end)
    fastBtn.MouseButton1Click:Connect(function()
        setFastSteal(not fastStealOn)
        fastBtn.Text = fastStealOn and "⏩ FAST STEAL: ON" or "⏩ FAST STEAL: OFF"
        local newColor = fastStealOn and Color3.fromRGB(255, 220, 100) or Color3.fromRGB(255, 200, 80)
        TweenService:Create(fastBtn, TweenInfo.new(0.2), {BackgroundColor3 = newColor}):Play()
    end)
end

createUI()
