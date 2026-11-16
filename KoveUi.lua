-- Kova UI Library
local KovaUI = {}

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local LP = Players.LocalPlayer

-- 主题颜色配置
local Theme = {
    Bg      = Color3.fromRGB(22, 22, 28),
    Panel   = Color3.fromRGB(32, 32, 40),
    Row     = Color3.fromRGB(40, 40, 48),
    RowHover= Color3.fromRGB(50, 50, 60),
    Accent  = Color3.fromRGB(120, 90, 255),
    Accent2 = Color3.fromRGB(70, 200, 255),
    White   = Color3.fromRGB(255, 255, 255),
    Stroke  = Color3.fromRGB(65, 65, 80),
}

local WIN_W, WIN_H = 420, 340
local TITLE_H, TOUCH_MIN = 40, 36
local SIDEBAR_W, ARROW_Y = 110, 10

local function new(class, props)
    local o = Instance.new(class)
    if class == "TextButton" then
        o.Text = ""
    end
    for k, v in pairs(props) do o[k] = v end
    return o
end
local function corner(p, r)
    return new("UICorner", { CornerRadius = UDim.new(0, r or 8), Parent = p })
end
local function stroke(p, c, t)
    return new("UIStroke", {
        Color = c or Theme.Stroke, Thickness = t or 1,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = p,
    })
end
local function tween(o, t, props)
    local tw = TweenService:Create(o, TweenInfo.new(t, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), props)
    tw:Play()
    return tw
end

-- ============ 图标加载与回调 ============
local iconModule, iconCache = nil, {}
local iconCallbacks = {}

task.spawn(function()
    local ok, wind = pcall(function() return _G.WindUI or WindUI end)
    if ok and wind and wind.Icons then
        iconModule = wind.Icons
    else
        pcall(function()
            local url = "https://raw.githubusercontent.com/Footagesus/Icons/main/Main-v2.lua"
            local src = game.HttpGet and game:HttpGet(url) or HttpService:GetAsync(url)
            local mod = loadstring(src)()
            mod.SetIconsType("lucide")
            iconModule = mod
        end)
    end
    for _, cb in ipairs(iconCallbacks) do
        task.spawn(cb)
    end
end)

function KovaUI:GetIcon(name)
    if iconCache[name] then return iconCache[name] end
    if not iconModule then return nil end
    local res
    pcall(function()
        if iconModule.Icon2 then res = iconModule.Icon2(name)
        elseif iconModule.Icon then res = iconModule.Icon(name) end
    end)
    if res then
        local data = { RectSize = Vector2.new(0,0), RectPos = Vector2.new(0,0) }
        if type(res) == "table" and res[1] then
            data.Image = res[1]
            if type(res[2]) == "table" then
                data.RectSize = res[2].ImageRectSize or Vector2.new(0,0)
                data.RectPos = res[2].ImageRectPosition or Vector2.new(0,0)
            end
        elseif type(res) == "string" then
            data.Image = res
        end
        if data.Image then
            iconCache[name] = data
            return data
        end
    end
    return nil
end

function KovaUI:OnIconReady(cb)
    if iconModule then task.spawn(cb) else table.insert(iconCallbacks, cb) end
end

-- ============ 核心环境 ============
local function getGuiParent()
    local ok, cg = pcall(function() return game:GetService("CoreGui") end)
    if ok and cg then
        local ok2 = pcall(function()
            local probe = Instance.new("Folder")
            probe.Parent = cg
            probe:Destroy()
        end)
        if ok2 then return cg end
    end
    return LP:WaitForChild("PlayerGui")
end
local PARENT = getGuiParent()
local OLD = PARENT:FindFirstChild("KovaUI")
if OLD then OLD:Destroy() end

local gui = new("ScreenGui", {
    Name = "KovaUI", ResetOnSpawn = false, IgnoreGuiInset = true,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 999, Parent = PARENT,
})

local scaler = new("UIScale", { Parent = gui })
local function updateScale()
    local cam = workspace.CurrentCamera
    if not cam then return end
    local vp = cam.ViewportSize
    local short = math.min(vp.X, vp.Y)
    local s = math.clamp(short / 400, 0.6, 1.25)
    s = math.min(s, (vp.X * 0.94) / WIN_W, (vp.Y * 0.90) / WIN_H)
    scaler.Scale = math.max(s, 0.45)
end
updateScale()
workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
    if workspace.CurrentCamera then
        workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)
    end
    updateScale()
end)

-- ============ 通知系统 ============
local notifHolder = new("Frame", {
    Name = "Notifications", AnchorPoint = Vector2.new(1, 0),
    Position = UDim2.new(1, -16, 0, 16), Size = UDim2.new(0, 220, 1, 0),
    BackgroundTransparency = 1, ZIndex = 500, Parent = gui,
})
local notifList = {}

local function updateNotifLayout(newCard)
    local currentY = 0
    for _, c in ipairs(notifList) do
        local realH = c.AbsoluteSize.Y / scaler.Scale
        if realH <= 1 then realH = 56 end
        local targetY = currentY
        if c == newCard then
            c.Position = UDim2.new(1, 300, 0, targetY)
            tween(c, 0.35, { Position = UDim2.new(1, 0, 0, targetY) })
        else
            tween(c, 0.35, { Position = UDim2.new(1, 0, 0, targetY) })
        end
        currentY = currentY + realH + 8
    end
end

function KovaUI:Notify(config)
    local title = config.Title or "通知"
    local text = config.Content or ""
    local duration = config.Duration or 3.5

    local card = new("Frame", {
        AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 300, 0, 0),
        Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundColor3 = Theme.Panel, BorderSizePixel = 0, ClipsDescendants = true,
        ZIndex = 501, Parent = notifHolder,
    })
    corner(card, 12)
    stroke(card, Theme.Stroke, 1)

    local textContainer = new("Frame", {
        Size = UDim2.new(1, -48, 0, 0), Position = UDim2.new(0, 12, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, ZIndex = 503, Parent = card,
    })
    new("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder, Parent = textContainer })
    new("UIPadding", { PaddingTop = UDim.new(0, 12), PaddingBottom = UDim.new(0, 18), Parent = textContainer })

    new("TextLabel", {
        Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1,
        Font = Enum.Font.GothamBold, TextSize = 13, TextColor3 = Theme.White, TextXAlignment = Enum.TextXAlignment.Left,
        TextWrapped = true, Text = title, ZIndex = 504, Parent = textContainer,
    })
    new("TextLabel", {
        Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1,
        Font = Enum.Font.Gotham, TextSize = 12, TextWrapped = true, TextColor3 = Theme.White, TextTransparency = 0.2,
        TextXAlignment = Enum.TextXAlignment.Left, Text = text, ZIndex = 504, Parent = textContainer,
    })

    local closeBtn = new("TextButton", {
        AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -8, 0, 8),
        Size = UDim2.new(0, 24, 0, 24), BackgroundTransparency = 1, ZIndex = 506, Parent = card,
    })
    local xAsset = self:GetIcon("x")
    local xImg = new("ImageLabel", {
        AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 0),
        Size = UDim2.new(0, 14, 0, 14), BackgroundTransparency = 1, ImageColor3 = Theme.White,
        ImageTransparency = 0.4, ScaleType = Enum.ScaleType.Fit, ZIndex = 507, Parent = closeBtn,
    })
    if xAsset then
        xImg.Image = xAsset.Image; xImg.ImageRectSize = xAsset.RectSize; xImg.ImageRectOffset = xAsset.RectPos
    else
        xImg.Visible = false
        new("TextLabel", { Size = UDim2.new(1,0,1,0), BackgroundTransparency = 1, Text = "X", TextColor3 = Theme.White, TextTransparency = 0.4, ZIndex = 507, Parent = closeBtn })
    end

    local progBg = new("Frame", {
        Size = UDim2.new(1, -24, 0, 3), Position = UDim2.new(0, 12, 1, -10),
        BackgroundColor3 = Theme.White, BackgroundTransparency = 0.9, ZIndex = 505, Parent = card,
    })
    corner(progBg, 2)
    local progFill = new("Frame", { Size = UDim2.new(1, 0, 1, 0), BackgroundColor3 = Theme.Accent, ZIndex = 506, Parent = progBg })
    corner(progFill, 2)

    table.insert(notifList, 1, card)
    updateNotifLayout(card)
    task.delay(0.05, function() updateNotifLayout() end)

    local isDestroyed = false
    local function destroyCard()
        if isDestroyed then return end
        isDestroyed = true
        local targetY = card.Position.Y.Offset
        local tw = TweenService:Create(card, TweenInfo.new(0.35, Enum.EasingStyle.Quart, Enum.EasingDirection.In), {
            Position = UDim2.new(1, 300, 0, targetY)
        })
        tw:Play()
        tw.Completed:Wait()
        for i, c in ipairs(notifList) do
            if c == card then table.remove(notifList, i) break end
        end
        card:Destroy()
        updateNotifLayout()
    end

    closeBtn.Activated:Connect(destroyCard)
    closeBtn.MouseEnter:Connect(function() tween(xImg, 0.1, { ImageTransparency = 0 }) end)
    closeBtn.MouseLeave:Connect(function() tween(xImg, 0.1, { ImageTransparency = 0.4 }) end)

    TweenService:Create(progFill, TweenInfo.new(duration, Enum.EasingStyle.Linear), { Size = UDim2.new(0, 0, 1, 0) }):Play()
    task.delay(duration, destroyCard)
end

-- ============ 顶部折叠箭头 ============
local arrow = new("TextButton", {
    Name = "ArrowToggle", AnchorPoint = Vector2.new(0.5, 0),
    Position = UDim2.new(0.5, 0, 0, ARROW_Y), Size = UDim2.new(0, 60, 0, 26),
    BackgroundColor3 = Theme.Panel, BackgroundTransparency = 0.35, ZIndex = 999, Parent = gui,
})
corner(arrow, 13)
stroke(arrow, Theme.Stroke, 1)

local arrowIcon = new("ImageLabel", {
    AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 0),
    Size = UDim2.new(0, 16, 0, 16), BackgroundTransparency = 1, ImageColor3 = Theme.White,
    ScaleType = Enum.ScaleType.Fit, ZIndex = 1000, Parent = arrow,
})

-- ============ 创建窗口 API ============
function KovaUI:CreateWindow(config)
    local titleText = config.Title or "脚本名称"
    local authorText = config.Author or "作者名称"

    local main = new("Frame", {
        Name = "Main", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 15),
        Size = UDim2.new(0, WIN_W, 0, WIN_H), BackgroundColor3 = Theme.Bg,
        ClipsDescendants = true, Active = true, ZIndex = 1, Parent = gui,
    })
    corner(main, 14)
    stroke(main, Theme.Stroke, 1)

    local titleBar = new("Frame", { Name = "TitleBar", Size = UDim2.new(1, 0, 0, TITLE_H), BackgroundTransparency = 1, Active = true, ZIndex = 2, Parent = main })
    local titleIcon = new("ImageLabel", {
        Position = UDim2.new(0, 12, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), Size = UDim2.new(0, 18, 0, 18),
        BackgroundTransparency = 1, ImageColor3 = Theme.White, ImageTransparency = 0.2, ScaleType = Enum.ScaleType.Fit, ZIndex = 3, Parent = titleBar,
    })
    new("TextLabel", { Position = UDim2.new(0, 38, 0.5, -7), AnchorPoint = Vector2.new(0, 0.5), Size = UDim2.new(1, -100, 0, 14), BackgroundTransparency = 1, Font = Enum.Font.GothamBold, TextSize = 13, TextColor3 = Theme.White, TextXAlignment = Enum.TextXAlignment.Left, Text = titleText, ZIndex = 3, Parent = titleBar })
    new("TextLabel", { Position = UDim2.new(0, 38, 0.5, 7), AnchorPoint = Vector2.new(0, 0.5), Size = UDim2.new(1, -100, 0, 12), BackgroundTransparency = 1, Font = Enum.Font.Gotham, TextSize = 10, TextColor3 = Theme.White, TextTransparency = 0.4, TextXAlignment = Enum.TextXAlignment.Left, Text = authorText, ZIndex = 3, Parent = titleBar })

    local maxBtn = new("TextButton", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -42, 0.5, 0), Size = UDim2.new(0, 28, 0, 28), BackgroundTransparency = 1, ZIndex = 3, Parent = titleBar })
    local maxIcon = new("ImageLabel", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 0), Size = UDim2.new(0, 16, 0, 16), BackgroundTransparency = 1, ImageColor3 = Theme.White, ImageTransparency = 0.4, ScaleType = Enum.ScaleType.Fit, ZIndex = 4, Parent = maxBtn })
    
    local closeBtn = new("TextButton", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0), Size = UDim2.new(0, 28, 0, 28), BackgroundTransparency = 1, ZIndex = 3, Parent = titleBar })
    local xIcon = new("ImageLabel", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 0), Size = UDim2.new(0, 16, 0, 16), BackgroundTransparency = 1, ImageColor3 = Theme.White, ImageTransparency = 0.4, ScaleType = Enum.ScaleType.Fit, ZIndex = 4, Parent = closeBtn })

    local isMaximized = false

    local function updateIcons()
        local xA = self:GetIcon("x")
        if xA then xIcon.Image = xA.Image; xIcon.ImageRectSize = xA.RectSize; xIcon.ImageRectOffset = xA.RectPos end
        local tA = self:GetIcon("book-open")
        if tA then titleIcon.Image = tA.Image; titleIcon.ImageRectSize = tA.RectSize; titleIcon.ImageRectOffset = tA.RectPos end
        local mA = self:GetIcon(isMaximized and "minimize" or "maximize")
        if mA then maxIcon.Image = mA.Image; maxIcon.ImageRectSize = mA.RectSize; maxIcon.ImageRectOffset = mA.RectPos end
        local aA = self:GetIcon("chevron-up")
        if aA then arrowIcon.Image = aA.Image; arrowIcon.ImageRectSize = aA.RectSize; arrowIcon.ImageRectOffset = aA.RectPos end
    end
    updateIcons()
    self:OnIconReady(updateIcons)

    closeBtn.MouseEnter:Connect(function() tween(xIcon, 0.1, { ImageColor3 = Theme.Accent2 }) end)
    closeBtn.MouseLeave:Connect(function() tween(xIcon, 0.1, { ImageColor3 = Theme.White }) end)
    maxBtn.MouseEnter:Connect(function() tween(maxIcon, 0.1, { ImageColor3 = Theme.Accent2 }) end)
    maxBtn.MouseLeave:Connect(function() tween(maxIcon, 0.1, { ImageColor3 = Theme.White }) end)

    -- 拖拽
    do
        local dragging, dragStart, startPos
        titleBar.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                dragging = true; dragStart = input.Position; startPos = main.Position
                input.Changed:Connect(function() if input.UserInputState == Enum.UserInputState.End then dragging = false end end)
            end
        end)
        UserInputService.InputChanged:Connect(function(input)
            if not dragging then return end
            if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
                local d = input.Position - dragStart
                main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
            end
        end)
        UserInputService.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then dragging = false end
        end)
    end

    -- 最大化
    maxBtn.Activated:Connect(function()
        isMaximized = not isMaximized
        tween(main, 0.25, { Size = isMaximized and UDim2.new(1, 0, 0, WIN_H) or UDim2.new(0, WIN_W, 0, WIN_H) })
        local mA = self:GetIcon(isMaximized and "minimize" or "maximize")
        if mA then maxIcon.Image = mA.Image; maxIcon.ImageRectSize = mA.RectSize; maxIcon.ImageRectOffset = mA.RectPos end
    end)

    -- 确认弹窗
    local modalOverlay = new("TextButton", { Size = UDim2.new(1, 0, 1, 0), BackgroundColor3 = Color3.new(0,0,0), BackgroundTransparency = 1, Visible = false, ClipsDescendants = true, ZIndex = 1000, Parent = main })
    corner(modalOverlay, 14)
    local modalPanel = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 0), Size = UDim2.new(0, 240, 0, 120), BackgroundColor3 = Theme.Panel, ZIndex = 1001, Parent = modalOverlay })
    corner(modalPanel, 14); stroke(modalPanel, Theme.Stroke, 1)
    local modalScale = new("UIScale", { Scale = 0.85, Parent = modalPanel })
    new("TextLabel", { Size = UDim2.new(1, -30, 1, -65), Position = UDim2.new(0, 15, 0, 15), BackgroundTransparency = 1, Font = Enum.Font.GothamMedium, TextSize = 13, TextColor3 = Theme.White, TextWrapped = true, Text = "确定要关闭 UI 吗？", TextXAlignment = Enum.TextXAlignment.Center, TextYAlignment = Enum.TextYAlignment.Center, ZIndex = 1002, Parent = modalPanel })
    
    local btnRow = new("Frame", { Size = UDim2.new(1, -30, 0, 32), Position = UDim2.new(0, 15, 1, -44), BackgroundTransparency = 1, ZIndex = 1002, Parent = modalPanel })
    
    local btnC = new("TextButton", { Size = UDim2.new(0, 80, 1, 0), BackgroundColor3 = Theme.Row, BackgroundTransparency = 0, Font = Enum.Font.GothamMedium, TextSize = 12, TextColor3 = Theme.White, Text = "取消", ZIndex = 1003, Parent = btnRow })
    corner(btnC, 8); stroke(btnC, Theme.Stroke, 1); btnC.MouseEnter:Connect(function() tween(btnC, 0.15, { BackgroundColor3 = Theme.RowHover }) end); btnC.MouseLeave:Connect(function() tween(btnC, 0.15, { BackgroundColor3 = Theme.Row }) end)
    
    local btnOk = new("TextButton", { Size = UDim2.new(0, 80, 1, 0), Position = UDim2.new(1, -80, 0, 0), BackgroundColor3 = Theme.Accent, BackgroundTransparency = 0, Font = Enum.Font.GothamMedium, TextSize = 12, TextColor3 = Theme.White, Text = "确定", ZIndex = 1003, Parent = btnRow })
    corner(btnOk, 8); stroke(btnOk, Theme.Stroke, 1); btnOk.MouseEnter:Connect(function() tween(btnOk, 0.15, { BackgroundColor3 = Theme.Accent2 }) end); btnOk.MouseLeave:Connect(function() tween(btnOk, 0.15, { BackgroundColor3 = Theme.Accent }) end)

    local function showModal() modalOverlay.Visible = true; modalScale.Scale = 0.85; tween(modalOverlay, 0.15, { BackgroundTransparency = 0.2 }); tween(modalScale, 0.15, { Scale = 1 }) end
    local function hideModal() local tw = tween(modalOverlay, 0.15, { BackgroundTransparency = 1 }); tween(modalScale, 0.15, { Scale = 0.85 }); tw.Completed:Connect(function() modalOverlay.Visible = false end) end
    btnC.Activated:Connect(hideModal); btnOk.Activated:Connect(function() gui:Destroy() end)
    closeBtn.Activated:Connect(showModal)

    -- 主体与侧栏
    local body = new("Frame", { Position = UDim2.new(0, 0, 0, TITLE_H), Size = UDim2.new(1, 0, 1, -TITLE_H), BackgroundTransparency = 1, ZIndex = 2, Parent = main })
    local sidebar = new("Frame", { Size = UDim2.new(0, SIDEBAR_W, 1, 0), BackgroundTransparency = 1, ZIndex = 2, Parent = body })
    new("UIListLayout", { Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder, Parent = sidebar })
    new("UIPadding", { PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8), PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 6), Parent = sidebar })
    local pageHolder = new("Frame", { Position = UDim2.new(0, SIDEBAR_W, 0, 2), Size = UDim2.new(1, -(SIDEBAR_W + 6), 1, -8), BackgroundColor3 = Theme.Panel, ClipsDescendants = true, ZIndex = 2, Parent = body })
    corner(pageHolder, 12)

    -- 滑动显隐逻辑
    local uiVisible = true
    local function getHiddenPos() return UDim2.new(main.Position.X.Scale, main.Position.X.Offset, 0, -main.AbsoluteSize.Y / 2 - 30) end
    local function toggleUI()
        uiVisible = not uiVisible
        local targetPos = uiVisible and UDim2.new(0.5, 0, 0.5, 15) or getHiddenPos()
        if not uiVisible then main.Position = targetPos; tween(main, 0.18, { Position = getHiddenPos() })
        else main.Position = getHiddenPos(); tween(main, 0.18, { Position = UDim2.new(0.5, 0, 0.5, 15) }) end
        local ico = self:GetIcon(uiVisible and "chevron-up" or "chevron-down")
        if ico then arrowIcon.Image = ico.Image; arrowIcon.ImageRectSize = ico.RectSize; arrowIcon.ImageRectOffset = ico.RectPos end
        tween(arrow, 0.15, { BackgroundTransparency = uiVisible and 0.35 or 0.2 })
    end

    do
        local dragging, moved, startX, startOffset = false, false, 0, 0
        arrow.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                dragging, moved, startX, startOffset = true, false, input.Position.X, arrow.Position.X.Offset
                input.Changed:Connect(function() if input.UserInputState == Enum.UserInputState.End then dragging = false; if not moved then toggleUI() end end end)
            end
        end)
        UserInputService.InputChanged:Connect(function(input)
            if not dragging then return end
            if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
                local delta = input.Position.X - startX
                if math.abs(delta) > 4 then moved = true end
                if moved then
                    local cam = workspace.CurrentCamera
                    local minX = arrow.AbsoluteSize.X / 2 / scaler.Scale + 4
                    local maxX = cam.ViewportSize.X / scaler.Scale - minX
                    arrow.Position = UDim2.new(0, math.clamp(startOffset + delta / scaler.Scale, minX, maxX), 0, ARROW_Y)
                end
            end
        end)
        UserInputService.InputEnded:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then dragging = false end end)
    end
    arrow.MouseEnter:Connect(function() if not uiVisible then tween(arrow, 0.15, { BackgroundTransparency = 0.1 }) end end)
    arrow.MouseLeave:Connect(function() if not uiVisible then tween(arrow, 0.15, { BackgroundTransparency = 0.2 }) end end)

    -- ============ 标签页与组件 API ============
    local Window = {}
    local pages, tabButtons = {}, {}
    local activePage = nil
    local tabCount = 0

    function Window:Tab(tConfig)
        local name = tConfig.Title or "Tab"
        local iconName = tConfig.Icon or "circle"
        tabCount = tabCount + 1
        local order = tabCount

        local frame = new("Frame", { Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, Visible = false, ZIndex = 2, Parent = pageHolder })
        
        local function makeColumn(xPos)
            local sf = new("ScrollingFrame", { Position = xPos, Size = UDim2.new(0.5, -8, 1, 0), BackgroundTransparency = 1, ScrollBarThickness = 2, ScrollBarImageColor3 = Theme.White, ScrollBarImageTransparency = 0.7, CanvasSize = UDim2.new(0, 0, 0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y, ZIndex = 2, Parent = frame })
            new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = sf })
            new("UIPadding", { PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 8), PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 4), Parent = sf })
            return sf
        end

        local Tab = { frame = frame, left = makeColumn(UDim2.new(0, 4, 0, 0)), right = makeColumn(UDim2.new(0.5, 2, 0, 0)) }
        pages[name] = Tab

        local function getParent(side) 
            if side == "Right" then return Tab.right 
            else return Tab.left end 
        end

        local function applyState(btnObj, isActive, isHover)
            local target = isActive and 0 or (isHover and 0.2 or 0.5)
            if btnObj.icon and btnObj.icon.Image ~= "" then tween(btnObj.icon, 0.12, { ImageTransparency = target }) end
            if btnObj.text then tween(btnObj.text, 0.12, { TextTransparency = target }) end
        end

        local btn = new("TextButton", { Size = UDim2.new(1, 0, 0, 34), LayoutOrder = order, BackgroundTransparency = 1, ZIndex = 3, Parent = sidebar })
        local img = new("ImageLabel", { Position = UDim2.new(0, 6, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), Size = UDim2.new(0, 16, 0, 16), BackgroundTransparency = 1, ImageColor3 = Theme.White, ImageTransparency = 0.5, ZIndex = 4, Parent = btn })
        local txt = new("TextLabel", { Position = UDim2.new(0, 30, 0, 0), Size = UDim2.new(1, -30, 1, 0), BackgroundTransparency = 1, Font = Enum.Font.GothamMedium, TextSize = 13, TextColor3 = Theme.White, TextTransparency = 0.5, TextXAlignment = Enum.TextXAlignment.Left, Text = name, ZIndex = 4, Parent = btn })
        
        local btnObj = { btn = btn, icon = img, text = txt }
        tabButtons[name] = btnObj

        local function updateTabIcon()
            local iA = KovaUI:GetIcon(iconName)
            if iA then img.Image = iA.Image; img.ImageRectSize = iA.RectSize; img.ImageRectOffset = iA.RectPos end
        end
        updateTabIcon()
        KovaUI:OnIconReady(updateTabIcon)

        btn.MouseEnter:Connect(function() if activePage ~= name then applyState(btnObj, false, true) end end)
        btn.MouseLeave:Connect(function() if activePage ~= name then applyState(btnObj, false, false) end end)
        btn.Activated:Connect(function()
            activePage = name
            for n, p in pairs(pages) do p.frame.Visible = (n == name) end
            for n, b in pairs(tabButtons) do applyState(b, n == name, false) end
        end)

        if not activePage then
            activePage = name; frame.Visible = true; applyState(btnObj, true, false)
        else
            frame.Visible = false; applyState(btnObj, false, false)
        end

        -- ============ 组件方法 ============

        function Tab:Section(title, side)
            new("TextLabel", { Size = UDim2.new(1, 0, 0, 16), BackgroundTransparency = 1, Font = Enum.Font.GothamBold, TextSize = 11, TextColor3 = Theme.White, TextTransparency = 0.4, TextXAlignment = Enum.TextXAlignment.Left, Text = title, ZIndex = 3, Parent = getParent(side) })
        end

        function Tab:Divider(side)
            new("Frame", { Size = UDim2.new(1, 0, 0, 1), BackgroundColor3 = Theme.Stroke, BackgroundTransparency = 0.5, ZIndex = 3, Parent = getParent(side) })
        end

        function Tab:Paragraph(config)
            local frame = new("Frame", {
                Size = UDim2.new(1, 0, 0, 0),
                AutomaticSize = Enum.AutomaticSize.Y, -- 高度自适应
                BackgroundColor3 = Theme.Bg,
                BackgroundTransparency = 0,
                ZIndex = 3,
                Parent = getParent(config.Side)
            })
            corner(frame, 8)
            stroke(frame, Theme.Stroke, 1)
            
            new("TextLabel", {
                Size = UDim2.new(1, 0, 0, 0),
                AutomaticSize = Enum.AutomaticSize.Y, -- 文本自动撑开
                BackgroundTransparency = 1,
                Font = Enum.Font.Gotham,
                TextSize = 12,
                TextColor3 = Theme.White,
                TextXAlignment = Enum.TextXAlignment.Left,
                TextYAlignment = Enum.TextYAlignment.Top,
                TextWrapped = true,
                Text = config.Content or config.Default or "",
                ZIndex = 4,
                Parent = frame
            })
            new("UIPadding", {
                PaddingTop = UDim.new(0, 8),
                PaddingBottom = UDim.new(0, 8),
                PaddingLeft = UDim.new(0, 10),
                PaddingRight = UDim.new(0, 10),
                Parent = frame
            })
            return frame
        end

        function Tab:Toggle(config)
            local title = config.Title or "Toggle"
            local default = config.Value or false
            local callback = config.Callback
            local row = new("TextButton", { Size = UDim2.new(1, 0, 0, TOUCH_MIN), BackgroundColor3 = Theme.Bg, BackgroundTransparency = 0, ZIndex = 3, Parent = getParent(config.Side) })
            corner(row, 8)
            stroke(row, Theme.Stroke, 1) 
            
            new("TextLabel", { Position = UDim2.new(0, 10, 0, 0), Size = UDim2.new(1, -56, 1, 0), BackgroundTransparency = 1, Font = Enum.Font.GothamMedium, TextSize = 12, TextColor3 = Theme.White, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Text = title, ZIndex = 4, Parent = row })
            local switch = new("Frame", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0), Size = UDim2.new(0, 36, 0, 20), BackgroundColor3 = Theme.Bg, ZIndex = 4, Parent = row })
            corner(switch, 10); stroke(switch, Theme.Stroke, 1)
            local knob = new("Frame", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 2, 0.5, 0), Size = UDim2.new(0, 16, 0, 16), BackgroundColor3 = Theme.White, ZIndex = 5, Parent = switch })
            corner(knob, 8)
            local state = false
            local function setState(v, silent)
                state = v
                tween(knob, 0.15, { Position = UDim2.new(0, state and 18 or 2, 0.5, 0), BackgroundColor3 = state and Theme.White or Theme.Stroke })
                tween(switch, 0.15, { BackgroundColor3 = state and Theme.Accent or Theme.Bg })
                if not silent and callback then pcall(callback, state) end
            end
            row.Activated:Connect(function() setState(not state) end)
            setState(default, true)
        end

        function Tab:Button(config)
            local btn = new("TextButton", { Size = UDim2.new(1, 0, 0, TOUCH_MIN), BackgroundColor3 = Theme.Bg, BackgroundTransparency = 0, Font = Enum.Font.GothamMedium, TextSize = 12, TextColor3 = Theme.White, Text = config.Title or "Button", ZIndex = 3, Parent = getParent(config.Side) })
            corner(btn, 8)
            stroke(btn, Theme.Stroke, 1)
            
            btn.MouseEnter:Connect(function() tween(btn, 0.15, { BackgroundColor3 = Theme.Accent }) end)
            btn.MouseLeave:Connect(function() tween(btn, 0.15, { BackgroundColor3 = Theme.Bg }) end)
            btn.Activated:Connect(function() if config.Callback then pcall(config.Callback) end end)
        end

        function Tab:Input(config)
            local wrap = new("Frame", { Size = UDim2.new(1, 0, 0, TOUCH_MIN), BackgroundColor3 = Theme.Bg, ZIndex = 3, Parent = getParent(config.Side) })
            corner(wrap, 8)
            stroke(wrap, Theme.Stroke, 1)
            
            -- ClipsDescendants = true 保证输入非常长的文本也不会溢出边框
            local box = new("TextBox", { 
                Size = UDim2.new(1, -16, 1, 0), 
                Position = UDim2.new(0, 8, 0, 0), 
                BackgroundTransparency = 1, 
                Font = Enum.Font.Gotham, 
                TextSize = 12, 
                TextColor3 = Theme.White, 
                PlaceholderText = config.Placeholder or "输入...", 
                PlaceholderColor3 = Theme.White, 
                Text = config.Default or "", 
                ClearTextOnFocus = false, 
                TextXAlignment = Enum.TextXAlignment.Left, 
                ClipsDescendants = true,
                ZIndex = 4, 
                Parent = wrap 
            })
            box.FocusLost:Connect(function(enter) if enter and config.Callback then pcall(config.Callback, box.Text) end end)
        end
        
        return Tab
    end

    return Window
end

return KovaUI
