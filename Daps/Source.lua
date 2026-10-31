--[[
    Ethum UI Library — source
    This file IS the UI. Example.lua loads it and builds the menu.

    API
        local Library = loadstring(...)()

        local Window = Library:Window({ name, size, open })
            Window:Info({ name })                  sidebar heading ("Main", "Misc", ...)
            Window:Tab({ name, icon })             sidebar tab  -> Tab
            Window.Open(state?)                    show / hide (no argument = toggle)

        Tab:Section({ name, side = "left" | "right" })  -> Section
        Tab.Set(true)                              select this tab

        Section:Toggle  ({ name, flag, value, callback })
        Section:Slider  ({ name, flag, value, min, max, float, suffix, callback })
        Section:Dropdown({ name, flag, values, value, callback })   .Set(v)  .Refresh(values)
        Section:Textbox ({ name, flag, value, placeholder, callback })
        Section:Button  ({ name, confirm, callback })
        Section:Label   ({ name, bold, dark })                      .SetText(text)

        Library.Watermark({ text, visible, rate })  .SetText  .SetVisible  .SetRate
        Library.Notification({ name, description, type = "Normal" | "Time", time })

        Library.Flags            flag -> current value
        Library.ConfigFlags      flag -> setter function
        Library.GetConfig()      JSON string with every flag
        Library.LoadConfig(json) applies a JSON string
        Library.Unload()         removes the UI and every connection
        Library.OnUnload(fn)     run fn when the UI unloads

    Built in (no patches needed):
        * Windows / watermark can never be dragged off screen, and they
          don't stick to the edges (position = start + finger movement).
        * Watermark text refreshes right away and supports
          {game} {time} {date} {hour} {minute} {second} {ap} {month} {day}
          {year} {fps} {ping} {n}
        * Tabs are compared by reference, so two tabs can share a name.
]]

local Players            = game:GetService("Players")
local UserInputService   = game:GetService("UserInputService")
local TweenService       = game:GetService("TweenService")
local RunService         = game:GetService("RunService")
local HttpService        = game:GetService("HttpService")
local Stats              = game:GetService("Stats")
local MarketplaceService = game:GetService("MarketplaceService")

-- Running the script twice replaces the old UI instead of stacking a second one.
local Env = (getgenv and getgenv()) or _G
if type(Env.EthumLibrary) == "table" and Env.EthumLibrary.Unload then
    pcall(Env.EthumLibrary.Unload)
end

local Library = {
    Version = "1.0.0",
    Flags = {},
    ConfigFlags = {},
    Unloaded = false,
    Fps = 0,
    UnloadCallbacks = {},

    Theme = {
        Accent     = Color3.fromRGB(140, 110, 255),
        Background = Color3.fromRGB(18, 18, 20),
        Panel      = Color3.fromRGB(24, 24, 27),
        Element    = Color3.fromRGB(34, 34, 39),
        Outline    = Color3.fromRGB(48, 48, 55),
        Text       = Color3.fromRGB(235, 235, 240),
        TextDim    = Color3.fromRGB(150, 150, 162),
        Danger     = Color3.fromRGB(235, 90, 90),
    },
}

Env.EthumLibrary = Library

----------------------------------------------------------------
-- UTILITY
----------------------------------------------------------------

local Utility = { Objects = {}, Signals = {} }
Library.Utility = Utility

-- Creates an instance and applies the properties (Parent is set last).
function Utility.New(class, props)
    local Object = Instance.new(class)
    local Parent

    for key, value in pairs(props or {}) do
        if key == "Parent" then
            Parent = value
        else
            Object[key] = value
        end
    end

    if Parent then
        Object.Parent = Parent
    end

    return Object
end

-- Remembers a connection so Library.Unload() can disconnect it.
function Utility.Signal(connection)
    table.insert(Utility.Signals, connection)
    return connection
end

function Utility.Tween(object, time, props, style, direction)
    local Tween = TweenService:Create(
        object,
        TweenInfo.new(time or 0.15, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out),
        props
    )
    Tween:Play()
    return Tween
end

local New, Signal, Tween = Utility.New, Utility.Signal, Utility.Tween

local function Corner(parent, radius)
    return New("UICorner", { CornerRadius = UDim.new(0, radius or 6), Parent = parent })
end

local function Stroke(parent, color, thickness, transparency)
    return New("UIStroke", {
        Color = color,
        Thickness = thickness or 1,
        Transparency = transparency or 0,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
        Parent = parent,
    })
end

local function Pad(parent, left, right, top, bottom)
    return New("UIPadding", {
        PaddingLeft = UDim.new(0, left or 0),
        PaddingRight = UDim.new(0, right or 0),
        PaddingTop = UDim.new(0, top or 0),
        PaddingBottom = UDim.new(0, bottom or 0),
        Parent = parent,
    })
end

local function List(parent, padding, fill)
    return New("UIListLayout", {
        Padding = UDim.new(0, padding or 0),
        SortOrder = Enum.SortOrder.LayoutOrder,
        FillDirection = fill or Enum.FillDirection.Vertical,
        Parent = parent,
    })
end

-- Runs a user callback without letting an error break the UI.
local function Fire(callback, ...)
    if callback then
        local ok, err = pcall(callback, ...)

        if not ok then
            warn("[Ethum] callback error: " .. tostring(err))
        end
    end
end

----------------------------------------------------------------
-- CONTAINER + SCREEN GUI
----------------------------------------------------------------

local function GetContainer()
    if gethui then
        local ok, result = pcall(gethui)

        if ok and result then
            return result
        end
    end

    local ok = pcall(function()
        local Probe = Instance.new("Folder")
        Probe.Parent = game:GetService("CoreGui")
        Probe:Destroy()
    end)

    if ok then
        return game:GetService("CoreGui")
    end

    return Players.LocalPlayer:WaitForChild("PlayerGui")
end

Library.Parent = GetContainer()

do
    local Old = Library.Parent:FindFirstChild("EthumUI")

    if Old then
        Old:Destroy()
    end
end

local Gui = New("ScreenGui", {
    Name = "EthumUI",
    ResetOnSpawn = false,
    IgnoreGuiInset = true,
    DisplayOrder = 1,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    Parent = Library.Parent,
})

table.insert(Utility.Objects, Gui)
Library.Gui = Gui

----------------------------------------------------------------
-- FPS + WATERMARK TEXT TRIGGERS
----------------------------------------------------------------

do
    local Frames, Last = 0, os.clock()

    Signal(RunService.RenderStepped:Connect(function()
        Frames = Frames + 1

        local Now = os.clock()
        if Now - Last >= 1 then
            Library.Fps = math.floor(Frames / (Now - Last) + 0.5)
            Frames = 0
            Last = Now
        end
    end))
end

do
    local GameName

    task.spawn(function()
        local ok, info = pcall(function()
            return MarketplaceService:GetProductInfo(game.PlaceId)
        end)

        GameName = (ok and info and info.Name) or game.Name
    end)

    local function GetPing()
        local ok, value = pcall(function()
            return Stats.PerformanceStats.Ping:GetValue()
        end)

        if not ok or not value then
            ok, value = pcall(function()
                return Stats.Network.ServerStatsItem["Data Ping"]:GetValue()
            end)
        end

        return ok and math.floor(value or 0) or 0
    end

    local function Hour12()
        return tostring(tonumber(os.date("%I")))
    end

    function Utility.TextTriggers(text)
        local Triggers = {
            ["{hour}"]   = Hour12(),
            ["{minute}"] = os.date("%M"),
            ["{second}"] = os.date("%S"),
            ["{ap}"]     = os.date("%p"),
            ["{month}"]  = os.date("%b"),
            ["{day}"]    = os.date("%d"),
            ["{year}"]   = os.date("%Y"),
            ["{fps}"]    = Library.Fps,
            ["{ping}"]   = GetPing(),
            ["{time}"]   = string.format("%s:%s:%s %s", Hour12(), os.date("%M"), os.date("%S"), os.date("%p")),
            ["{date}"]   = os.date("%b. %d, %Y"),
            ["{game}"]   = GameName or game.Name,
            ["{n}"]      = "\n",
        }

        for trigger, value in pairs(Triggers) do
            -- function replacement so a "%" in a game name can't break gsub
            text = string.gsub(text, trigger, function() return tostring(value) end)
        end

        return text
    end
end

----------------------------------------------------------------
-- DRAGGING (always fully on screen, never sticks to an edge)
----------------------------------------------------------------

function Library.Dragging(holder, box)
    local Start, StartAbs, StartPos, Dragging, ActiveInput

    -- Clamps the window's top-left corner (inside its ScreenGui) so the whole
    -- window stays visible. If the window is bigger than the screen on an
    -- axis it can still be panned, so every part of it stays reachable.
    local function Fit(wanted)
        local Parent = holder.Parent
        if not Parent then return wanted end

        local Size = holder.AbsoluteSize
        local View = Parent.AbsoluteSize

        if View.X <= 0 or View.Y <= 0 then return wanted end

        local LowX,  HighX = math.min(0, View.X - Size.X), math.max(0, View.X - Size.X)
        local LowY,  HighY = math.min(0, View.Y - Size.Y), math.max(0, View.Y - Size.Y)

        return Vector2.new(
            math.clamp(wanted.X, LowX, HighX),
            math.clamp(wanted.Y, LowY, HighY)
        )
    end

    -- Pulls the window back in when the screen or the window changes size.
    local function KeepOnScreen()
        if Dragging then return end

        local Parent = holder.Parent
        if not Parent then return end

        local Current = holder.AbsolutePosition - Parent.AbsolutePosition
        local Diff = Fit(Current) - Current

        if math.abs(Diff.X) > 0.5 or math.abs(Diff.Y) > 0.5 then
            local P = holder.Position

            holder.Position = UDim2.new(
                P.X.Scale, P.X.Offset + Diff.X,
                P.Y.Scale, P.Y.Offset + Diff.Y
            )
        end
    end

    Signal(holder:GetPropertyChangedSignal("AbsoluteSize"):Connect(KeepOnScreen))

    local Camera = workspace.CurrentCamera
    if Camera then
        Signal(Camera:GetPropertyChangedSignal("ViewportSize"):Connect(KeepOnScreen))
    end

    task.defer(KeepOnScreen)

    Signal(box.InputBegan:Connect(function(input)
        if Dragging then return end -- a second finger/button can't hijack the drag

        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            Dragging = true
            ActiveInput = input
            Start = Vector2.new(input.Position.X, input.Position.Y)
            StartAbs = holder.AbsolutePosition - holder.Parent.AbsolutePosition
            StartPos = holder.Position
        end
    end))

    Signal(UserInputService.InputChanged:Connect(function(input)
        if not Dragging then return end

        if input.UserInputType == Enum.UserInputType.Touch then
            if input ~= ActiveInput then return end
        elseif input.UserInputType ~= Enum.UserInputType.MouseMovement then
            return
        end

        -- Only the finger's movement is used, so the coordinate space of the
        -- raw input doesn't matter. Always measured from where the drag
        -- started, so an edge never "sticks".
        local Delta = Vector2.new(input.Position.X, input.Position.Y) - Start
        local Wanted = Fit(StartAbs + Delta)
        local Applied = Wanted - StartAbs

        holder.Position = UDim2.new(
            StartPos.X.Scale, StartPos.X.Offset + Applied.X,
            StartPos.Y.Scale, StartPos.Y.Offset + Applied.Y
        )
    end))

    Signal(UserInputService.InputEnded:Connect(function(input)
        if not Dragging then return end

        local SameTouch = input == ActiveInput
        local SameMouse = ActiveInput.UserInputType == Enum.UserInputType.MouseButton1
            and input.UserInputType == Enum.UserInputType.MouseButton1

        if SameTouch or SameMouse then
            Dragging = false
            ActiveInput = nil
        end
    end))
end

----------------------------------------------------------------
-- WATERMARK
----------------------------------------------------------------

function Library.Watermark(cfg)
    cfg = cfg or {}

    local Theme = Library.Theme

    local Watermark = {
        Text = tostring(cfg.text or "Ethum.lol"),
        Rate = tonumber(cfg.rate) or 1,
        Clock = 0,
        Objects = {},
    }

    local Holder = New("Frame", {
        Name = "Watermark",
        Position = UDim2.fromOffset(10, 10),
        Size = UDim2.fromOffset(0, 0),
        AutomaticSize = Enum.AutomaticSize.XY,
        BackgroundColor3 = Theme.Panel,
        BorderSizePixel = 0,
        Active = true,
        Visible = cfg.visible ~= false,
        Parent = Gui,
    })
    Corner(Holder, 6)
    Stroke(Holder, Theme.Accent, 1, 0.4)
    Pad(Holder, 10, 10, 6, 6)

    local Label = New("TextLabel", {
        Size = UDim2.fromOffset(0, 0),
        AutomaticSize = Enum.AutomaticSize.XY,
        BackgroundTransparency = 1,
        Font = Enum.Font.GothamMedium,
        Text = "",
        TextSize = 12,
        TextColor3 = Theme.Text,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = Holder,
    })

    Watermark.Objects.Holder = Holder
    Watermark.Objects.Label = Label

    local function Refresh()
        Label.Text = Utility.TextTriggers(Watermark.Text)
        Watermark.Clock = 0
    end

    function Watermark.SetText(text)
        Watermark.Text = tostring(text or "")
        Refresh() -- shows right away instead of waiting for the next tick
    end

    function Watermark.SetVisible(state)
        Holder.Visible = state and true or false
    end

    function Watermark.SetRate(rate)
        Watermark.Rate = math.max(tonumber(rate) or 1, 0.05)
    end

    Signal(RunService.Heartbeat:Connect(function(delta)
        Watermark.Clock = Watermark.Clock + delta

        if Watermark.Clock >= Watermark.Rate then
            Refresh()
        end
    end))

    Library.Dragging(Holder, Holder)
    Refresh()

    return Watermark
end

----------------------------------------------------------------
-- NOTIFICATIONS (stacked top-left, under the watermark)
----------------------------------------------------------------

local NotifHolder = New("Frame", {
    Name = "Notifications",
    Position = UDim2.fromOffset(10, 44),
    Size = UDim2.fromOffset(240, 0),
    AutomaticSize = Enum.AutomaticSize.Y,
    BackgroundTransparency = 1,
    Parent = Gui,
})
List(NotifHolder, 6)

local NotifOrder = 0

function Library.Notification(cfg)
    cfg = cfg or {}

    local Theme = Library.Theme
    local Duration = math.max(tonumber(cfg.time) or 5, 0.5)

    NotifOrder = NotifOrder + 1

    local Wrapper = New("Frame", {
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        ClipsDescendants = true,
        LayoutOrder = NotifOrder,
        Parent = NotifHolder,
    })

    local Inner = New("Frame", {
        Size = UDim2.new(1, 0, 0, 0),
        Position = UDim2.new(-1.1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundColor3 = Theme.Panel,
        BorderSizePixel = 0,
        Parent = Wrapper,
    })
    Corner(Inner, 6)
    Stroke(Inner, Theme.Outline, 1)
    List(Inner, 3)
    Pad(Inner, 10, 10, 8, 8)

    New("TextLabel", {
        Size = UDim2.new(1, 0, 0, 16),
        BackgroundTransparency = 1,
        Font = Enum.Font.GothamBold,
        Text = tostring(cfg.name or "Ethum.lol"),
        TextSize = 13,
        TextColor3 = Theme.Accent,
        TextXAlignment = Enum.TextXAlignment.Left,
        LayoutOrder = 1,
        Parent = Inner,
    })

    if cfg.description and cfg.description ~= "" then
        New("TextLabel", {
            Size = UDim2.new(1, 0, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            BackgroundTransparency = 1,
            Font = Enum.Font.GothamMedium,
            Text = tostring(cfg.description),
            TextSize = 12,
            TextColor3 = Theme.Text,
            TextWrapped = true,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextYAlignment = Enum.TextYAlignment.Top,
            LayoutOrder = 2,
            Parent = Inner,
        })
    end

    if cfg.type == "Time" then
        local Track = New("Frame", {
            Size = UDim2.new(1, 0, 0, 3),
            BackgroundColor3 = Theme.Element,
            BorderSizePixel = 0,
            LayoutOrder = 3,
            Parent = Inner,
        })
        Corner(Track, 2)

        local Fill = New("Frame", {
            Size = UDim2.new(1, 0, 1, 0),
            BackgroundColor3 = Theme.Accent,
            BorderSizePixel = 0,
            Parent = Track,
        })
        Corner(Fill, 2)

        Tween(Fill, Duration, { Size = UDim2.new(0, 0, 1, 0) }, Enum.EasingStyle.Linear)
    end

    local Notification = {}

    function Notification.Close()
        if not Wrapper.Parent then return end

        Tween(Inner, 0.25, { Position = UDim2.new(-1.1, 0, 0, 0) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)

        task.delay(0.28, function()
            if Wrapper.Parent then
                Wrapper:Destroy()
            end
        end)
    end

    Tween(Inner, 0.3, { Position = UDim2.new(0, 0, 0, 0) }, Enum.EasingStyle.Quint)

    task.delay(Duration, function()
        if not Library.Unloaded then
            Notification.Close()
        end
    end)

    return Notification
end

----------------------------------------------------------------
-- CONFIG
----------------------------------------------------------------

-- Every flag that holds a boolean / number / string.
function Library.GetConfig()
    local Data = {}

    for flag, value in pairs(Library.Flags) do
        local Kind = typeof(value)

        if Kind == "boolean" or Kind == "number" or Kind == "string" then
            Data[flag] = value
        end
    end

    return HttpService:JSONEncode(Data)
end

function Library.LoadConfig(json)
    local Data = HttpService:JSONDecode(json)

    for flag, value in pairs(Data) do
        local Set = Library.ConfigFlags[flag]

        if Set then
            local ok, err = pcall(Set, value)

            if not ok then
                warn("[Ethum] could not load '" .. tostring(flag) .. "': " .. tostring(err))
            end
        end
    end
end

----------------------------------------------------------------
-- WINDOW
----------------------------------------------------------------

function Library:Window(cfg)
    cfg = cfg or {}

    local Theme = Library.Theme
    local WindowSize = cfg.size or UDim2.fromOffset(560, 340)

    local Window = { Tabs = {}, Objects = {}, Opened = cfg.open ~= false, Current = nil }

    local Order = 0
    local function NextOrder()
        Order = Order + 1
        return Order
    end

    local Holder = New("Frame", {
        Name = "Window",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = WindowSize,
        BackgroundColor3 = Theme.Background,
        BorderSizePixel = 0,
        ClipsDescendants = true,
        Visible = Window.Opened,
        Parent = Gui,
    })
    Corner(Holder, 8)
    Stroke(Holder, Theme.Outline, 1)

    New("Frame", {
        Name = "AccentLine",
        Size = UDim2.new(1, 0, 0, 2),
        BackgroundColor3 = Theme.Accent,
        BorderSizePixel = 0,
        ZIndex = 5,
        Parent = Holder,
    })

    -- Top bar (drag handle)
    local TopBar = New("Frame", {
        Name = "TopBar",
        Size = UDim2.new(1, 0, 0, 34),
        BackgroundColor3 = Theme.Panel,
        BorderSizePixel = 0,
        Active = true,
        Parent = Holder,
    })

    New("Frame", {
        Size = UDim2.new(1, 0, 0, 1),
        Position = UDim2.new(0, 0, 1, -1),
        BackgroundColor3 = Theme.Outline,
        BorderSizePixel = 0,
        Parent = TopBar,
    })

    New("TextLabel", {
        Position = UDim2.fromOffset(12, 0),
        Size = UDim2.new(1, -56, 1, 0),
        BackgroundTransparency = 1,
        Font = Enum.Font.GothamBold,
        Text = tostring(cfg.name or "Ethum.lol"),
        TextSize = 14,
        TextColor3 = Theme.Text,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = TopBar,
    })

    local Close = New("TextButton", {
        Position = UDim2.new(1, -34, 0, 0),
        Size = UDim2.fromOffset(34, 34),
        BackgroundTransparency = 1,
        AutoButtonColor = false,
        Font = Enum.Font.GothamBold,
        Text = "x",
        TextSize = 14,
        TextColor3 = Theme.TextDim,
        Parent = TopBar,
    })

    -- Body: sidebar + content
    local Body = New("Frame", {
        Position = UDim2.fromOffset(0, 34),
        Size = UDim2.new(1, 0, 1, -34),
        BackgroundTransparency = 1,
        Parent = Holder,
    })

    local Side = New("Frame", {
        Name = "Sidebar",
        Size = UDim2.new(0, 140, 1, 0),
        BackgroundColor3 = Theme.Panel,
        BorderSizePixel = 0,
        Parent = Body,
    })

    New("Frame", {
        Size = UDim2.new(0, 1, 1, 0),
        Position = UDim2.new(1, -1, 0, 0),
        BackgroundColor3 = Theme.Outline,
        BorderSizePixel = 0,
        Parent = Side,
    })

    local SideScroll = New("ScrollingFrame", {
        Name = "Tabs",
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 0,
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        CanvasSize = UDim2.new(),
        Parent = Side,
    })
    List(SideScroll, 2)
    Pad(SideScroll, 8, 9, 6, 8)

    local Content = New("Frame", {
        Name = "Content",
        Position = UDim2.fromOffset(140, 0),
        Size = UDim2.new(1, -140, 1, 0),
        BackgroundTransparency = 1,
        Parent = Body,
    })

    Window.Objects.Holder = Holder
    Window.Objects.TopBar = TopBar
    Window.Objects.Side = Side
    Window.Objects.SideScroll = SideScroll
    Window.Objects.Content = Content

    function Window.Open(state)
        if state == nil then
            state = not Window.Opened
        end

        Window.Opened = state and true or false
        Holder.Visible = Window.Opened
    end

    Signal(Close.Activated:Connect(function()
        Window.Open(false)
    end))

    Library.Dragging(Holder, TopBar)

    -- Sidebar heading
    function Window:Info(info)
        info = info or {}

        local Label = New("TextLabel", {
            Name = "Info",
            Size = UDim2.new(1, 0, 0, 26),
            BackgroundTransparency = 1,
            Font = Enum.Font.GothamBold,
            Text = string.upper(tostring(info.name or "")),
            TextSize = 11,
            TextColor3 = Theme.TextDim,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextYAlignment = Enum.TextYAlignment.Bottom,
            LayoutOrder = NextOrder(),
            Parent = SideScroll,
        })
        Pad(Label, 6, 0, 0, 3)

        return { Objects = { Holder = Label } }
    end

    -- Sidebar tab
    function Window:Tab(info)
        info = info or {}

        local Tab = { Name = info.name, Objects = {}, Window = Window }

        local SectionOrder = 0
        local function NextSection()
            SectionOrder = SectionOrder + 1
            return SectionOrder
        end

        local Button = New("TextButton", {
            Name = "Tab",
            Size = UDim2.new(1, 0, 0, 30),
            BackgroundColor3 = Theme.Element,
            BackgroundTransparency = 1,
            AutoButtonColor = false,
            Text = "",
            LayoutOrder = NextOrder(),
            Parent = SideScroll,
        })
        Corner(Button, 6)

        local Bar = New("Frame", {
            Size = UDim2.fromOffset(3, 14),
            Position = UDim2.new(0, 0, 0.5, -7),
            BackgroundColor3 = Theme.Accent,
            BorderSizePixel = 0,
            Visible = false,
            Parent = Button,
        })
        Corner(Bar, 2)

        local Icon
        if info.icon then
            Icon = New("ImageLabel", {
                Size = UDim2.fromOffset(16, 16),
                Position = UDim2.new(0, 10, 0.5, -8),
                BackgroundTransparency = 1,
                Image = info.icon,
                ImageColor3 = Theme.TextDim,
                Parent = Button,
            })
        end

        local Name = New("TextLabel", {
            Position = UDim2.fromOffset(info.icon and 34 or 12, 0),
            Size = UDim2.new(1, -(info.icon and 40 or 18), 1, 0),
            BackgroundTransparency = 1,
            Font = Enum.Font.GothamMedium,
            Text = tostring(info.name or ""),
            TextSize = 13,
            TextColor3 = Theme.TextDim,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextTruncate = Enum.TextTruncate.AtEnd,
            Parent = Button,
        })

        local Page = New("ScrollingFrame", {
            Name = "Page",
            Size = UDim2.new(1, 0, 1, 0),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            ScrollBarThickness = 3,
            ScrollBarImageColor3 = Theme.Outline,
            ScrollingDirection = Enum.ScrollingDirection.Y,
            AutomaticCanvasSize = Enum.AutomaticSize.Y,
            CanvasSize = UDim2.new(),
            Visible = false,
            Parent = Content,
        })
        Pad(Page, 10, 10, 10, 10)

        local Row = New("Frame", {
            Size = UDim2.new(1, 0, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            BackgroundTransparency = 1,
            Parent = Page,
        })
        List(Row, 8, Enum.FillDirection.Horizontal)

        local function Column(order)
            local Frame = New("Frame", {
                Size = UDim2.new(0.5, -4, 0, 0),
                AutomaticSize = Enum.AutomaticSize.Y,
                BackgroundTransparency = 1,
                LayoutOrder = order,
                Parent = Row,
            })
            List(Frame, 8)
            return Frame
        end

        local Left, Right = Column(1), Column(2)

        Tab.Objects.Button = Button
        Tab.Objects.Page = Page
        Tab.Objects.Left = Left
        Tab.Objects.Right = Right

        local function Paint(active)
            Bar.Visible = active
            Button.BackgroundTransparency = active and 0 or 1
            Name.TextColor3 = active and Theme.Text or Theme.TextDim

            if Icon then
                Icon.ImageColor3 = active and Theme.Accent or Theme.TextDim
            end
        end

        Tab.Page = Page
        Tab.Paint = Paint

        function Tab.Set(state)
            if state == false then
                Page.Visible = false
                Paint(false)

                if Window.Current == Tab then
                    Window.Current = nil
                end

                return
            end

            for _, Other in ipairs(Window.Tabs) do
                Other.Page.Visible = (Other == Tab)
                Other.Paint(Other == Tab)
            end

            Window.Current = Tab
        end

        Signal(Button.Activated:Connect(function()
            Tab.Set(true)
        end))

        table.insert(Window.Tabs, Tab)

        ------------------------------------------------------------
        -- SECTION
        ------------------------------------------------------------

        function Tab:Section(sec)
            sec = sec or {}

            local Column = (string.lower(tostring(sec.side or "left")) == "right") and Right or Left
            local Section = { Objects = {}, Scroll = Page }

            local ElementOrder = 0
            local function NextElement()
                ElementOrder = ElementOrder + 1
                return ElementOrder
            end

            local Box = New("Frame", {
                Name = "Section",
                Size = UDim2.new(1, 0, 0, 0),
                AutomaticSize = Enum.AutomaticSize.Y,
                BackgroundColor3 = Theme.Panel,
                BorderSizePixel = 0,
                LayoutOrder = NextSection(),
                Parent = Column,
            })
            Corner(Box, 6)
            Stroke(Box, Theme.Outline, 1)
            List(Box, 0)

            local Title = New("TextLabel", {
                Size = UDim2.new(1, 0, 0, 28),
                BackgroundTransparency = 1,
                Font = Enum.Font.GothamBold,
                Text = tostring(sec.name or ""),
                TextSize = 12,
                TextColor3 = Theme.Text,
                TextXAlignment = Enum.TextXAlignment.Left,
                LayoutOrder = 0,
                Parent = Box,
            })
            Pad(Title, 10, 10, 0, 0)

            New("Frame", {
                Size = UDim2.new(1, 0, 0, 1),
                BackgroundColor3 = Theme.Outline,
                BorderSizePixel = 0,
                LayoutOrder = 1,
                Parent = Box,
            })

            local Items = New("Frame", {
                Name = "Items",
                Size = UDim2.new(1, 0, 0, 0),
                AutomaticSize = Enum.AutomaticSize.Y,
                BackgroundTransparency = 1,
                LayoutOrder = 2,
                Parent = Box,
            })
            List(Items, 8)
            Pad(Items, 10, 10, 8, 10)

            Section.Objects.Holder = Box
            Section.Objects.Items = Items

            -- TOGGLE ------------------------------------------------
            function Section:Toggle(cfg)
                cfg = cfg or {}

                local Flag = cfg.flag or cfg.name
                local Element = { Flag = Flag, Value = false }

                local Rowbutton = New("TextButton", {
                    Size = UDim2.new(1, 0, 0, 22),
                    BackgroundTransparency = 1,
                    AutoButtonColor = false,
                    Text = "",
                    LayoutOrder = NextElement(),
                    Parent = Items,
                })

                New("TextLabel", {
                    Size = UDim2.new(1, -46, 1, 0),
                    BackgroundTransparency = 1,
                    Font = Enum.Font.GothamMedium,
                    Text = tostring(cfg.name or ""),
                    TextSize = 13,
                    TextColor3 = Theme.Text,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    TextTruncate = Enum.TextTruncate.AtEnd,
                    Parent = Rowbutton,
                })

                local Switch = New("Frame", {
                    Size = UDim2.fromOffset(34, 16),
                    Position = UDim2.new(1, -34, 0.5, -8),
                    BackgroundColor3 = Theme.Element,
                    BorderSizePixel = 0,
                    Parent = Rowbutton,
                })
                Corner(Switch, 8)
                Stroke(Switch, Theme.Outline, 1)

                local Knob = New("Frame", {
                    Size = UDim2.fromOffset(12, 12),
                    Position = UDim2.new(0, 2, 0.5, -6),
                    BackgroundColor3 = Theme.TextDim,
                    BorderSizePixel = 0,
                    Parent = Switch,
                })
                Corner(Knob, 6)

                function Element.Set(value, silent)
                    value = value and true or false

                    Element.Value = value
                    Library.Flags[Flag] = value

                    Tween(Switch, 0.12, { BackgroundColor3 = value and Theme.Accent or Theme.Element })
                    Tween(Knob, 0.12, {
                        Position = value and UDim2.new(1, -14, 0.5, -6) or UDim2.new(0, 2, 0.5, -6),
                        BackgroundColor3 = value and Theme.Text or Theme.TextDim,
                    })

                    if not silent then
                        Fire(cfg.callback, value)
                    end
                end

                Signal(Rowbutton.Activated:Connect(function()
                    Element.Set(not Element.Value)
                end))

                Library.ConfigFlags[Flag] = Element.Set
                Element.Set(cfg.value == true)

                return Element
            end

            -- SLIDER ------------------------------------------------
            function Section:Slider(cfg)
                cfg = cfg or {}

                local Flag = cfg.flag or cfg.name
                local Min, Max = cfg.min or 0, cfg.max or 100
                local Step = (cfg.float and cfg.float > 0) and cfg.float or 1

                local Element = { Flag = Flag, Value = nil }

                local Rowbutton = New("TextButton", {
                    Size = UDim2.new(1, 0, 0, 36),
                    BackgroundTransparency = 1,
                    AutoButtonColor = false,
                    Text = "",
                    LayoutOrder = NextElement(),
                    Parent = Items,
                })

                New("TextLabel", {
                    Size = UDim2.new(1, -70, 0, 16),
                    BackgroundTransparency = 1,
                    Font = Enum.Font.GothamMedium,
                    Text = tostring(cfg.name or ""),
                    TextSize = 13,
                    TextColor3 = Theme.Text,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    TextTruncate = Enum.TextTruncate.AtEnd,
                    Parent = Rowbutton,
                })

                local ValueLabel = New("TextLabel", {
                    Size = UDim2.new(0, 70, 0, 16),
                    Position = UDim2.new(1, -70, 0, 0),
                    BackgroundTransparency = 1,
                    Font = Enum.Font.GothamMedium,
                    Text = "",
                    TextSize = 12,
                    TextColor3 = Theme.TextDim,
                    TextXAlignment = Enum.TextXAlignment.Right,
                    Parent = Rowbutton,
                })

                local Bar = New("Frame", {
                    Size = UDim2.new(1, 0, 0, 8),
                    Position = UDim2.new(0, 0, 0, 24),
                    BackgroundColor3 = Theme.Element,
                    BorderSizePixel = 0,
                    Parent = Rowbutton,
                })
                Corner(Bar, 4)
                Stroke(Bar, Theme.Outline, 1)

                local Fill = New("Frame", {
                    Size = UDim2.new(0, 0, 1, 0),
                    BackgroundColor3 = Theme.Accent,
                    BorderSizePixel = 0,
                    Parent = Bar,
                })
                Corner(Fill, 4)

                local function Round(value)
                    value = math.clamp(tonumber(value) or Min, Min, Max)
                    value = Min + math.floor((value - Min) / Step + 0.5) * Step
                    value = math.floor(value * 1000 + 0.5) / 1000
                    return math.clamp(value, Min, Max)
                end

                -- suffix "s" -> "5s"; suffix "%ss" -> "5s" ("%s" is replaced by the value)
                local function Display(value)
                    local Suffix = cfg.suffix

                    if not Suffix then
                        return tostring(value)
                    end

                    if string.find(Suffix, "%%s") then
                        return (string.gsub(Suffix, "%%s", tostring(value)))
                    end

                    return tostring(value) .. Suffix
                end

                function Element.Set(value, silent)
                    value = Round(value)

                    local Changed = value ~= Element.Value

                    Element.Value = value
                    Library.Flags[Flag] = value

                    local Alpha = (Max > Min) and (value - Min) / (Max - Min) or 0
                    Fill.Size = UDim2.new(Alpha, 0, 1, 0)
                    ValueLabel.Text = Display(value)

                    if Changed and not silent then
                        Fire(cfg.callback, value)
                    end
                end

                local ActiveInput

                local function FromInput(input)
                    local Width = Bar.AbsoluteSize.X
                    if Width <= 0 then return end

                    local Alpha = math.clamp((input.Position.X - Bar.AbsolutePosition.X) / Width, 0, 1)
                    Element.Set(Min + (Max - Min) * Alpha)
                end

                Signal(Rowbutton.InputBegan:Connect(function(input)
                    if ActiveInput then return end

                    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                        ActiveInput = input
                        Page.ScrollingEnabled = false -- finger drags the slider, not the page
                        FromInput(input)
                    end
                end))

                Signal(UserInputService.InputChanged:Connect(function(input)
                    if not ActiveInput then return end

                    local Same = input == ActiveInput
                    local Mouse = ActiveInput.UserInputType == Enum.UserInputType.MouseButton1
                        and input.UserInputType == Enum.UserInputType.MouseMovement

                    if Same or Mouse then
                        FromInput(input)
                    end
                end))

                Signal(UserInputService.InputEnded:Connect(function(input)
                    if not ActiveInput then return end

                    local Same = input == ActiveInput
                    local Mouse = ActiveInput.UserInputType == Enum.UserInputType.MouseButton1
                        and input.UserInputType == Enum.UserInputType.MouseButton1

                    if Same or Mouse then
                        ActiveInput = nil
                        Page.ScrollingEnabled = true
                    end
                end))

                Library.ConfigFlags[Flag] = Element.Set
                Element.Set(cfg.value or Min)

                return Element
            end

            -- DROPDOWN ----------------------------------------------
            function Section:Dropdown(cfg)
                cfg = cfg or {}

                local Flag = cfg.flag or cfg.name
                local Element = { Flag = Flag, Values = table.clone(cfg.values or {}), Value = nil }

                local Holder = New("Frame", {
                    Size = UDim2.new(1, 0, 0, 0),
                    AutomaticSize = Enum.AutomaticSize.Y,
                    BackgroundTransparency = 1,
                    LayoutOrder = NextElement(),
                    Parent = Items,
                })
                List(Holder, 4)

                New("TextLabel", {
                    Size = UDim2.new(1, 0, 0, 14),
                    BackgroundTransparency = 1,
                    Font = Enum.Font.GothamMedium,
                    Text = tostring(cfg.name or ""),
                    TextSize = 12,
                    TextColor3 = Theme.TextDim,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    LayoutOrder = 0,
                    Parent = Holder,
                })

                local Head = New("TextButton", {
                    Size = UDim2.new(1, 0, 0, 26),
                    BackgroundColor3 = Theme.Element,
                    BorderSizePixel = 0,
                    AutoButtonColor = false,
                    Text = "",
                    LayoutOrder = 1,
                    Parent = Holder,
                })
                Corner(Head, 5)
                Stroke(Head, Theme.Outline, 1)

                local Current = New("TextLabel", {
                    Position = UDim2.fromOffset(8, 0),
                    Size = UDim2.new(1, -30, 1, 0),
                    BackgroundTransparency = 1,
                    Font = Enum.Font.GothamMedium,
                    Text = "",
                    TextSize = 12,
                    TextColor3 = Theme.Text,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    TextTruncate = Enum.TextTruncate.AtEnd,
                    Parent = Head,
                })

                local Arrow = New("TextLabel", {
                    Position = UDim2.new(1, -22, 0, 0),
                    Size = UDim2.new(0, 20, 1, 0),
                    BackgroundTransparency = 1,
                    Font = Enum.Font.GothamBold,
                    Text = ">",
                    TextSize = 12,
                    TextColor3 = Theme.TextDim,
                    Rotation = 90,
                    Parent = Head,
                })

                local Options = New("Frame", {
                    Size = UDim2.new(1, 0, 0, 0),
                    AutomaticSize = Enum.AutomaticSize.Y,
                    BackgroundColor3 = Theme.Background,
                    BorderSizePixel = 0,
                    Visible = false,
                    LayoutOrder = 2,
                    Parent = Holder,
                })
                Corner(Options, 5)
                Stroke(Options, Theme.Outline, 1)
                List(Options, 0)

                local Buttons = {}

                local function SetOpen(state)
                    Options.Visible = state
                    Arrow.Rotation = state and -90 or 90
                end

                local function Paint()
                    for _, Entry in ipairs(Buttons) do
                        Entry.Button.TextColor3 = (Entry.Value == Element.Value) and Theme.Accent or Theme.Text
                    end
                end

                local function Build()
                    for _, Entry in ipairs(Buttons) do
                        Entry.Button:Destroy()
                    end

                    table.clear(Buttons)

                    for index, value in ipairs(Element.Values) do
                        local Option = New("TextButton", {
                            Size = UDim2.new(1, 0, 0, 24),
                            BackgroundTransparency = 1,
                            AutoButtonColor = false,
                            Font = Enum.Font.GothamMedium,
                            Text = tostring(value),
                            TextSize = 12,
                            TextColor3 = Theme.Text,
                            TextXAlignment = Enum.TextXAlignment.Left,
                            TextTruncate = Enum.TextTruncate.AtEnd,
                            LayoutOrder = index,
                            Parent = Options,
                        })
                        Pad(Option, 8, 8, 0, 0)

                        Option.Activated:Connect(function()
                            Element.Set(value)
                            SetOpen(false)
                        end)

                        table.insert(Buttons, { Button = Option, Value = value })
                    end
                end

                function Element.Set(value, silent)
                    Element.Value = value
                    Library.Flags[Flag] = value

                    Current.Text = (value ~= nil) and tostring(value) or "-"
                    Paint()

                    if not silent then
                        Fire(cfg.callback, value)
                    end
                end

                -- Replaces the list; keeps the selection if it still exists.
                function Element.Refresh(values)
                    Element.Values = table.clone(values or {})
                    Build()

                    local Found = false

                    for _, value in ipairs(Element.Values) do
                        if value == Element.Value then
                            Found = true
                            break
                        end
                    end

                    if Found then
                        Paint()
                    else
                        Element.Set(Element.Values[1])
                    end
                end

                Signal(Head.Activated:Connect(function()
                    SetOpen(not Options.Visible)
                end))

                Build()
                Library.ConfigFlags[Flag] = Element.Set

                if cfg.value ~= nil then
                    Element.Set(cfg.value)
                else
                    Element.Set(Element.Values[1])
                end

                return Element
            end

            -- TEXTBOX -----------------------------------------------
            function Section:Textbox(cfg)
                cfg = cfg or {}

                local Flag = cfg.flag or cfg.name
                local Element = { Flag = Flag, Value = "" }

                local Box = New("TextBox", {
                    Size = UDim2.new(1, 0, 0, 26),
                    BackgroundColor3 = Theme.Element,
                    BorderSizePixel = 0,
                    Font = Enum.Font.GothamMedium,
                    Text = "",
                    TextSize = 12,
                    TextColor3 = Theme.Text,
                    PlaceholderText = tostring(cfg.placeholder or cfg.name or ""),
                    PlaceholderColor3 = Theme.TextDim,
                    ClearTextOnFocus = false,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    LayoutOrder = NextElement(),
                    Parent = Items,
                })
                Corner(Box, 5)
                Stroke(Box, Theme.Outline, 1)
                Pad(Box, 8, 8, 0, 0)

                -- The flag follows the text live, so a button pressed right
                -- after typing already sees the new value.
                Signal(Box:GetPropertyChangedSignal("Text"):Connect(function()
                    Element.Value = Box.Text
                    Library.Flags[Flag] = Box.Text
                end))

                Signal(Box.FocusLost:Connect(function()
                    Fire(cfg.callback, Box.Text)
                end))

                function Element.Set(value, silent)
                    value = tostring(value or "")

                    Box.Text = value
                    Element.Value = value
                    Library.Flags[Flag] = value

                    if not silent then
                        Fire(cfg.callback, value)
                    end
                end

                Library.ConfigFlags[Flag] = Element.Set
                Element.Set(cfg.value or "")

                return Element
            end

            -- BUTTON ------------------------------------------------
            function Section:Button(cfg)
                cfg = cfg or {}

                local Name = tostring(cfg.name or "")
                local Element = {}
                local Armed = false

                local Press = New("TextButton", {
                    Size = UDim2.new(1, 0, 0, 26),
                    BackgroundColor3 = Theme.Element,
                    BorderSizePixel = 0,
                    AutoButtonColor = false,
                    Font = Enum.Font.GothamMedium,
                    Text = Name,
                    TextSize = 12,
                    TextColor3 = Theme.Text,
                    TextTruncate = Enum.TextTruncate.AtEnd,
                    LayoutOrder = NextElement(),
                    Parent = Items,
                })
                Corner(Press, 5)
                Stroke(Press, Theme.Outline, 1)

                local function Reset()
                    Armed = false
                    Press.Text = Name
                    Press.TextColor3 = Theme.Text
                end

                Signal(Press.Activated:Connect(function()
                    -- confirm = true: first press arms the button, second one fires it
                    if cfg.confirm and not Armed then
                        Armed = true
                        Press.Text = "confirm: " .. Name
                        Press.TextColor3 = Theme.Danger

                        task.delay(3, function()
                            if Armed and Press.Parent then
                                Reset()
                            end
                        end)

                        return
                    end

                    Reset()

                    Press.BackgroundColor3 = Theme.Outline
                    Tween(Press, 0.25, { BackgroundColor3 = Theme.Element })

                    Fire(cfg.callback)
                end))

                Element.Objects = { Button = Press }

                return Element
            end

            -- LABEL -------------------------------------------------
            function Section:Label(cfg)
                cfg = cfg or {}

                local Element = {}

                local Text = New("TextLabel", {
                    Size = UDim2.new(1, 0, 0, 14),
                    AutomaticSize = Enum.AutomaticSize.Y,
                    BackgroundTransparency = 1,
                    Font = cfg.bold and Enum.Font.GothamBold or Enum.Font.GothamMedium,
                    Text = tostring(cfg.name or ""),
                    TextSize = 12,
                    TextColor3 = cfg.dark and Theme.TextDim or Theme.Text,
                    TextWrapped = true,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    TextYAlignment = Enum.TextYAlignment.Top,
                    LayoutOrder = NextElement(),
                    Parent = Items,
                })

                function Element.SetText(text)
                    Text.Text = tostring(text or "")
                end

                Element.Objects = { Label = Text }

                return Element
            end

            return Section
        end

        -- The first tab you create is selected automatically.
        if not Window.Current then
            Tab.Set(true)
        end

        return Tab
    end

    return Window
end

----------------------------------------------------------------
-- UNLOAD
----------------------------------------------------------------

function Library.OnUnload(callback)
    table.insert(Library.UnloadCallbacks, callback)
end

function Library.Unload()
    if Library.Unloaded then return end
    Library.Unloaded = true

    for _, Callback in ipairs(Library.UnloadCallbacks) do
        pcall(Callback)
    end

    for _, Connection in ipairs(Utility.Signals) do
        pcall(function() Connection:Disconnect() end)
    end

    for _, Object in ipairs(Utility.Objects) do
        pcall(function() Object:Destroy() end)
    end

    table.clear(Utility.Signals)
    table.clear(Utility.Objects)

    if Env.EthumLibrary == Library then
        Env.EthumLibrary = nil
    end
end

return Library, Utility
