--[[
    ================================================================
    Third Sub Library  -  SOURCE
    ----------------------------------------------------------------
    Host this file (GitHub raw, pastebin, your own site) and load it
    from Example.lua with:

        local Library, Utility = loadstring(game:HttpGet(URL))()

    API overview
        Library:Window({ name, size, open })
            Window:Info({ name })                       sidebar heading
            Window:Tab({ name, icon })                  sidebar tab
                Tab.Set(true)                           select a tab
                Tab:Section({ name, side, description })
                    Section:Toggle / Slider / Button / Dropdown / List
                    Section:Textbox / Label / Colorpicker / Keybind
                    Toggle:Colorpicker / Keybind        (side widgets)
                    Label:Colorpicker / Keybind
            Window.Open()                               show / hide window

        Library.Notification({ name, description, type, time })
        Library.Watermark({ text, visible, rate })
        Library.GetConfig() / Library.LoadConfig(json)
        Library.Flags / Library.ConfigFlags
        Library.Unload()

    Built in (these used to be "patches" in the example):
        * window dragging that always stays fully on screen
        * 12-hour {time}, safe {game}/{ping} watermark triggers
        * watermark refreshes immediately on load / text change
    ================================================================
]]

local UserInputService   = game:GetService("UserInputService")
local RunService         = game:GetService("RunService")
local HttpService        = game:GetService("HttpService")
local TweenService       = game:GetService("TweenService")
local GuiService         = game:GetService("GuiService")
local Stats              = game:GetService("Stats")
local MarketplaceService = game:GetService("MarketplaceService")

local Camera   = workspace.CurrentCamera
local HiddenUI = (gethui and gethui()) or game:GetService("CoreGui")

local Vertical, Horizontal = Enum.FillDirection.Vertical, Enum.FillDirection.Horizontal
local AutoY, AutoX, AutoXY = Enum.AutomaticSize.Y, Enum.AutomaticSize.X, Enum.AutomaticSize.XY
local Left, Right, Center  = Enum.HorizontalAlignment.Left, Enum.HorizontalAlignment.Right, Enum.HorizontalAlignment.Center

----------------------------------------------------------------
-- LIBRARY TABLE
----------------------------------------------------------------

local Library = {
    TweenSpeed = 0.2,
    TweenStyle = Enum.EasingStyle.Quad,

    ThemeObjects = {},

    Font     = Font.new("rbxassetid://12187365364", Enum.FontWeight.Bold),
    FontSize = 15,

    Flags       = {},
    ConfigFlags = {},
    Popups      = {},
    Dropdowns   = {}, -- kept for compatibility
    Notifications = {},

    Fps = 0,

    ScrollBar  = "rbxassetid://12776289446",
    Saturation = "rbxassetid://13901004307",
    Checkers   = "http://www.roblox.com/asset/?id=18274452449",
    KeyIcon    = "rbxassetid://81471583706380",

    KeyConverters = {
        escape = "ESC", backquote = "`", backspace = "BSP", slash = "/", leftquote = "'",
        rightquote = '"', leftbracket = "[", rightbracket = "]", semicolon = ";", comma = ",",
        period = ".", backslash = "\\", minus = "-", equals = "=", space = "SPC", ["return"] = "ENT",
        tab = "TAB", capslock = "CAP", leftshift = "LSH", rightshift = "RSH", leftcontrol = "CTRL",
        rightcontrol = "CTRL", leftalt = "ALT", rightalt = "ALT", leftsuper = "WIN", rightsuper = "WIN",
        mousebutton1 = "MB1", mousebutton2 = "MB2", mousebutton3 = "MB3", insert = "INS", delete = "DEL",
        home = "HME", pageup = "PUD", pagedown = "PDN", up = "UP", down = "DWN", left = "LFT",
        right = "RGT", numlock = "NUM",
        numpad0 = "N0", numpad1 = "N1", numpad2 = "N2", numpad3 = "N3", numpad4 = "N4",
        numpad5 = "N5", numpad6 = "N6", numpad7 = "N7", numpad8 = "N8", numpad9 = "N9",
    },

    Theme = {
        Inline = Color3.fromRGB(52, 52, 52),
        Background = Color3.fromRGB(36, 36, 36),
        ["Page Background"] = Color3.fromRGB(22, 22, 22),
        ["Section Background"] = Color3.fromRGB(30, 30, 30),
        ["Dark Background"] = Color3.fromRGB(19, 19, 19),
        Accent = Color3.fromRGB(0, 134, 229),
        ["Dark Text"] = Color3.fromRGB(120, 120, 120),
        ["Light Text"] = Color3.fromRGB(160, 160, 160),
        Text = Color3.fromRGB(220, 220, 220),
    },
}
Library.__index = Library

local Utility = { Objects = {}, Connections = {} }
Library.Utility = Utility

----------------------------------------------------------------
-- UTILITY
----------------------------------------------------------------

function Utility.New(class, props, theme)
    local Obj = Instance.new(class)

    for prop, val in pairs(props or {}) do
        Obj[prop] = val
    end

    if theme then
        Library.AddObjectTheme(Obj, theme)
    end

    table.insert(Utility.Objects, Obj)
    return Obj
end

function Utility.Signal(connection)
    table.insert(Utility.Connections, connection)
    return connection
end

function Utility.GetTransparency(obj)
    if obj:IsA("Frame") then
        return { "BackgroundTransparency" }
    elseif obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("TextBox") then
        return { "TextTransparency", "BackgroundTransparency" }
    elseif obj:IsA("ImageLabel") or obj:IsA("ImageButton") then
        return { "BackgroundTransparency", "ImageTransparency" }
    elseif obj:IsA("ScrollingFrame") then
        return { "BackgroundTransparency", "ScrollBarImageTransparency" }
    end

    return nil
end

function Utility.Round(number, float)
    local Mult = 1 / (float or 1)
    return math.floor(number * Mult + 0.5) / Mult
end

function Utility.Lerp(a, b, c)
    c = c or 1 / 8

    if math.abs(b - a) < c then
        return b
    end

    return a + (b - a) * c
end

-- Pointer position in the same space as AbsolutePosition (IgnoreGuiInset = true).
function Utility.Pointer(input)
    local Inset = GuiService:GetGuiInset()
    return Vector2.new(input.Position.X + Inset.X, input.Position.Y + Inset.Y)
end

function Utility.MouseOver(object, position)
    if not object or not object.Parent then return false end

    local Pos, Size = object.AbsolutePosition, object.AbsoluteSize

    return position.X >= Pos.X and position.Y >= Pos.Y
        and position.X <= Pos.X + Size.X and position.Y <= Pos.Y + Size.Y
end

function Utility.StringToEnum(text)
    local EnumType, EnumValue = tostring(text):match("Enum%.([^%.]+)%.(.+)")

    if EnumType and EnumValue then
        local ok, result = pcall(function() return Enum[EnumType][EnumValue] end)
        return ok and result or nil
    end

    return nil
end

-- Press / drag / release tracking for one GuiObject (mouse or a single finger).
function Utility.Track(frame, onMove, onBegin, onEnd)
    local Active, ActiveInput = false, nil

    Utility.Signal(frame.InputBegan:Connect(function(input)
        if Active then return end

        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            Active, ActiveInput = true, input

            if onBegin then onBegin(input) end
            if onMove then onMove(Utility.Pointer(input), input) end
        end
    end))

    Utility.Signal(UserInputService.InputChanged:Connect(function(input)
        if not Active then return end

        if input.UserInputType == Enum.UserInputType.Touch then
            if input ~= ActiveInput then return end
        elseif input.UserInputType ~= Enum.UserInputType.MouseMovement then
            return
        end

        if onMove then onMove(Utility.Pointer(input), input) end
    end))

    Utility.Signal(UserInputService.InputEnded:Connect(function(input)
        if not Active then return end

        local SameTouch = input == ActiveInput
        local SameMouse = ActiveInput.UserInputType == Enum.UserInputType.MouseButton1
            and input.UserInputType == Enum.UserInputType.MouseButton1

        if SameTouch or SameMouse then
            Active, ActiveInput = false, nil
            if onEnd then onEnd() end
        end
    end))
end

function Utility.GetFiles(folder, extensions)
    if not isfolder(folder) then makefolder(folder) end

    local Stored, Names = {}, {}

    for _, path in ipairs(listfiles(folder)) do
        for _, ext in ipairs(extensions) do
            if string.sub(path, -#ext) == ext then
                table.insert(Stored, path)
                table.insert(Names, (string.match(path, "([^/\\]+)$") or path):gsub(ext .. "$", ""))
            end
        end
    end

    return Stored, Names
end

do -- watermark text triggers (12-hour time, safe against odd game names)
    local GameName

    task.spawn(function()
        local ok, info = pcall(function()
            return MarketplaceService:GetProductInfo(game.PlaceId)
        end)

        GameName = (ok and info and info.Name) or game.Name
    end)

    local function GetPing()
        local ok, value = pcall(function() return Stats.PerformanceStats.Ping:GetValue() end)

        if not ok or not value then
            ok, value = pcall(function() return Stats.Network.ServerStatsItem["Data Ping"]:GetValue() end)
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
            ["{fps}"]    = Library.Fps or 0,
            ["{ping}"]   = GetPing(),
            ["{time}"]   = string.format("%s:%s:%s %s", Hour12(), os.date("%M"), os.date("%S"), os.date("%p")),
            ["{date}"]   = os.date("%b. %d, %Y"),
            ["{game}"]   = GameName or game.Name,
            ["{n}"]      = "\n",
        }

        for trigger, value in pairs(Triggers) do
            -- function replacement so a "%" in a value can't break gsub
            text = string.gsub(text, trigger, function() return tostring(value) end)
        end

        return text
    end
end

-- small builders -------------------------------------------------
local function New(class, props, theme) return Utility.New(class, props, theme) end

local function Corner(parent, radius)
    return New("UICorner", { CornerRadius = UDim.new(0, radius or 5), Parent = parent })
end

local function Pad(parent, l, r, t, b)
    return New("UIPadding", {
        PaddingLeft = UDim.new(0, l), PaddingRight = UDim.new(0, r),
        PaddingTop = UDim.new(0, t), PaddingBottom = UDim.new(0, b),
        Parent = parent,
    })
end

local function Layout(parent, gap, dir, halign)
    return New("UIListLayout", {
        FillDirection = dir or Vertical,
        SortOrder = Enum.SortOrder.LayoutOrder,
        HorizontalAlignment = halign or Left,
        Padding = UDim.new(0, gap or 0),
        Parent = parent,
    })
end

local function Label(props, theme)
    props.BackgroundTransparency = 1
    props.TextStrokeTransparency = props.TextStrokeTransparency or 0.8
    props.FontFace = Library.Font
    props.TextSize = props.TextSize or Library.FontSize
    props.TextXAlignment = props.TextXAlignment or Enum.TextXAlignment.Left
    return New("TextLabel", props, theme)
end

----------------------------------------------------------------
-- THEME / TWEEN
----------------------------------------------------------------

Library.ScreenGui = Utility.New("ScreenGui", {
    Name = "\0", DisplayOrder = 1, IgnoreGuiInset = true, ResetOnSpawn = false, Parent = HiddenUI,
})

function Library.Tween(obj, props, info)
    local Tween = TweenService:Create(obj, info or TweenInfo.new(Library.TweenSpeed, Library.TweenStyle), props)
    Tween:Play()
    return Tween
end

function Library.AddObjectTheme(object, props)
    for prop, v in pairs(props) do
        if type(v) == "string" then
            object[prop] = Library.Theme[v]
        elseif type(v) == "function" then
            object[prop] = v()
        end
    end

    Library.ThemeObjects[object] = { Props = props, Object = object }
end

function Library.ChangeObjectTheme(object, props, tweened)
    local Theme = Library.ThemeObjects[object]
    if not Theme then return end

    Theme.Props = props

    for prop, v in pairs(props) do
        if type(v) == "string" then
            if tweened then
                Theme.Tween = Library.Tween(object, { [prop] = Library.Theme[v] })
            else
                object[prop] = Library.Theme[v]
            end
        elseif type(v) == "function" then
            object[prop] = v()
        end
    end
end

function Library.UpdateTheme(name, color)
    if not Library.Theme[name] then return end

    Library.Theme[name] = color

    for _, themeobj in pairs(Library.ThemeObjects) do
        for prop, val in pairs(themeobj.Props) do
            if val == name then
                if themeobj.Tween then themeobj.Tween:Cancel() end
                themeobj.Object[prop] = color
            end
        end
    end
end

-- Fades a whole tree out / back in, remembering the original transparencies.
local Saved = setmetatable({}, { __mode = "k" })

function Library.FadeTree(root, show)
    local List = root:GetDescendants()
    table.insert(List, root)

    for _, obj in ipairs(List) do
        local Props = Utility.GetTransparency(obj)

        if Props then
            Saved[obj] = Saved[obj] or {}

            for _, prop in ipairs(Props) do
                if show then
                    local Target = Saved[obj][prop]
                    if Target ~= nil then Library.Tween(obj, { [prop] = Target }) end
                else
                    Saved[obj][prop] = obj[prop]
                    Library.Tween(obj, { [prop] = 1 })
                end
            end
        end
    end
end

-- lower-cases the user's keys and fills in defaults
function Library.Config(cfg, default)
    local Table = {}

    for name, val in pairs(cfg or {}) do
        Table[string.lower(name)] = val
    end

    for name, val in pairs(default) do
        if Table[name] == nil then
            Table[name] = val
        end
    end

    return Table
end

----------------------------------------------------------------
-- DRAGGING / RESIZING
----------------------------------------------------------------

-- Moves purely by finger/mouse delta and is clamped so the WHOLE window
-- stays on screen. No snapping: it stops at an edge and follows again as
-- soon as you drag back.
function Library.Dragging(holder, box)
    local Start, StartAbs, StartPos, Dragging, ActiveInput

    local function Fit(wanted)
        local Parent = holder.Parent
        if not Parent then return wanted end

        local Size, View = holder.AbsoluteSize, Parent.AbsoluteSize
        if View.X <= 0 or View.Y <= 0 then return wanted end

        local LowX, HighX = math.min(0, View.X - Size.X), math.max(0, View.X - Size.X)
        local LowY, HighY = math.min(0, View.Y - Size.Y), math.max(0, View.Y - Size.Y)

        return Vector2.new(math.clamp(wanted.X, LowX, HighX), math.clamp(wanted.Y, LowY, HighY))
    end

    local function KeepOnScreen()
        if Dragging then return end

        local Parent = holder.Parent
        if not Parent then return end

        local Current = holder.AbsolutePosition - Parent.AbsolutePosition
        local Diff = Fit(Current) - Current

        if math.abs(Diff.X) > 0.5 or math.abs(Diff.Y) > 0.5 then
            local P = holder.Position
            holder.Position = UDim2.new(P.X.Scale, P.X.Offset + Diff.X, P.Y.Scale, P.Y.Offset + Diff.Y)
        end
    end

    Utility.Signal(holder:GetPropertyChangedSignal("AbsoluteSize"):Connect(KeepOnScreen))

    if Camera then
        Utility.Signal(Camera:GetPropertyChangedSignal("ViewportSize"):Connect(KeepOnScreen))
    end

    task.defer(KeepOnScreen)

    Utility.Signal(box.InputBegan:Connect(function(input)
        if Dragging then return end

        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            Dragging, ActiveInput = true, input
            Start = Vector2.new(input.Position.X, input.Position.Y)
            StartAbs = holder.AbsolutePosition - holder.Parent.AbsolutePosition
            StartPos = holder.Position
        end
    end))

    Utility.Signal(UserInputService.InputChanged:Connect(function(input)
        if not Dragging then return end

        if input.UserInputType == Enum.UserInputType.Touch then
            if input ~= ActiveInput then return end
        elseif input.UserInputType ~= Enum.UserInputType.MouseMovement then
            return
        end

        local Delta = Vector2.new(input.Position.X, input.Position.Y) - Start
        local Applied = Fit(StartAbs + Delta) - StartAbs

        holder.Position = UDim2.new(
            StartPos.X.Scale, StartPos.X.Offset + Applied.X,
            StartPos.Y.Scale, StartPos.Y.Offset + Applied.Y
        )
    end))

    Utility.Signal(UserInputService.InputEnded:Connect(function(input)
        if not Dragging then return end

        local SameTouch = input == ActiveInput
        local SameMouse = ActiveInput.UserInputType == Enum.UserInputType.MouseButton1
            and input.UserInputType == Enum.UserInputType.MouseButton1

        if SameTouch or SameMouse then
            Dragging, ActiveInput = false, nil
        end
    end))
end

function Library.Resize(holder, box)
    local MinX, MinY = holder.Size.X.Offset, holder.Size.Y.Offset
    local StartPointer, StartSize

    Utility.Track(box, function(pos)
        local View = Library.ScreenGui.AbsoluteSize
        local Delta = pos - StartPointer

        holder.Size = UDim2.fromOffset(
            math.clamp(StartSize.X + Delta.X, MinX, math.max(MinX, View.X)),
            math.clamp(StartSize.Y + Delta.Y, MinY, math.max(MinY, View.Y))
        )
    end, function(input)
        StartPointer = Utility.Pointer(input)
        StartSize = holder.AbsoluteSize
    end)
end

----------------------------------------------------------------
-- POPUPS (dropdowns, keybind menu, colour picker)
----------------------------------------------------------------

function Library.MakePopup()
    local Popup = { Visible = false }

    local Outline = New("Frame", {
        Name = "Popup", Size = UDim2.fromOffset(0, 0), BorderSizePixel = 0,
        Visible = false, ClipsDescendants = true, Parent = Library.ScreenGui,
    }, { BackgroundColor3 = "Inline" })
    Corner(Outline)

    local Background = New("TextButton", {
        Size = UDim2.new(1, -2, 1, -2), Position = UDim2.fromOffset(1, 1), Text = "",
        AutoButtonColor = false, BorderSizePixel = 0, Parent = Outline,
    }, { BackgroundColor3 = "Background" })
    Corner(Background)
    Pad(Background, 5, 5, 5, 5)

    Popup.Outline = Outline
    Popup.Content = New("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0, Parent = Background })

    local Size, Place, Connection = Vector2.zero, nil, nil

    local function Reposition()
        if not Place then return end

        local Pos, View = Place(), Library.ScreenGui.AbsoluteSize

        Outline.Position = UDim2.fromOffset(
            math.clamp(Pos.X, 0, math.max(0, View.X - Size.X)),
            math.clamp(Pos.Y, 0, math.max(0, View.Y - Size.Y))
        )
    end

    -- anchor = object the popup belongs to, place() = where it should sit
    function Popup.Bind(anchor, place)
        Popup.Anchor, Place = anchor, place

        if Connection then Connection:Disconnect() end

        Connection = Utility.Signal(anchor:GetPropertyChangedSignal("AbsolutePosition"):Connect(function()
            if Popup.Visible then Reposition() end
        end))
    end

    function Popup.Show(size)
        Size = size
        Popup.Visible = true
        Outline.Visible = true
        Outline.Size = UDim2.fromOffset(size.X, 0)
        Reposition()
        Library.Tween(Outline, { Size = UDim2.fromOffset(size.X, size.Y) })
    end

    function Popup.Hide()
        if not Popup.Visible then return end

        Popup.Visible = false
        Library.Tween(Outline, { Size = UDim2.fromOffset(Size.X, 0) })

        task.delay(Library.TweenSpeed, function()
            if not Popup.Visible then Outline.Visible = false end
        end)
    end

    table.insert(Library.Popups, Popup)
    return Popup
end

-- click outside = close
Utility.Signal(UserInputService.InputBegan:Connect(function(input)
    if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
        return
    end

    local Pos = Utility.Pointer(input)

    for _, popup in ipairs(Library.Popups) do
        if popup.Visible and not Utility.MouseOver(popup.Outline, Pos)
            and not (popup.Anchor and Utility.MouseOver(popup.Anchor, Pos)) then
            popup.Hide()
        end
    end
end))

local function CloseAllPopups()
    for _, popup in ipairs(Library.Popups) do
        popup.Hide()
    end
end

----------------------------------------------------------------
-- WINDOW / INFO / TAB / SECTION
----------------------------------------------------------------

function Library.Window(self, cfg)
    cfg = Library.Config(cfg, { name = "User Interface", size = UDim2.fromOffset(560, 340), open = true })

    local Window = { Objects = {}, Visible = cfg.open, Tweening = false, Tabs = {} }
    local O = Window.Objects
    local SideWidth = 150

    O.ScreenGui = New("ScreenGui", { Name = "\0", IgnoreGuiInset = true, ResetOnSpawn = false, Parent = HiddenUI })

    O.Outline = New("Frame", {
        Name = "Outline", Size = cfg.size, BorderSizePixel = 0, Visible = Window.Visible, ClipsDescendants = true,
        Position = UDim2.new(0.5, -cfg.size.X.Offset / 2, 0.5, -cfg.size.Y.Offset / 2),
        Parent = O.ScreenGui,
    }, { BackgroundColor3 = "Page Background" })
    Corner(O.Outline)

    -- sidebar
    O.SideInline = New("Frame", { Size = UDim2.new(0, SideWidth, 1, 0), BorderSizePixel = 0, Parent = O.Outline }, { BackgroundColor3 = "Inline" })
    Corner(O.SideInline)

    O.SideBackground = New("Frame", {
        Size = UDim2.new(1, -1, 1, 0), BorderSizePixel = 0, ClipsDescendants = true, Parent = O.SideInline,
    }, { BackgroundColor3 = "Dark Background" })
    Corner(O.SideBackground)
    Pad(O.SideBackground, 5, 5, 8, 5)

    Library.Dragging(O.Outline, O.SideBackground)

    O.Title = Label({
        Size = UDim2.new(1, 0, 0, 34), Text = cfg.name, TextSize = Library.FontSize + 6,
        TextXAlignment = Enum.TextXAlignment.Center, Parent = O.SideBackground,
    }, { TextColor3 = "Text" })

    O.SideScroll = New("ScrollingFrame", {
        Size = UDim2.new(1, 0, 1, -34), Position = UDim2.fromOffset(0, 34), BackgroundTransparency = 1,
        BorderSizePixel = 0, AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(),
        BottomImage = Library.ScrollBar, MidImage = Library.ScrollBar, TopImage = Library.ScrollBar,
        ScrollBarThickness = 2, Parent = O.SideBackground,
    }, { ScrollBarImageColor3 = "Accent" })

    O.SideContent = New("Frame", {
        Size = UDim2.new(1, -6, 0, 0), AutomaticSize = AutoY, BackgroundTransparency = 1, Parent = O.SideScroll,
    })
    Layout(O.SideContent, 6)

    Window.SideHolder = O.SideContent

    -- pages
    O.PageHolder = New("Frame", {
        Size = UDim2.new(1, -SideWidth, 1, 0), Position = UDim2.fromOffset(SideWidth, 0),
        BackgroundTransparency = 1, Parent = O.Outline,
    })
    Pad(O.PageHolder, 5, 5, 5, 5)

    Window.PageHolder = O.PageHolder

    O.ResizeBar = New("TextButton", {
        Size = UDim2.fromOffset(14, 14), Position = UDim2.new(1, -14, 1, -14), BackgroundTransparency = 1,
        Text = "", AutoButtonColor = false, Parent = O.Outline,
    })
    Library.Resize(O.Outline, O.ResizeBar)

    function Window.Open()
        if Window.Tweening then return end

        CloseAllPopups()

        Window.Tweening = true
        Window.Visible = not Window.Visible

        if Window.Visible then O.Outline.Visible = true end

        Library.FadeTree(O.Outline, Window.Visible)

        task.delay(Library.TweenSpeed + 0.05, function()
            O.Outline.Visible = Window.Visible
            Window.Tweening = false
        end)
    end

    return setmetatable(Window, Library)
end

function Library.Info(self, cfg)
    cfg = Library.Config(cfg, { name = "Misc" })

    local Info = { Objects = {} }

    Info.Objects.Holder = New("Frame", {
        Size = UDim2.new(1, 0, 0, 0), AutomaticSize = AutoY, BackgroundTransparency = 1, Parent = self.SideHolder,
    })
    Pad(Info.Objects.Holder, 7, 7, 0, 0)

    Info.Objects.Text = Label({
        Text = cfg.name, TextSize = Library.FontSize - 2, Size = UDim2.new(), AutomaticSize = AutoXY,
        Parent = Info.Objects.Holder,
    }, { TextColor3 = "Dark Text" })

    return setmetatable(Info, Library)
end

function Library.Tab(self, cfg)
    cfg = Library.Config(cfg, { name = "New Tab", icon = nil })

    local Tab = { Objects = {}, Name = cfg.name }
    local O = Tab.Objects

    O.Holder = New("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = AutoY, BackgroundTransparency = 1, Parent = self.SideHolder })

    O.Background = New("TextButton", {
        Size = UDim2.new(1, 0, 0, 0), AutomaticSize = AutoY, BackgroundTransparency = 1, BorderSizePixel = 0,
        Text = "", AutoButtonColor = false, ClipsDescendants = true, Parent = O.Holder,
    }, { BackgroundColor3 = "Background" })
    Corner(O.Background)
    Pad(O.Background, 8, 8, 6, 6)

    local Row = Layout(O.Background, 7, Horizontal)
    Row.VerticalAlignment = Enum.VerticalAlignment.Center

    if cfg.icon then
        O.Icon = New("ImageLabel", {
            Size = UDim2.fromOffset(Library.FontSize + 2, Library.FontSize + 2), BackgroundTransparency = 1,
            Image = cfg.icon, Parent = O.Background,
        }, { ImageColor3 = "Dark Text" })
    end

    O.Text = Label({ Text = cfg.name, Size = UDim2.new(), AutomaticSize = AutoXY, Parent = O.Background }, { TextColor3 = "Dark Text" })

    O.Page = New("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false, Parent = self.PageHolder })

    local function Column(name, x, ox)
        local Col = New("Frame", {
            Name = name, Size = UDim2.new(0.5, -2, 1, 0), Position = UDim2.new(x, ox, 0, 0),
            BackgroundTransparency = 1, BorderSizePixel = 0, Parent = O.Page,
        })

        local L = Layout(Col, 4)
        L.VerticalFlex = Enum.UIFlexAlignment.Fill

        return Col
    end

    O.Left  = Column("Left", 0, 0)
    O.Right = Column("Right", 0.5, 2)

    Tab.left, Tab.right = O.Left, O.Right

    function Tab.Set(status)
        if status then
            for _, tab in ipairs(self.Tabs) do
                if tab ~= Tab then tab.Set(false) end
            end
        end

        Library.Tween(O.Background, { BackgroundTransparency = status and 0 or 1 })
        Library.ChangeObjectTheme(O.Text, { TextColor3 = status and "Text" or "Dark Text" }, true)

        if O.Icon then
            Library.ChangeObjectTheme(O.Icon, { ImageColor3 = status and "Text" or "Dark Text" }, true)
        end

        O.Page.Visible = status

        if status then
            O.Page.Position = UDim2.fromOffset(0, 14)
            Library.Tween(O.Page, { Position = UDim2.fromOffset(0, 0) })
        end
    end

    Utility.Signal(O.Background.MouseButton1Click:Connect(function() Tab.Set(true) end))

    table.insert(self.Tabs, Tab)

    return setmetatable(Tab, Library)
end

function Library.Section(self, cfg)
    cfg = Library.Config(cfg, { name = "New Section", description = nil, side = "left" })

    local Section = { Objects = {} }
    local O = Section.Objects

    O.Outline = New("Frame", {
        Name = "Section", BorderSizePixel = 0, Size = UDim2.fromScale(1, 0), ClipsDescendants = true,
        Parent = self[string.lower(cfg.side)],
    }, { BackgroundColor3 = "Section Background" })
    Corner(O.Outline)

    -- example: Section.Objects.Constraint.MaxSize = Vector2.new(math.huge, 90)
    O.Constraint = New("UISizeConstraint", { MinSize = Vector2.new(0, 40), Parent = O.Outline })

    local HeaderHeight = cfg.description and 38 or 22

    O.Header = New("Frame", { Size = UDim2.new(1, 0, 0, HeaderHeight), BorderSizePixel = 0, Parent = O.Outline }, { BackgroundColor3 = "Background" })
    Corner(O.Header)

    O.Cover = New("Frame", {
        Size = UDim2.new(1, 0, 0, 5), Position = UDim2.new(0, 0, 1, -5), BorderSizePixel = 0, Parent = O.Header,
    }, { BackgroundColor3 = "Background" })

    O.Line = New("Frame", {
        Size = UDim2.new(1, 0, 0, 1), Position = UDim2.fromOffset(0, HeaderHeight), BorderSizePixel = 0, Parent = O.Outline,
    }, { BackgroundColor3 = "Inline" })

    O.Title = Label({ Size = UDim2.new(1, -10, 0, 22), Position = UDim2.fromOffset(8, 0), Text = cfg.name, Parent = O.Header }, { TextColor3 = "Text" })

    if cfg.description then
        O.Description = Label({
            Size = UDim2.new(1, -10, 0, 14), Position = UDim2.fromOffset(8, 20), Text = cfg.description,
            TextSize = Library.FontSize - 2, Parent = O.Header,
        }, { TextColor3 = "Light Text" })
    end

    O.Scrolling = New("ScrollingFrame", {
        Size = UDim2.new(1, -10, 1, -(HeaderHeight + 10)), Position = UDim2.fromOffset(5, HeaderHeight + 5),
        BackgroundTransparency = 1, BorderSizePixel = 0, AutomaticCanvasSize = Enum.AutomaticSize.Y,
        CanvasSize = UDim2.new(), BottomImage = Library.ScrollBar, MidImage = Library.ScrollBar,
        TopImage = Library.ScrollBar, ScrollBarThickness = 2, Parent = O.Outline,
    }, { ScrollBarImageColor3 = "Accent" })

    O.Content = New("Frame", { Size = UDim2.new(1, -5, 0, 0), AutomaticSize = AutoY, BackgroundTransparency = 1, Parent = O.Scrolling })
    Layout(O.Content, 5)

    Section.Holder = O.Content

    return setmetatable(Section, Library)
end

----------------------------------------------------------------
-- ELEMENT ROW (label + side holder + optional description)
----------------------------------------------------------------

function Library.Row(self, cfg)
    local R = {}

    R.Holder = New("Frame", {
        Name = "Holder", Size = UDim2.new(1, 0, 0, 0), AutomaticSize = AutoY, BackgroundTransparency = 1,
        BorderSizePixel = 0, Parent = self.Holder,
    })
    Layout(R.Holder, 4)

    R.Line = New("TextButton", {
        Name = "Line", Size = UDim2.new(1, 0, 0, 0), AutomaticSize = AutoY, BackgroundTransparency = 1,
        AutoButtonColor = false, Text = "", Parent = R.Holder,
    })
    Layout(R.Line, 2)

    R.Text = Label({ Name = "Text", Size = UDim2.new(1, 0, 0, 0), AutomaticSize = AutoY, Text = cfg.name, Parent = R.Line }, { TextColor3 = "Dark Text" })
    Layout(R.Text, 4, Horizontal, Right)

    R.SideHolder = New("Frame", {
        Name = "SideHolder", Size = UDim2.new(0, 0, 1, 0), AutomaticSize = AutoX, BackgroundTransparency = 1,
        BorderSizePixel = 0, LayoutOrder = 1, Parent = R.Text,
    })
    Layout(R.SideHolder, 3, Horizontal, Right)

    if cfg.description then
        R.Description = Label({
            Name = "Description", Size = UDim2.new(1, 0, 0, 0), AutomaticSize = AutoY, Text = cfg.description,
            TextSize = Library.FontSize - 2, TextWrapped = true, Parent = R.Line,
        }, { TextColor3 = "Light Text" })
    end

    return R
end

-- boxed control (outline + inner background), returns outline, background
local function Box(class, props, parent)
    props.BorderSizePixel = 0
    props.Parent = parent
    local Outline = New(class, props, { BackgroundColor3 = "Inline" })
    Corner(Outline)

    local Background = New("Frame", { Size = UDim2.new(1, -2, 1, -2), Position = UDim2.fromOffset(1, 1), BorderSizePixel = 0, Parent = Outline }, { BackgroundColor3 = "Background" })
    Corner(Background)

    return Outline, Background
end

----------------------------------------------------------------
-- LABEL
----------------------------------------------------------------

function Library.Label(self, cfg)
    cfg = Library.Config(cfg, { name = "New Label", bold = true, dark = false })

    local LabelObj = { Objects = {} }
    local O = LabelObj.Objects

    O.Holder = New("Frame", {
        Size = UDim2.new(1, 0, 0, 0), AutomaticSize = AutoY, BackgroundTransparency = 1, BorderSizePixel = 0, Parent = self.Holder,
    })
    Layout(O.Holder, 5)

    O.Text = Label({
        Size = UDim2.new(1, 0, 0, 0), AutomaticSize = AutoY, Text = cfg.name, TextWrapped = true,
        TextSize = cfg.bold and Library.FontSize or Library.FontSize - 2, Parent = O.Holder,
    }, { TextColor3 = cfg.dark and "Light Text" or "Text" })
    Layout(O.Text, 3, Horizontal, Right)

    O.SideHolder = New("Frame", {
        Size = UDim2.new(0, 0, 1, 0), AutomaticSize = AutoX, BackgroundTransparency = 1, BorderSizePixel = 0, Parent = O.Text,
    })
    Layout(O.SideHolder, 3, Horizontal, Right)

    LabelObj.SideHolder = O.SideHolder

    function LabelObj.SetText(text) O.Text.Text = text end

    return setmetatable(LabelObj, Library)
end

----------------------------------------------------------------
-- TOGGLE
----------------------------------------------------------------

function Library.Toggle(self, cfg)
    cfg = Library.Config(cfg, { name = "New Toggle", description = nil, value = false, callback = function() end, flag = nil, children = nil })
    cfg.flag = cfg.flag or cfg.name

    local Toggle = { Objects = {}, Value = false }
    local R = Library.Row(self, cfg)
    local O = Toggle.Objects

    O.Holder, O.Line, O.Text = R.Holder, R.Line, R.Text
    Toggle.SideHolder = R.SideHolder

    local Size = Library.FontSize + 1
    O.Outline, O.Background = Box("Frame", { Size = UDim2.fromOffset(Size, Size), LayoutOrder = 2 }, R.Text)

    if cfg.children ~= nil then
        O.ChildrenHolder = New("Frame", {
            Size = UDim2.new(1, 0, 0, 0), AutomaticSize = AutoY, BackgroundTransparency = 1, BorderSizePixel = 0,
            Visible = cfg.children and true or false, Parent = R.Holder,
        })
        Layout(O.ChildrenHolder, 5)
        Pad(O.ChildrenHolder, 8, 0, 0, 0)

        Toggle.Holder = O.ChildrenHolder -- Toggle:Slider(...) etc. nest inside
    end

    function Toggle.Set(value)
        value = value and true or false
        Toggle.Value = value

        if O.ChildrenHolder then O.ChildrenHolder.Visible = value end

        Library.ChangeObjectTheme(O.Background, { BackgroundColor3 = value and "Accent" or "Background" }, true)
        Library.ChangeObjectTheme(O.Text, { TextColor3 = value and "Text" or "Dark Text" }, true)

        Library.Flags[cfg.flag] = value
        cfg.callback(value)
    end

    function Toggle.Enable() Toggle.Set(not Toggle.Value) end

    Utility.Signal(R.Line.MouseButton1Click:Connect(Toggle.Enable))

    Toggle.Set(cfg.value)
    Library.ConfigFlags[cfg.flag] = Toggle.Set

    return setmetatable(Toggle, Library)
end

----------------------------------------------------------------
-- SLIDER
----------------------------------------------------------------

function Library.Slider(self, cfg)
    cfg = Library.Config(cfg, {
        name = "New Slider", description = nil, value = 50, min = 0, max = 100, float = 1,
        suffix = "%s", callback = function() end, flag = nil,
    })
    cfg.flag = cfg.flag or cfg.name

    local Slider = { Objects = {}, Value = cfg.value }
    local R = Library.Row(self, cfg)
    local O = Slider.Objects

    O.Holder, O.Line, O.Text = R.Holder, R.Line, R.Text
    Slider.SideHolder = R.SideHolder

    O.Value = Label({ Text = "", Size = UDim2.new(), AutomaticSize = AutoXY, LayoutOrder = 2, Parent = R.Text }, { TextColor3 = "Dark Text" })

    O.Bar = New("TextButton", {
        Size = UDim2.new(1, 0, 0, 10), BorderSizePixel = 0, AutoButtonColor = false, Text = "", Parent = R.Holder,
    }, { BackgroundColor3 = "Inline" })
    Corner(O.Bar)

    O.Back = New("Frame", { Size = UDim2.new(1, -2, 1, -2), Position = UDim2.fromOffset(1, 1), BorderSizePixel = 0, Parent = O.Bar }, { BackgroundColor3 = "Background" })
    Corner(O.Back)

    O.Fill = New("Frame", { Size = UDim2.new(0, 0, 1, 0), BorderSizePixel = 0, Parent = O.Back }, { BackgroundColor3 = "Accent" })
    Corner(O.Fill)

    O.Knob = New("Frame", {
        Size = UDim2.fromOffset(12, 12), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0, 0.5),
        BorderSizePixel = 0, Parent = O.Back,
    }, { BackgroundColor3 = "Accent" })
    Corner(O.Knob, 6)
    New("UIStroke", { Thickness = 1, Parent = O.Knob }, { Color = "Inline" })

    function Slider.Set(value)
        value = tonumber(value) or cfg.min
        Slider.Value = math.clamp(Utility.Round(value, cfg.float), cfg.min, cfg.max)

        local Fraction = (Slider.Value - cfg.min) / math.max(cfg.max - cfg.min, 1e-9)

        O.Value.Text = string.format(cfg.suffix, tostring(Slider.Value))

        Library.Tween(O.Fill, { Size = UDim2.new(Fraction, 0, 1, 0) })
        Library.Tween(O.Knob, { Position = UDim2.fromScale(Fraction, 0.5) })

        local Theme = Slider.Value > cfg.min and "Text" or "Dark Text"
        Library.ChangeObjectTheme(O.Text, { TextColor3 = Theme }, true)
        Library.ChangeObjectTheme(O.Value, { TextColor3 = Theme }, true)

        Library.Flags[cfg.flag] = Slider.Value
        cfg.callback(Slider.Value)
    end

    Utility.Track(O.Bar, function(pos)
        local Fraction = math.clamp((pos.X - O.Bar.AbsolutePosition.X) / math.max(O.Bar.AbsoluteSize.X, 1), 0, 1)
        Slider.Set(cfg.min + (cfg.max - cfg.min) * Fraction)
    end)

    Slider.Set(cfg.value)
    Library.ConfigFlags[cfg.flag] = Slider.Set

    return setmetatable(Slider, Library)
end

----------------------------------------------------------------
-- BUTTON
----------------------------------------------------------------

function Library.Button(self, cfg)
    cfg = Library.Config(cfg, { name = "New Button", confirm = false, callback = function() end })

    local Button = { Objects = {}, Clicked = false, Token = 0 }
    local O = Button.Objects

    O.Outline, O.Background = Box("TextButton", {
        Size = UDim2.new(1, 0, 0, 24), AutoButtonColor = false, Text = "",
    }, self.Holder)

    O.Text = Label({
        Size = UDim2.fromScale(1, 1), Text = cfg.name, TextXAlignment = Center, Parent = O.Background,
    }, { TextColor3 = "Dark Text" })

    local function Reset()
        Button.Clicked = false
        O.Text.Text = cfg.name
        Library.ChangeObjectTheme(O.Text, { TextColor3 = "Dark Text" }, true)
    end

    function Button.Click()
        if cfg.confirm then
            if Button.Clicked then
                Button.Token += 1
                Reset()
                cfg.callback()
            else
                Button.Clicked = true
                Button.Token += 1

                local Token = Button.Token
                Library.ChangeObjectTheme(O.Text, { TextColor3 = "Accent" }, true)

                task.spawn(function()
                    for left = 5, 1, -1 do
                        if Button.Token ~= Token then return end
                        O.Text.Text = string.format("Confirm %s? (%d)", cfg.name, left)
                        task.wait(1)
                    end

                    if Button.Token == Token then Reset() end
                end)
            end
        else
            Library.ChangeObjectTheme(O.Text, { TextColor3 = "Accent" }, true)

            task.delay(Library.TweenSpeed, function()
                Library.ChangeObjectTheme(O.Text, { TextColor3 = "Dark Text" }, true)
            end)

            cfg.callback()
        end
    end

    Utility.Signal(O.Outline.MouseButton1Click:Connect(Button.Click))

    return setmetatable(Button, Library)
end

----------------------------------------------------------------
-- TEXTBOX
----------------------------------------------------------------

function Library.Textbox(self, cfg)
    cfg = Library.Config(cfg, { name = "New Textbox", value = "", callback = function() end, flag = nil })
    cfg.flag = cfg.flag or cfg.name

    local Textbox = { Objects = {} }
    local O = Textbox.Objects

    O.Outline, O.Background = Box("Frame", { Size = UDim2.new(1, 0, 0, 24), ClipsDescendants = true }, self.Holder)

    O.TextBox = New("TextBox", {
        Size = UDim2.new(1, -10, 1, 0), Position = UDim2.fromOffset(5, 0), Text = cfg.value, ClearTextOnFocus = false,
        PlaceholderText = cfg.name, MultiLine = false, TextSize = Library.FontSize, FontFace = Library.Font,
        TextXAlignment = Center, BackgroundTransparency = 1, TextStrokeTransparency = 0.8, ClipsDescendants = true,
        Parent = O.Background,
    }, { TextColor3 = "Text", PlaceholderColor3 = "Dark Text" })

    function Textbox.Set(value)
        value = tostring(value or "")
        O.TextBox.Text = value
        Library.Flags[cfg.flag] = value
        cfg.callback(value)
    end

    Utility.Signal(O.TextBox.FocusLost:Connect(function() Textbox.Set(O.TextBox.Text) end))

    Textbox.Set(cfg.value)
    Library.ConfigFlags[cfg.flag] = Textbox.Set

    return setmetatable(Textbox, Library)
end

----------------------------------------------------------------
-- DROPDOWN / LIST  (shared item logic)
----------------------------------------------------------------

local function Selector(S, cfg, parent, onPick)
    S.Items = {}
    S.Value = cfg.multi and {} or nil

    local function Mark()
        for _, item in ipairs(S.Items) do
            local On
            if cfg.multi then On = table.find(S.Value, item.Name) ~= nil else On = S.Value == item.Name end

            item.Selected = On
            Library.ChangeObjectTheme(item.Button, { TextColor3 = On and "Text" or "Dark Text" }, true)
        end
    end

    function S.Set(value, ignore)
        if cfg.multi then
            if type(value) == "table" then
                S.Value = table.clone(value)
            elseif value ~= nil then
                local Index = table.find(S.Value, value)
                if Index then table.remove(S.Value, Index) else table.insert(S.Value, value) end
            end
        else
            S.Value = value
        end

        Mark()

        if S.OnChange then S.OnChange() end

        Library.Flags[cfg.flag] = S.Value

        if not ignore then cfg.callback(S.Value) end
    end

    function S.Add(name)
        local Item = { Name = name, Selected = false }

        Item.Button = New("TextButton", {
            Size = UDim2.new(1, 0, 0, 17), Text = name, AutoButtonColor = false, BackgroundTransparency = 1,
            TextSize = Library.FontSize, FontFace = Library.Font, TextStrokeTransparency = 0.8,
            TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Parent = parent,
        }, { TextColor3 = "Dark Text" })

        Utility.Signal(Item.Button.MouseButton1Click:Connect(function()
            S.Set(name)
            if onPick then onPick() end
        end))

        table.insert(S.Items, Item)
        return Item
    end

    function S.Refresh(values)
        local Previous = S.Value

        for _, item in ipairs(S.Items) do item.Button:Destroy() end
        S.Items = {}

        for _, name in ipairs(values) do S.Add(name) end

        local function Exists(name)
            for _, item in ipairs(S.Items) do if item.Name == name then return true end end
            return false
        end

        if cfg.multi then
            local Kept = {}
            for _, name in ipairs(Previous or {}) do if Exists(name) then table.insert(Kept, name) end end
            S.Set(Kept, true)
        else
            S.Set(Exists(Previous) and Previous or values[1], true)
        end
    end

    for _, name in ipairs(cfg.values) do S.Add(name) end
end

function Library.Dropdown(self, cfg)
    cfg = Library.Config(cfg, {
        name = "New Dropdown", description = nil, values = {}, value = nil, multi = false,
        callback = function() end, flag = nil,
    })
    cfg.flag = cfg.flag or cfg.name

    local Dropdown = { Objects = {} }
    local R = Library.Row(self, cfg)
    local O = Dropdown.Objects

    O.Holder, O.Line, O.Text = R.Holder, R.Line, R.Text
    Dropdown.SideHolder = R.SideHolder

    O.Outline, O.Background = Box("TextButton", { Size = UDim2.new(1, 0, 0, 22), AutoButtonColor = false, Text = "" }, R.Holder)
    Pad(O.Background, 5, 5, 0, 0)

    O.Value = Label({ Size = UDim2.fromScale(1, 1), Text = "-", TextTruncate = Enum.TextTruncate.AtEnd, Parent = O.Background }, { TextColor3 = "Text" })

    local Popup = Library.MakePopup()
    Dropdown.Popup = Popup

    Popup.Bind(O.Outline, function()
        return O.Outline.AbsolutePosition + Vector2.new(0, O.Outline.AbsoluteSize.Y + 4)
    end)

    O.Scroll = New("ScrollingFrame", {
        Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0,
        AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(),
        BottomImage = Library.ScrollBar, MidImage = Library.ScrollBar, TopImage = Library.ScrollBar,
        ScrollBarThickness = 2, Parent = Popup.Content,
    }, { ScrollBarImageColor3 = "Accent" })
    Layout(O.Scroll, 4)

    Selector(Dropdown, cfg, O.Scroll, function()
        if not cfg.multi then Popup.Hide() end
    end)

    Dropdown.OnChange = function()
        local Value = Dropdown.Value

        if cfg.multi then
            O.Value.Text = #Value > 0 and table.concat(Value, ", ") or "-"
        else
            O.Value.Text = (Value == nil or Value == "") and "-" or tostring(Value)
        end
    end

    function Dropdown.Open()
        if Popup.Visible then
            Popup.Hide()
        else
            CloseAllPopups()
            Popup.Show(Vector2.new(O.Outline.AbsoluteSize.X, math.clamp(#Dropdown.Items, 1, 5) * 21 + 10))
        end
    end

    Utility.Signal(O.Outline.MouseButton1Click:Connect(Dropdown.Open))

    local Initial = cfg.value
    if Initial == nil and not cfg.multi then Initial = cfg.values[1] end

    Dropdown.Set(Initial or (cfg.multi and {} or nil))
    Library.ConfigFlags[cfg.flag] = Dropdown.Set

    return setmetatable(Dropdown, Library)
end

function Library.List(self, cfg)
    cfg = Library.Config(cfg, {
        name = "New List", description = nil, values = {}, value = nil, multi = false, size = 100,
        callback = function() end, flag = nil,
    })
    cfg.flag = cfg.flag or cfg.name

    local List = { Objects = {} }
    local R = Library.Row(self, cfg)
    local O = List.Objects

    O.Holder, O.Line, O.Text = R.Holder, R.Line, R.Text
    List.SideHolder = R.SideHolder

    O.Outline, O.Background = Box("Frame", { Size = UDim2.new(1, 0, 0, cfg.size), ClipsDescendants = true }, R.Holder)
    Pad(O.Background, 5, 5, 5, 5)

    O.Scroll = New("ScrollingFrame", {
        Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0,
        AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(),
        BottomImage = Library.ScrollBar, MidImage = Library.ScrollBar, TopImage = Library.ScrollBar,
        ScrollBarThickness = 2, Parent = O.Background,
    }, { ScrollBarImageColor3 = "Accent" })
    Layout(O.Scroll, 4)

    Selector(List, cfg, O.Scroll)

    List.Set(cfg.value or (cfg.multi and {} or cfg.values[1]))
    Library.ConfigFlags[cfg.flag] = List.Set

    return setmetatable(List, Library)
end

----------------------------------------------------------------
-- COLOURPICKER
----------------------------------------------------------------

function Library.GetColorWindow()
    if Library.ColorWindow then return Library.ColorWindow end

    local W = { H = 0, S = 0, V = 1, A = 0, Owner = nil }
    local Popup = Library.MakePopup()
    local C = Popup.Content

    W.Popup = Popup

    local SV = New("ImageLabel", {
        Size = UDim2.new(1, -18, 1, -18), BorderSizePixel = 0, Image = Library.Saturation,
        BackgroundColor3 = Color3.fromHSV(0, 1, 1), Parent = C,
    })
    Corner(SV, 4)

    local SVKnob = New("Frame", {
        Size = UDim2.fromOffset(8, 8), AnchorPoint = Vector2.new(0.5, 0.5), BorderSizePixel = 0,
        BackgroundColor3 = Color3.new(1, 1, 1), Parent = SV,
    })
    Corner(SVKnob, 4)
    New("UIStroke", { Thickness = 1, Color = Color3.new(0, 0, 0), Parent = SVKnob })

    local Hue = New("Frame", {
        Size = UDim2.new(0, 12, 1, -18), Position = UDim2.new(1, -12, 0, 0), BorderSizePixel = 0,
        BackgroundColor3 = Color3.new(1, 1, 1), Parent = C,
    })
    Corner(Hue, 4)
    New("UIGradient", {
        Rotation = 90, Parent = Hue,
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0.00, Color3.fromRGB(255, 0, 0)),
            ColorSequenceKeypoint.new(0.17, Color3.fromRGB(255, 255, 0)),
            ColorSequenceKeypoint.new(0.33, Color3.fromRGB(0, 255, 0)),
            ColorSequenceKeypoint.new(0.50, Color3.fromRGB(0, 255, 255)),
            ColorSequenceKeypoint.new(0.67, Color3.fromRGB(0, 0, 255)),
            ColorSequenceKeypoint.new(0.83, Color3.fromRGB(255, 0, 255)),
            ColorSequenceKeypoint.new(1.00, Color3.fromRGB(255, 0, 0)),
        }),
    })

    local HueKnob = New("Frame", {
        Size = UDim2.new(1, 4, 0, 4), AnchorPoint = Vector2.new(0.5, 0.5), BorderSizePixel = 0,
        BackgroundColor3 = Color3.new(1, 1, 1), Parent = Hue,
    })
    Corner(HueKnob, 2)
    New("UIStroke", { Thickness = 1, Color = Color3.new(0, 0, 0), Parent = HueKnob })

    local Alpha = New("ImageLabel", {
        Size = UDim2.new(1, -18, 0, 12), Position = UDim2.new(0, 0, 1, -12), BorderSizePixel = 0,
        Image = Library.Checkers, ScaleType = Enum.ScaleType.Tile, TileSize = UDim2.fromOffset(6, 6),
        BackgroundColor3 = Color3.new(1, 1, 1), Parent = C,
    })
    Corner(Alpha, 4)

    local AlphaFill = New("Frame", { Size = UDim2.fromScale(1, 1), BorderSizePixel = 0, BackgroundColor3 = Color3.new(1, 1, 1), Parent = Alpha })
    Corner(AlphaFill, 4)
    New("UIGradient", {
        Parent = AlphaFill,
        Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) }),
    })

    local AlphaKnob = New("Frame", {
        Size = UDim2.new(0, 4, 1, 4), AnchorPoint = Vector2.new(0.5, 0.5), BorderSizePixel = 0,
        BackgroundColor3 = Color3.new(1, 1, 1), Parent = Alpha,
    })
    Corner(AlphaKnob, 2)
    New("UIStroke", { Thickness = 1, Color = Color3.new(0, 0, 0), Parent = AlphaKnob })

    function W.Refresh(push)
        local Color = Color3.fromHSV(W.H, W.S, W.V)

        SV.BackgroundColor3 = Color3.fromHSV(W.H, 1, 1)
        SVKnob.Position = UDim2.fromScale(W.S, 1 - W.V)
        HueKnob.Position = UDim2.fromScale(0.5, W.H)
        AlphaKnob.Position = UDim2.fromScale(W.A, 0.5)
        AlphaFill.BackgroundColor3 = Color

        if push and W.Owner then W.Owner.Set(Color, W.A) end
    end

    local function Rel(pos, obj)
        return math.clamp((pos.X - obj.AbsolutePosition.X) / math.max(obj.AbsoluteSize.X, 1), 0, 1),
               math.clamp((pos.Y - obj.AbsolutePosition.Y) / math.max(obj.AbsoluteSize.Y, 1), 0, 1)
    end

    Utility.Track(SV, function(pos)
        local x, y = Rel(pos, SV)
        W.S, W.V = x, 1 - y
        W.Refresh(true)
    end)

    Utility.Track(Hue, function(pos)
        local _, y = Rel(pos, Hue)
        W.H = y
        W.Refresh(true)
    end)

    Utility.Track(Alpha, function(pos)
        local x = Rel(pos, Alpha)
        W.A = x
        W.Refresh(true)
    end)

    function W.Open(owner)
        if Popup.Visible and W.Owner == owner then
            Popup.Hide()
            return
        end

        CloseAllPopups()

        W.Owner = nil -- don't push while loading
        local h, s, v = owner.Value:ToHSV()
        if s > 0 and v > 0 then W.H = h end
        W.S, W.V, W.A = s, v, owner.Alpha or 0
        W.Refresh(false)
        W.Owner = owner

        local Anchor = owner.Objects.Outline

        Popup.Bind(Anchor, function() return Anchor.AbsolutePosition + Vector2.new(0, Anchor.AbsoluteSize.Y + 4) end)
        Popup.Show(Vector2.new(170, 150))
    end

    Library.ColorWindow = W
    return W
end

function Library.Colorpicker(self, cfg)
    cfg = Library.Config(cfg, { name = "New Colorpicker", value = Color3.new(1, 1, 1), alpha = 0, flag = nil, callback = function() end })
    cfg.flag = cfg.flag or cfg.name

    local Colorpicker = { Objects = {}, Value = cfg.value, Alpha = cfg.alpha }
    local O = Colorpicker.Objects

    local Side = self.SideHolder
    if not Side then
        local R = Library.Row(self, cfg)
        O.Holder, Side = R.Holder, R.SideHolder
    end

    local Size = Library.FontSize + 1
    O.Outline, O.Background = Box("TextButton", { Size = UDim2.fromOffset(Size, Size), Text = "", AutoButtonColor = false, LayoutOrder = 2 }, Side)

    function Colorpicker.Set(value, alpha)
        local Color, Trans

        if type(value) == "table" then
            Color, Trans = value.c, value.a
        else
            Color, Trans = value, alpha
        end

        Colorpicker.Value = Color
        Colorpicker.Alpha = Trans or Colorpicker.Alpha

        O.Background.BackgroundColor3 = Color
        O.Background.BackgroundTransparency = Colorpicker.Alpha

        Library.Flags[cfg.flag] = { c = Color, a = Colorpicker.Alpha }
        cfg.callback({ c = Color, a = Colorpicker.Alpha })
    end

    Utility.Signal(O.Outline.MouseButton1Click:Connect(function()
        Library.GetColorWindow().Open(Colorpicker)
    end))

    Colorpicker.Set(cfg.value, cfg.alpha)
    Library.ConfigFlags[cfg.flag] = Colorpicker.Set

    return setmetatable(Colorpicker, Library)
end

----------------------------------------------------------------
-- KEYBIND
----------------------------------------------------------------

function Library.Keybind(self, cfg)
    cfg = Library.Config(cfg, { name = "New Keybind", value = false, key = Enum.KeyCode.E, mode = "Toggle", callback = function() end, flag = nil })
    cfg.flag = cfg.flag or cfg.name

    local Keybind = { Objects = {}, Key = nil, Mode = "Toggle", Value = false }
    local O = Keybind.Objects

    local Side = self.SideHolder
    if not Side then
        local R = Library.Row(self, cfg)
        O.Holder, Side = R.Holder, R.SideHolder
    end

    local Size = Library.FontSize + 1
    O.Icon = New("ImageButton", {
        Size = UDim2.fromOffset(Size, Size), BackgroundTransparency = 1, AutoButtonColor = false,
        Image = Library.KeyIcon, LayoutOrder = 1, Parent = Side,
    }, { ImageColor3 = "Text" })

    -- popup: key button + 3 mode buttons
    local Popup = Library.MakePopup()
    Keybind.Popup = Popup

    Popup.Bind(O.Icon, function() return O.Icon.AbsolutePosition + Vector2.new(0, O.Icon.AbsoluteSize.Y + 4) end)
    Layout(Popup.Content, 4)

    local KeyRow = New("Frame", { Size = UDim2.new(1, 0, 0, 20), BackgroundTransparency = 1, Parent = Popup.Content })
    Label({ Size = UDim2.fromScale(0.5, 1), Text = "Key", Parent = KeyRow }, { TextColor3 = "Dark Text" })

    O.KeyOutline, O.KeyBackground = Box("TextButton", {
        Size = UDim2.new(0.5, 0, 1, 0), Position = UDim2.fromScale(0.5, 0), Text = "", AutoButtonColor = false,
    }, KeyRow)

    O.KeyText = Label({ Size = UDim2.fromScale(1, 1), Text = "E", TextSize = Library.FontSize - 2, TextXAlignment = Center, Parent = O.KeyBackground }, { TextColor3 = "Dark Text" })

    local ModeRow = New("Frame", { Size = UDim2.new(1, 0, 0, 20), BackgroundTransparency = 1, Parent = Popup.Content })
    local ModeLayout = Layout(ModeRow, 3, Horizontal)
    ModeLayout.HorizontalFlex = Enum.UIFlexAlignment.Fill

    local ModeButtons = {}
    for _, mode in ipairs({ "Toggle", "Hold", "Always" }) do
        local Btn = New("TextButton", {
            Size = UDim2.new(0.33, -2, 1, 0), Text = mode, AutoButtonColor = false, BackgroundTransparency = 1,
            TextSize = Library.FontSize - 2, FontFace = Library.Font, TextStrokeTransparency = 0.8, Parent = ModeRow,
        }, { TextColor3 = "Dark Text" })

        Utility.Signal(Btn.MouseButton1Click:Connect(function() Keybind.Set(mode) end))
        ModeButtons[mode] = Btn
    end

    function Keybind.Set(value, ignore)
        local Type = typeof(value)

        if Type == "table" then
            for _, v in pairs(value) do Keybind.Set(v, true) end
        elseif Type == "EnumItem" then
            Keybind.Key = value

            local Name = value == Enum.KeyCode.Unknown and "..." or value.Name
            O.KeyText.Text = Library.KeyConverters[string.lower(Name)] or Name
        elseif Type == "boolean" then
            if Keybind.Mode == "Always" then value = true end
            Keybind.Value = value
        elseif Type == "string" then
            Keybind.Mode = value

            if value == "Always" then Keybind.Value = true end

            for mode, btn in pairs(ModeButtons) do
                Library.ChangeObjectTheme(btn, { TextColor3 = mode == value and "Accent" or "Dark Text" }, true)
            end
        end

        Library.Flags[cfg.flag] = Keybind.Value
        Library.Flags[cfg.flag .. "_data"] = { value = Keybind.Value, key = Keybind.Key, mode = Keybind.Mode }

        if not ignore then cfg.callback(Keybind.Value) end
    end

    function Keybind.Open()
        if Popup.Visible then
            Popup.Hide()
        else
            CloseAllPopups()
            Popup.Show(Vector2.new(150, 76))
        end
    end

    Utility.Signal(O.Icon.MouseButton1Click:Connect(Keybind.Open))

    -- rebinding
    local Listener
    Utility.Signal(O.KeyOutline.MouseButton1Click:Connect(function()
        if Listener then return end

        Library.ChangeObjectTheme(O.KeyText, { TextColor3 = "Accent" }, true)
        O.KeyText.Text = "..."

        task.wait(0.05)

        Listener = UserInputService.InputBegan:Connect(function(input)
            local Key

            if input.KeyCode == Enum.KeyCode.Escape or input.KeyCode == Enum.KeyCode.Backspace then
                Key = Enum.KeyCode.Unknown
            elseif input.UserInputType == Enum.UserInputType.Keyboard then
                Key = input.KeyCode
            elseif input.UserInputType == Enum.UserInputType.MouseButton1
                or input.UserInputType == Enum.UserInputType.MouseButton2
                or input.UserInputType == Enum.UserInputType.MouseButton3 then
                Key = input.UserInputType
            end

            if Key then
                Listener:Disconnect()
                Listener = nil

                Keybind.Set(Key)
                Library.ChangeObjectTheme(O.KeyText, { TextColor3 = "Dark Text" }, true)
            end
        end)

        Utility.Signal(Listener)
    end))

    local function Matches(input)
        local Key = Keybind.Key
        return Key ~= nil and Key ~= Enum.KeyCode.Unknown and (input.KeyCode == Key or input.UserInputType == Key)
    end

    Utility.Signal(UserInputService.InputBegan:Connect(function(input)
        if Listener or UserInputService:GetFocusedTextBox() or not Matches(input) then return end

        if Keybind.Mode == "Toggle" then
            Keybind.Set(not Keybind.Value)
        elseif Keybind.Mode == "Hold" then
            Keybind.Set(true)
        end
    end))

    Utility.Signal(UserInputService.InputEnded:Connect(function(input)
        if Keybind.Mode == "Hold" and Keybind.Value and Matches(input) then
            Keybind.Set(false)
        end
    end))

    Keybind.Set({ cfg.key, cfg.mode, cfg.value }, true)
    Library.ConfigFlags[cfg.flag .. "_data"] = Keybind.Set

    return setmetatable(Keybind, Library)
end

----------------------------------------------------------------
-- NOTIFICATIONS / WATERMARK
----------------------------------------------------------------

function Library.Notification(cfg)
    cfg = Library.Config(cfg, { name = "New Notification", description = nil, type = "Normal", time = 5 })

    local Notification = {
        Objects = {}, Name = cfg.name, Type = cfg.type, Time = cfg.time, Clock = os.clock(), Lerp = 0,
    }
    local O = Notification.Objects

    O.Holder = New("Frame", {
        Name = "Notification", Size = UDim2.new(), AutomaticSize = AutoXY, BackgroundTransparency = 1, Parent = Library.ScreenGui,
    })

    O.Outline = New("Frame", { Size = UDim2.new(), AutomaticSize = AutoXY, BorderSizePixel = 0, Parent = O.Holder }, { BackgroundColor3 = "Inline" })
    Corner(O.Outline)
    Pad(O.Outline, 1, 1, 1, 1)

    O.Background = New("Frame", { Size = UDim2.new(), AutomaticSize = AutoXY, BorderSizePixel = 0, Parent = O.Outline }, { BackgroundColor3 = "Background" })
    Corner(O.Background)
    Pad(O.Background, 6, 6, 5, 6)
    Layout(O.Background, 4)

    O.Title = Label({ Text = cfg.name, Size = UDim2.new(), AutomaticSize = AutoXY, LayoutOrder = 1, Parent = O.Background }, { TextColor3 = "Text" })

    if cfg.description then
        O.Description = Label({
            Text = cfg.description, Size = UDim2.new(), AutomaticSize = AutoXY, TextSize = Library.FontSize - 2,
            TextWrapped = true, LayoutOrder = 2, Parent = O.Background,
        }, { TextColor3 = "Light Text" })

        New("UISizeConstraint", { MaxSize = Vector2.new(260, math.huge), Parent = O.Description })
    end

    if cfg.type == "Time" then
        O.Time = New("Frame", { Size = UDim2.new(0, 0, 0, 2), BorderSizePixel = 0, LayoutOrder = 3, Parent = O.Background }, { BackgroundColor3 = "Accent" })
    end

    function Notification.SetTime(time) Notification.Time, Notification.Clock = time, os.clock() end
    function Notification.Hide() Notification.Time = 0 end
    function Notification.Title(text) O.Title.Text = text end
    function Notification.Description(text) if O.Description then O.Description.Text = text end end

    table.insert(Library.Notifications, Notification)

    return Notification
end

function Library.Watermark(cfg)
    cfg = Library.Config(cfg, { text = "Elisium.lol | {game} | {time} | {date}", visible = true, rate = 1 })

    local Watermark = {
        Objects = {}, Visible = cfg.visible, Rate = cfg.rate, Text = cfg.text,
        Clock = 0, -- 0 = refresh on the very first frame
    }
    local O = Watermark.Objects

    O.Outline = New("Frame", {
        Name = "Watermark", Size = UDim2.new(), AutomaticSize = AutoXY, BorderSizePixel = 0,
        Position = UDim2.fromOffset(10, 10), Parent = Library.ScreenGui,
    }, { BackgroundColor3 = "Inline" })
    Corner(O.Outline)
    Pad(O.Outline, 1, 1, 1, 1)

    O.Background = New("Frame", { Size = UDim2.new(), AutomaticSize = AutoXY, BorderSizePixel = 0, Parent = O.Outline }, { BackgroundColor3 = "Background" })
    Corner(O.Background)
    Pad(O.Background, 6, 6, 4, 5)

    O.Text = Label({ Size = UDim2.new(), AutomaticSize = AutoXY, Text = "", Parent = O.Background }, { TextColor3 = "Text" })

    function Watermark.SetText(text)
        Watermark.Text = text
        Watermark.Clock = 0
    end

    function Watermark.SetVisible(visibility) Watermark.Visible = visibility end
    function Watermark.SetRate(rate) Watermark.Rate = rate end

    function Watermark.Think()
        O.Outline.Visible = Watermark.Visible

        if Watermark.Visible and os.clock() - Watermark.Clock >= Watermark.Rate then
            Watermark.Clock = os.clock()
            O.Text.Text = Utility.TextTriggers(Watermark.Text)
        end
    end

    Utility.Signal(RunService.RenderStepped:Connect(Watermark.Think))

    return Watermark
end

function Library.HandleNotifications(step)
    Library.Fps = math.floor(1 / math.max(step, 1e-4))

    local Clock = os.clock()
    local Mark = Library.ScreenGui:FindFirstChild("Watermark")
    local Offset = (Mark and Mark.Visible) and (10 + Mark.AbsoluteSize.Y + 5) or 10

    for i = #Library.Notifications, 1, -1 do
        local N = Library.Notifications[i]
        local O = N.Objects

        local Expired = Clock - N.Clock >= N.Time
        N.Lerp = Utility.Lerp(N.Lerp, Expired and 0 or 255, 0.1)

        local Alpha = 1 - (N.Lerp / 255)

        O.Holder.Position = UDim2.fromOffset(10 - O.Holder.AbsoluteSize.X * Alpha, Offset)
        O.Outline.BackgroundTransparency = Alpha
        O.Background.BackgroundTransparency = Alpha
        O.Title.TextTransparency = Alpha

        if O.Description then O.Description.TextTransparency = Alpha end

        if O.Time then
            O.Time.BackgroundTransparency = Alpha

            local Fraction = math.clamp(1 - (Clock - N.Clock) / math.max(N.Time, 1e-4), 0, 1)
            O.Time.Size = UDim2.new(0, math.max(0, (O.Background.AbsoluteSize.X - 12)) * Fraction, 0, 2)
        end

        Offset += (O.Holder.AbsoluteSize.Y + 5) * (N.Lerp / 255)

        if Expired and N.Lerp <= 0 then
            O.Holder:Destroy()
            table.remove(Library.Notifications, i)
        end
    end
end

Utility.Signal(RunService.RenderStepped:Connect(Library.HandleNotifications))

----------------------------------------------------------------
-- CONFIG / UNLOAD
----------------------------------------------------------------

function Library.GetConfig()
    local Config = {}

    for name in pairs(Library.ConfigFlags) do
        local Value = Library.Flags[name]

        if type(Value) == "table" and Value.key ~= nil then
            Config[name] = { value = Value.value, mode = Value.mode, key = tostring(Value.key) }
        elseif type(Value) == "table" and Value.a ~= nil and Value.c ~= nil then
            Config[name] = { a = Value.a, c = Value.c:ToHex() }
        else
            Config[name] = Value
        end
    end

    return HttpService:JSONEncode(Config)
end

function Library.LoadConfig(data)
    data = HttpService:JSONDecode(data)

    for name, v in pairs(data) do
        local Setter = Library.ConfigFlags[name]

        if Setter then
            local ok, err = pcall(function()
                if type(v) == "table" and v.a ~= nil and v.c ~= nil then
                    Setter({ a = v.a, c = type(v.c) == "string" and Color3.fromHex(v.c) or v.c })
                elseif type(v) == "table" and (v.key ~= nil or v.mode ~= nil) then
                    Setter({ value = v.value, mode = v.mode, key = v.key and Utility.StringToEnum(v.key) or nil })
                else
                    Setter(v)
                end
            end)

            if not ok then warn("[Library] could not load flag '" .. tostring(name) .. "': " .. tostring(err)) end
        end
    end
end

function Library.Unload()
    for _, connection in ipairs(Utility.Connections) do
        pcall(function() connection:Disconnect() end)
    end

    for _, obj in ipairs(Utility.Objects) do
        pcall(function() obj:Destroy() end)
    end

    table.clear(Library.Notifications)

    if getgenv then getgenv().Library = nil end
end

return Library, Utility
