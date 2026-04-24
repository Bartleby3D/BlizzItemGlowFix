local _, NS = ...

local PixelSnapValue = NS.PixelSnapValue
local PixelSnapSetSize = NS.PixelSnapSetSize
local PixelSnapSetPoint = NS.PixelSnapSetPoint

local MainFrame
local CurrentSubTab = 1
local ScrollFrame
local ContentInner
local ScrollBar

local function ClearContainer()
    if not ContentInner then return end
    local kids = { ContentInner:GetChildren() }
    for _, child in ipairs(kids) do
        if child.list then
            child.list:Hide()
            child.list:SetParent(nil)
            if NS.AllDropdowns then
                for index = #NS.AllDropdowns, 1, -1 do
                    if NS.AllDropdowns[index] == child.list then
                        table.remove(NS.AllDropdowns, index)
                    end
                end
            end
        end
        child:Hide()
        child:SetParent(nil)
    end
end

local function GetCurrentSubTabInfo()
    return NS.UIData and NS.UIData.subTabs and NS.UIData.subTabs[CurrentSubTab] or nil
end

local function IsGeneralSubTab(index)
    local info = NS.UIData and NS.UIData.subTabs and NS.UIData.subTabs[index]
    return info and info.key == "general"
end

local function GetSubTabEnabled(index)
    if IsGeneralSubTab(index) then
        return true
    end

    local info = NS.UIData and NS.UIData.subTabs and NS.UIData.subTabs[index]
    if not info or not info.toggleKey or not NS.Config then
        return true
    end

    local value = NS.Config.Get(info.toggleKey, "Global")
    return value ~= false
end

local function SetSubTabEnabled(index, state)
    if IsGeneralSubTab(index) then
        return
    end

    local info = NS.UIData and NS.UIData.subTabs and NS.UIData.subTabs[index]
    if not info or not info.toggleKey or not NS.Config then
        return
    end

    NS.Config.Set(info.toggleKey, state and true or false, "Global")
end

local function CreateDescriptionBlock(parent, text, width)
    local frame = CreateFrame("Frame", nil, parent)
    PixelSnapSetSize(frame, width or 265, 1, 1, 1)

    local fs = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    PixelSnapSetPoint(fs, "TOPLEFT", frame, "TOPLEFT", 0, 0)
    fs:SetTextColor(0.5, 0.5, 0.5)
    fs:SetWidth(PixelSnapValue(fs, width or 265, 1))
    fs:SetJustifyH("LEFT")
    fs:SetWordWrap(true)
    fs:SetText(text or "")

    local h = math.max(14, (fs:GetStringHeight() or 14))
    PixelSnapSetSize(frame, width or 265, h, 1, 1)
    frame.Text = fs
    return frame
end

local function CreateSpacer(parent, height)
    local frame = CreateFrame("Frame", nil, parent)
    PixelSnapSetSize(frame, 1, height or 10, 1, 1)
    return frame
end

local function GetCurrentPage()
    local subTab = GetCurrentSubTabInfo()
    if not subTab then return nil end
    return NS.UIData.pages[subTab.key]
end

local function LocalizeDropdownOptions(options)
    if type(options) ~= "table" then
        return options
    end

    local localized = {}
    for i, entry in ipairs(options) do
        if type(entry) == "table" then
            localized[i] = {
                text = NS.L(entry.text),
                value = entry.value,
                color = entry.color,
            }
        else
            localized[i] = NS.L(entry)
        end
    end
    return localized
end

local function BindCheckbox(widget, opt)
    if not widget or not opt or not opt.dbKey or not NS.Config then return end
    local context = opt.context or "Global"
    widget:SetChecked(NS.Config.Get(opt.dbKey, context) and true or false)
    widget:SetScript("OnClick", function(self)
        NS.CloseAllDropdowns()
        NS.Config.Set(opt.dbKey, self:GetChecked() and true or false, context)
        if NS.RefreshGUI then
            NS.RefreshGUI(true)
        end
    end)
end

local function BindSlider(widget, opt)
    if not widget or not opt or not opt.dbKey or not NS.Config then return end
    local context = opt.context or "Global"
    local value = tonumber(NS.Config.Get(opt.dbKey, context)) or opt.min or 0
    widget.slider:SetValue(value)
    if widget.editbox and widget.formatValue then
        widget.editbox:SetText(widget.formatValue(widget.slider:GetValue()))
    end
    widget.slider.OnValueChangedCallback = function(_, newValue)
        NS.Config.Set(opt.dbKey, newValue, context)
    end
end

local function BindColorPicker(widget, opt)
    if not widget or not opt or not opt.dbKey or not NS.Config then return end
    local context = opt.context or "Global"

    local function ApplySwatch(r, g, b, a)
        if widget.colorTex and widget.colorTex.SetColorTexture then
            widget.colorTex:SetColorTexture(r or 1, g or 1, b or 1, a or 1)
        end
    end

    local function GetCurrentColor()
        return NS.Config.GetColor(opt.dbKey, context)
    end

    local function SaveColor(r, g, b, a)
        NS.Config.SetColor(opt.dbKey, r, g, b, a, context)
        ApplySwatch(r, g, b, a)
    end

    ApplySwatch(GetCurrentColor())

    widget.box:SetScript("OnClick", function()
        NS.CloseAllDropdowns()

        local startR, startG, startB, startA = GetCurrentColor()

        if ColorPickerFrame and type(ColorPickerFrame.SetupColorPickerAndShow) == "function" then
            local info = {
                r = startR,
                g = startG,
                b = startB,
                hasOpacity = false,
                previousValues = {
                    r = startR,
                    g = startG,
                    b = startB,
                    a = startA,
                },
            }

            info.swatchFunc = function()
                local color = ColorPickerFrame:GetColorRGB()
                if type(color) == "table" then
                    SaveColor(color.r or startR, color.g or startG, color.b or startB, startA)
                    return
                end

                local r, g, b = ColorPickerFrame:GetColorRGB()
                SaveColor(r or startR, g or startG, b or startB, startA)
            end

            info.cancelFunc = function(previousValues)
                if type(previousValues) == "table" then
                    SaveColor(previousValues.r or startR, previousValues.g or startG, previousValues.b or startB, previousValues.a or startA)
                    return
                end

                SaveColor(startR, startG, startB, startA)
            end

            ColorPickerFrame:SetupColorPickerAndShow(info)
            return
        end

        if not ColorPickerFrame then
            return
        end

        ColorPickerFrame.hasOpacity = false
        ColorPickerFrame.previousValues = {
            r = startR,
            g = startG,
            b = startB,
            a = startA,
        }
        ColorPickerFrame.func = function()
            local r, g, b = ColorPickerFrame:GetColorRGB()
            SaveColor(r or startR, g or startG, b or startB, startA)
        end
        ColorPickerFrame.cancelFunc = function(previousValues)
            if type(previousValues) == "table" then
                SaveColor(previousValues.r or startR, previousValues.g or startG, previousValues.b or startB, previousValues.a or startA)
                return
            end

            SaveColor(startR, startG, startB, startA)
        end
        ColorPickerFrame:SetColorRGB(startR, startG, startB)
        if ColorPickerFrame.Show then
            ColorPickerFrame:Show()
        end
    end)
end

local function CreateBoundDropdown(parent, opt)
    local options = LocalizeDropdownOptions(opt.options or { "-" })
    local context = opt.context or "Global"
    local currentValue = opt.dbKey and NS.GetConfig(opt.dbKey, nil, context) or nil
    if type(opt.currentValue) == "function" then
        local ok, resolvedValue = pcall(opt.currentValue, context, currentValue)
        if ok then
            currentValue = resolvedValue
        end
    end

    return NS.Widgets.CreateDropdown(
        parent,
        NS.L(opt.text),
        options,
        opt.width,
        function(value)
            if opt.dbKey and NS.Config then
                NS.Config.Set(opt.dbKey, value, context)
                if NS.RefreshGUI then
                    NS.RefreshGUI(true)
                end
            end
        end,
        currentValue
    )
end

local function IsOptionVisible(opt)
    if not opt then return true end

    local context = opt.context or "Global"

    if type(opt.visibleWhen) == "function" then
        local ok, result = pcall(opt.visibleWhen, context, opt)
        if ok then
            return result and true or false
        end
        return true
    end

    if not opt.visibleWhenKey or not NS.Config then
        return true
    end

    return NS.Config.Get(opt.visibleWhenKey, context) ~= false
end

local function DrawOptions(container)
    ClearContainer()

    local page = GetCurrentPage()
    if not page then return 1 end

    local startX = 20
    local startY = -15
    local currentY = startY
    local pageEnabled = GetSubTabEnabled(CurrentSubTab)

    for _, opt in ipairs(page) do
        if IsOptionVisible(opt) then
            local widget
            local x = startX + (opt.offX or 0)

            if opt.type == "header" then
            if currentY ~= startY then
                currentY = currentY - 10
            end
            widget = NS.Widgets.CreateHeader(container, NS.L(opt.text))
            if opt.textColor and widget.Text then
                widget.Text:SetTextColor(unpack(opt.textColor))
            end
            PixelSnapSetPoint(widget, "TOPLEFT", container, "TOPLEFT", x - 5, currentY)
            currentY = currentY - 40

        elseif opt.type == "desc" then
            widget = CreateDescriptionBlock(container, NS.L(opt.text), 265)
            if opt.textColor and widget.Text then
                widget.Text:SetTextColor(unpack(opt.textColor))
            end
            PixelSnapSetPoint(widget, "TOPLEFT", container, "TOPLEFT", x, currentY)
            currentY = currentY - (widget:GetHeight() or 14) - 8

        elseif opt.type == "separator" then
            currentY = currentY - 10 + (opt.offY or 0)
            widget = NS.Widgets.CreateSeparator(container, "H", opt.width or 265)
            PixelSnapSetPoint(widget, "TOPLEFT", container, "TOPLEFT", x - 10, currentY)
            currentY = currentY - 14

        elseif opt.type == "checkbox" then
            widget = NS.Widgets.CreateCheckbox(container, NS.L(opt.text))
            if opt.textColor and widget.Text then
                widget.Text:SetTextColor(unpack(opt.textColor))
            end
            BindCheckbox(widget, opt)
            PixelSnapSetPoint(widget, "TOPLEFT", container, "TOPLEFT", x, currentY)
            currentY = currentY - 40

        elseif opt.type == "slider" then
            widget = NS.Widgets.CreateSlider(container, NS.L(opt.text), opt.min or 0, opt.max or 100, opt.step)
            BindSlider(widget, opt)
            PixelSnapSetPoint(widget, "TOPLEFT", container, "TOPLEFT", x, currentY)
            currentY = currentY - 50

        elseif opt.type == "dropdown" then
            widget = CreateBoundDropdown(container, opt)
            PixelSnapSetPoint(widget, "TOPLEFT", container, "TOPLEFT", x, currentY)
            currentY = currentY - 60

        elseif opt.type == "color" then
            widget = NS.Widgets.CreateColorPicker(container, NS.L(opt.text))
            BindColorPicker(widget, opt)
            PixelSnapSetPoint(widget, "TOPLEFT", container, "TOPLEFT", x, currentY)
            currentY = currentY - 35

        elseif opt.type == "spacer" then
            widget = CreateSpacer(container, opt.size or 10)
            PixelSnapSetPoint(widget, "TOPLEFT", container, "TOPLEFT", x, currentY)
            currentY = currentY - (opt.size or 10)
        end

            if widget and (opt.type == "checkbox" or opt.type == "slider" or opt.type == "dropdown" or opt.type == "color") then
                local shouldEnable = (opt.enabled ~= false) and (pageEnabled or IsGeneralSubTab(CurrentSubTab))
                NS.Widgets.SetEnabled(widget, shouldEnable)
            end
        end
    end

    return math.abs(currentY) + 20
end

local function UpdateScrollBar(contentHeight)
    if not ScrollBar or not ScrollFrame or not ContentInner then return end

    local viewHeight = ScrollFrame:GetHeight() or 1
    local maxScroll = math.max(0, contentHeight - viewHeight)

    if maxScroll > 0 then
        ScrollBar:SetMinMaxValues(0, maxScroll)
        if ScrollBar:GetValue() > maxScroll then
            ScrollBar:SetValue(maxScroll)
        end
        ScrollBar:Show()
    else
        ScrollBar:SetMinMaxValues(0, 0)
        ScrollBar:SetValue(0)
        ScrollFrame:SetVerticalScroll(0)
        ScrollBar:Hide()
    end
end

local function RefreshLayout(preserveScroll)
    if not MainFrame or not ContentInner then return end

    local savedScroll = 0
    if preserveScroll and ScrollBar and ScrollBar:IsShown() then
        savedScroll = ScrollBar:GetValue() or 0
    end

    local contentHeight = DrawOptions(ContentInner)
    ContentInner:SetHeight(PixelSnapValue(ContentInner, contentHeight, 1))
    UpdateScrollBar(contentHeight)

    if preserveScroll and ScrollBar and ScrollBar:IsShown() then
        local minV, maxV = ScrollBar:GetMinMaxValues()
        local v = savedScroll
        if v < minV then v = minV end
        if v > maxV then v = maxV end
        ScrollBar:SetValue(v)
        ScrollFrame:SetVerticalScroll(v)
    end

    for i, btn in ipairs(MainFrame.SubButtons or {}) do
        local isSelected = (i == CurrentSubTab)
        btn:SetBackdropBorderColor(unpack(isSelected and NS.COLOR_ACCENT or { 0.2, 0.2, 0.2, 1 }))
        btn.Text:SetTextColor(unpack(isSelected and { 1, 1, 1, 1 } or { 0.6, 0.6, 0.6, 1 }))

        if btn.Toggle then
            if IsGeneralSubTab(i) then
                btn.Toggle:Hide()
            else
                btn.Toggle:Show()
                btn.Toggle:SetChecked(GetSubTabEnabled(i))
            end
        end
    end
end

function NS.InitializeGUI()
    if MainFrame then return end
    MainFrame = CreateFrame("Frame", "BIGF_MainLayout", UIParent, "BackdropTemplate")
    PixelSnapSetSize(MainFrame, 550, 650, 1, 1)
    PixelSnapSetPoint(MainFrame, "CENTER", UIParent, "CENTER", 0, 0)
    MainFrame:SetMovable(true)
    MainFrame:EnableMouse(true)
    MainFrame:RegisterForDrag("LeftButton")
    MainFrame:SetScript("OnDragStart", MainFrame.StartMoving)
    MainFrame:SetScript("OnDragStop", MainFrame.StopMovingOrSizing)
    MainFrame:SetFrameStrata("HIGH")
    MainFrame:SetClampedToScreen(true)
    MainFrame:SetScript("OnMouseDown", function() NS.CloseAllDropdowns() end)
    MainFrame:SetScript("OnHide", function() NS.CloseAllDropdowns() end)
    NS.CreateBackdrop(MainFrame, NS.COLOR_BG_DARK, NS.COLOR_BORDER)
    NS.DropdownParent = MainFrame
    MainFrame:Hide()

    local Title = MainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    PixelSnapSetPoint(Title, "BOTTOMLEFT", MainFrame, "TOPLEFT", 10, 8)
    Title:SetText("|cff00aaffBlizzItemGlow|r Fix")
    local font, size, flags = Title:GetFont()
    if font and size then
        Title:SetFont(font, size + 2, flags)
    end

    local TopPanel = CreateFrame("Frame", nil, MainFrame)
    PixelSnapSetPoint(TopPanel, "TOPLEFT", MainFrame, "TOPLEFT", 10, -10)
    PixelSnapSetPoint(TopPanel, "TOPRIGHT", MainFrame, "TOPRIGHT", -10, -10)
    TopPanel:SetHeight(PixelSnapValue(TopPanel, 35, 1))

    local LeftPanel = CreateFrame("Frame", nil, MainFrame, "BackdropTemplate")
    PixelSnapSetPoint(LeftPanel, "TOPLEFT", MainFrame, "TOPLEFT", 10, -60)
    PixelSnapSetPoint(LeftPanel, "BOTTOMLEFT", MainFrame, "BOTTOMLEFT", 10, 10)
    LeftPanel:SetWidth(PixelSnapValue(LeftPanel, 170, 1))
    NS.CreateBackdrop(LeftPanel, { 0, 0, 0, 0.2 }, NS.COLOR_BORDER)

    local Content = CreateFrame("Frame", nil, MainFrame, "BackdropTemplate")
    PixelSnapSetPoint(Content, "TOPLEFT", LeftPanel, "TOPRIGHT", 10, 0)
    PixelSnapSetPoint(Content, "BOTTOMRIGHT", MainFrame, "BOTTOMRIGHT", -10, 10)
    NS.CreateBackdrop(Content, NS.COLOR_BG_PANEL, NS.COLOR_BORDER)
    Content:SetScript("OnMouseDown", function() NS.CloseAllDropdowns() end)

    local Clip = CreateFrame("Frame", nil, Content)
    PixelSnapSetPoint(Clip, "TOPLEFT", Content, "TOPLEFT", 0, -2)
    PixelSnapSetPoint(Clip, "BOTTOMRIGHT", Content, "BOTTOMRIGHT", -18, 2)
    if Clip.SetClipsChildren then
        Clip:SetClipsChildren(true)
    end

    ScrollFrame = CreateFrame("ScrollFrame", nil, Clip)
    ScrollFrame:SetAllPoints()
    ScrollFrame:EnableMouseWheel(true)

    ContentInner = CreateFrame("Frame", nil, ScrollFrame)
    PixelSnapSetPoint(ContentInner, "TOPLEFT", ScrollFrame, "TOPLEFT", 0, 0)
    ContentInner:SetWidth(PixelSnapValue(ContentInner, 305, 1))
    ContentInner:SetHeight(PixelSnapValue(ContentInner, 1, 1))
    ScrollFrame:SetScrollChild(ContentInner)

    ScrollBar = CreateFrame("Slider", nil, Content, "BackdropTemplate")
    PixelSnapSetPoint(ScrollBar, "TOPRIGHT", Content, "TOPRIGHT", -5, -7)
    PixelSnapSetPoint(ScrollBar, "BOTTOMRIGHT", Content, "BOTTOMRIGHT", -5, 7)
    local TRACK_W, THUMB_W, THUMB_H = 4, 4, 44
    ScrollBar:SetWidth(PixelSnapValue(ScrollBar, TRACK_W, 1))
    ScrollBar:SetOrientation("VERTICAL")
    ScrollBar:SetMinMaxValues(0, 0)
    ScrollBar:SetValue(0)
    ScrollBar:SetValueStep(1)
    ScrollBar:SetObeyStepOnDrag(true)
    ScrollBar:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
    ScrollBar:SetBackdropColor(0, 0, 0, 0.35)

    local thumb = ScrollBar:CreateTexture(nil, "ARTWORK")
    thumb:SetTexture("Interface\\Buttons\\WHITE8X8")
    PixelSnapSetSize(thumb, THUMB_W, THUMB_H, 1, 1)
    thumb:SetVertexColor(unpack(NS.COLOR_ACCENT))
    ScrollBar:SetThumbTexture(thumb)

    local thumbGlow = ScrollBar:CreateTexture(nil, "OVERLAY")
    thumbGlow:SetTexture("Interface\\Buttons\\WHITE8X8")
    PixelSnapSetPoint(thumbGlow, "CENTER", thumb, "CENTER", 0, 0)
    PixelSnapSetSize(thumbGlow, THUMB_W + 2, THUMB_H + 2, 1, 1)
    thumbGlow:SetVertexColor(1, 1, 1, 0.22)
    thumbGlow:Hide()

    local thumbHit = CreateFrame("Frame", nil, ScrollBar)
    PixelSnapSetPoint(thumbHit, "CENTER", thumb, "CENTER", 0, 0)
    PixelSnapSetSize(thumbHit, THUMB_W + 10, THUMB_H + 10, 1, 1)
    ScrollBar:SetScript("OnUpdate", function(self)
        if not self:IsShown() then
            thumbGlow:Hide()
            return
        end
        if MouseIsOver(thumbHit) then
            thumbGlow:Show()
        else
            thumbGlow:Hide()
        end
    end)
    ScrollBar:SetScript("OnValueChanged", function(self, value)
        ScrollFrame:SetVerticalScroll(value)
        NS.CloseAllDropdowns()
    end)
    ScrollFrame:SetScript("OnMouseWheel", function(_, delta)
        if not ScrollBar or not ScrollBar:IsShown() then return end
        local cur = ScrollBar:GetValue()
        local minV, maxV = ScrollBar:GetMinMaxValues()
        local newV = cur - (delta * 30)
        if newV < minV then newV = minV end
        if newV > maxV then newV = maxV end
        ScrollBar:SetValue(newV)
        NS.CloseAllDropdowns()
    end)
    ScrollBar:Hide()

    local mainButton = CreateFrame("Button", nil, TopPanel, "BackdropTemplate")
    PixelSnapSetPoint(mainButton, "TOPLEFT", TopPanel, "TOPLEFT", 0, 0)
    PixelSnapSetPoint(mainButton, "TOPRIGHT", TopPanel, "TOPRIGHT", 0, 0)
    mainButton:SetHeight(PixelSnapValue(mainButton, 30, 1))
    NS.CreateBackdrop(mainButton, { 0.02, 0.02, 0.02, 1 }, { 0.15, 0.15, 0.15, 1 })
    mainButton:EnableMouse(false)
    mainButton.Text = mainButton:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    mainButton.Text:SetFont(mainButton.Text:GetFont(), 11)
    mainButton.Text:SetPoint("CENTER")
    mainButton.Text:SetText(NS.L(NS.UIData.mainTitle))
    mainButton.Text:SetTextColor(1, 1, 1, 1)
    mainButton:SetBackdropBorderColor(unpack(NS.COLOR_ACCENT))

    MainFrame.SubButtons = {}
    for i, info in ipairs(NS.UIData.subTabs) do
        local btn = CreateFrame("Button", nil, LeftPanel, "BackdropTemplate")
        PixelSnapSetSize(btn, 160, 32, 1, 1)
        PixelSnapSetPoint(btn, "TOP", LeftPanel, "TOP", 0, -10 - (i - 1) * 35)
        NS.CreateBackdrop(btn, { 0, 0, 0, 0.3 }, { 0.2, 0.2, 0.2, 1 })

        btn.Text = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        btn.Text:SetPoint("LEFT", 15, 0)
        btn.Text:SetText(NS.L(info.text))

        btn.Toggle = CreateFrame("CheckButton", nil, btn, "BackdropTemplate")
        PixelSnapSetSize(btn.Toggle, 16, 16, 1, 1)
        PixelSnapSetPoint(btn.Toggle, "RIGHT", btn, "RIGHT", -10, 0)
        NS.CreateBackdrop(btn.Toggle, { 0, 0, 0, 0.5 }, { 0.3, 0.3, 0.3, 1 })

        local check = btn.Toggle:CreateTexture(nil, "OVERLAY")
        check:SetTexture("Interface\\Buttons\\WHITE8X8")
        check:SetVertexColor(unpack(NS.COLOR_ACCENT))
        PixelSnapSetPoint(check, "TOPLEFT", btn.Toggle, "TOPLEFT", 3, -3)
        PixelSnapSetPoint(check, "BOTTOMRIGHT", btn.Toggle, "BOTTOMRIGHT", -3, 3)
        btn.Toggle:SetCheckedTexture(check)
        btn.Toggle:EnableMouse(true)
        btn.Toggle:SetScript("OnClick", function(self)
            local newState = self:GetChecked() and true or false
            SetSubTabEnabled(i, newState)
            NS.CloseAllDropdowns()
            RefreshLayout(true)
        end)

        btn:SetScript("OnEnter", function(self)
            if i ~= CurrentSubTab then
                self:SetBackdropBorderColor(unpack(NS.COLOR_ACCENT))
                self.Text:SetTextColor(1, 1, 1)
            end
        end)
        btn:SetScript("OnLeave", function(self)
            if i ~= CurrentSubTab then
                self:SetBackdropBorderColor(0.2, 0.2, 0.2, 1)
                self.Text:SetTextColor(0.6, 0.6, 0.6, 1)
            end
        end)
        btn:SetScript("OnClick", function()
            CurrentSubTab = i
            if NS.Config then
                NS.Config.Set("uiSelectedSubTab", i, "Global")
            end
            NS.CloseAllDropdowns()
            RefreshLayout()
        end)

        MainFrame.SubButtons[i] = btn
    end

    local close = CreateFrame("Button", nil, MainFrame, "BackdropTemplate")
    PixelSnapSetSize(close, 26, 26, 1, 1)
    PixelSnapSetPoint(close, "TOPRIGHT", MainFrame, "TOPRIGHT", 0, 26)
    NS.CreateBackdrop(close, { 0.02, 0.02, 0.02, 1 }, { 0.15, 0.15, 0.15, 1 })
    close.t = close:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    close.t:SetPoint("CENTER", 0, -1)
    close.t:SetJustifyH("CENTER")
    close.t:SetJustifyV("MIDDLE")
    close.t:SetText("X")
    close.t:SetTextColor(0.8, 0.8, 0.8)
    close:SetScript("OnEnter", function(self)
        self.t:SetTextColor(1, 0.2, 0.2, 1)
        self.t:SetShadowColor(1, 0.4, 0.4, 1)
        self.t:SetShadowOffset(0, 0)
    end)
    close:SetScript("OnLeave", function(self)
        self.t:SetTextColor(0.7, 0.7, 0.7, 1)
        self.t:SetShadowColor(0, 0, 0, 0)
        self.t:SetShadowOffset(0, 0)
    end)
    close:SetScript("OnClick", function()
        NS.CloseAllDropdowns()
        MainFrame:Hide()
    end)

    NS.RefreshGUI = RefreshLayout

    MainFrame:HookScript("OnShow", function()
        local selected = NS.GetConfig("uiSelectedSubTab", 1, "Global")
        if type(selected) ~= "number" or selected < 1 or selected > #NS.UIData.subTabs then
            selected = 1
        end
        CurrentSubTab = selected
        RefreshLayout()
        C_Timer.After(0, function()
            if MainFrame and MainFrame:IsShown() then
                RefreshLayout(true)
            end
        end)
    end)
end

function NS.ToggleGUI()
    if not MainFrame then
        NS.InitializeGUI()
    end
    if MainFrame then
        MainFrame:SetShown(not MainFrame:IsShown())
    end
end
