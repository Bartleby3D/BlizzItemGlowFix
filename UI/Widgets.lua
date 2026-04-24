local _, NS = ...
NS.Widgets = NS.Widgets or {}

local PixelSnapValue = NS.PixelSnapValue
local PixelSnapSetSize = NS.PixelSnapSetSize
local PixelSnapSetPoint = NS.PixelSnapSetPoint

NS.COLOR_ACCENT    = { 0.0, 0.6, 1.0, 1 }
NS.COLOR_BG_DARK   = { 0.02, 0.02, 0.03, 0.98 }
NS.COLOR_BG_PANEL  = { 1, 1, 1, 0.03 }
NS.COLOR_BORDER    = { 0.1, 0.12, 0.15, 1 }
NS.COLOR_TEXT_OFF  = { 0.9, 0.9, 0.9, 1 }

NS.AllDropdowns = NS.AllDropdowns or {}

function NS.CloseAllDropdowns()
    if NS.AllDropdowns then
        for _, list in ipairs(NS.AllDropdowns) do
            if list and list:IsShown() then
                list:Hide()
            end
        end
    end
end

function NS.CreateBackdrop(f, bg, border)
    f:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    f:SetBackdropColor(unpack(bg or NS.COLOR_BG_DARK))
    f:SetBackdropBorderColor(unpack(border or NS.COLOR_BORDER))
end

function NS.CreateHeader(parent, text)
    local f = CreateFrame("Frame", nil, parent)
    PixelSnapSetSize(f, 265, 20, 1, 1)

    local h = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    PixelSnapSetPoint(h, "LEFT", f, "LEFT", 0, 0)
    h:SetWidth(PixelSnapValue(h, 265, 1))
    h:SetJustifyH("LEFT")
    h:SetWordWrap(false)
    h:SetText(text)
    h:SetTextColor(unpack(NS.COLOR_ACCENT))

    f.Text = h
    return f
end


function NS.CreateModernSlider(parent, label, minV, maxV, step)
    local frame = CreateFrame("Frame", nil, parent)
    PixelSnapSetSize(frame, 220, 42, 1, 1)

    local sliderMin = minV or 0
    local sliderMax = maxV or 100
    local sliderStep = step or 0.1
    local stepString = tostring(sliderStep)
    local decimals = stepString:match("%.(%d+)")
    decimals = decimals and #decimals or 0

    local function RoundToStep(value)
        if not value then return sliderMin end
        local steps = math.floor(((value - sliderMin) / sliderStep) + 0.5)
        local snapped = sliderMin + (steps * sliderStep)
        if snapped < sliderMin then snapped = sliderMin end
        if snapped > sliderMax then snapped = sliderMax end
        return tonumber(string.format("%." .. decimals .. "f", snapped)) or snapped
    end

    local function FormatValue(value)
        if decimals <= 0 then
            return string.format("%.0f", value)
        end
        return string.format("%." .. decimals .. "f", value)
    end

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    PixelSnapSetPoint(title, "TOPLEFT", frame, "TOPLEFT", 0, 0)
    title:SetTextColor(unpack(NS.COLOR_TEXT_OFF))
    title:SetText(label)

    local s = CreateFrame("Slider", nil, frame, "BackdropTemplate")
    PixelSnapSetPoint(s, "TOPLEFT", frame, "TOPLEFT", 0, -20)
    PixelSnapSetSize(s, 160, 6, 1, 1)
    s:SetOrientation("HORIZONTAL")
    s:SetMinMaxValues(sliderMin, sliderMax)
    s:SetValue(sliderMin)
    s:SetValueStep(sliderStep)
    s:SetObeyStepOnDrag(true)
    s:HookScript("OnMouseDown", function() NS.CloseAllDropdowns() end)
    NS.CreateBackdrop(s, { 0, 0, 0, 0.5 }, { 0, 0, 0, 1 })

    local thumb = s:CreateTexture(nil, "ARTWORK")
    thumb:SetTexture("Interface\\Buttons\\WHITE8X8")
    PixelSnapSetSize(thumb, 6, 16, 1, 1)
    thumb:SetVertexColor(unpack(NS.COLOR_ACCENT))
    s:SetThumbTexture(thumb)
    s:SetHitRectInsets(0, 0, -4, -4)

    local thumbGlow = s:CreateTexture(nil, "OVERLAY")
    thumbGlow:SetTexture("Interface\\Buttons\\WHITE8X8")
    PixelSnapSetSize(thumbGlow, 8, 18, 1, 1)
    thumbGlow:SetVertexColor(1, 1, 1, 0.4)
    PixelSnapSetPoint(thumbGlow, "CENTER", thumb, "CENTER", 0, 0)
    thumbGlow:Hide()

    s:SetScript("OnEnter", function() thumbGlow:Show() end)
    s:SetScript("OnLeave", function() thumbGlow:Hide() end)

    local eb = CreateFrame("EditBox", nil, frame, "BackdropTemplate")
    PixelSnapSetSize(eb, 45, 20, 1, 1)
    PixelSnapSetPoint(eb, "LEFT", s, "RIGHT", 12, 0)
    eb:SetFontObject("GameFontHighlightSmall")
    eb:SetJustifyH("CENTER")
    NS.CreateBackdrop(eb, { 0, 0, 0, 0.6 }, NS.COLOR_BORDER)
    eb:SetAutoFocus(false)
    eb:HookScript("OnMouseDown", function() NS.CloseAllDropdowns() end)
    eb:SetScript("OnEnter", function(self) self:SetBackdropBorderColor(unpack(NS.COLOR_ACCENT)) end)
    eb:SetScript("OnLeave", function(self) self:SetBackdropBorderColor(unpack(NS.COLOR_BORDER)) end)

    local function UpdateFromEB(self)
        local val = tonumber(self:GetText())
        if val then
            val = RoundToStep(val)
            s:SetValue(val)
            if s.OnValueChangedCallback then
                s.OnValueChangedCallback(s, val)
            end
        else
            self:SetText(FormatValue(RoundToStep(s:GetValue())))
        end
        self:ClearFocus()
    end

    eb:SetScript("OnEnterPressed", UpdateFromEB)
    eb:SetScript("OnEditFocusLost", UpdateFromEB)
    eb:SetScript("OnEscapePressed", function(self)
        self:SetText(FormatValue(RoundToStep(s:GetValue())))
        self:ClearFocus()
    end)

    s:SetScript("OnValueChanged", function(self, v, userInput)
        local snappedValue = RoundToStep(v)
        eb:SetText(FormatValue(snappedValue))
        if userInput and self.OnValueChangedCallback then
            self.OnValueChangedCallback(self, snappedValue)
        end
    end)

    frame.slider = s
    frame.editbox = eb
    frame.decimals = decimals
    frame.formatValue = FormatValue
    return frame
end

function NS.CreateModernCheckbox(parent, label)
    local cb = CreateFrame("CheckButton", nil, parent, "BackdropTemplate")
    PixelSnapSetSize(cb, 18, 18, 1, 1)
    NS.CreateBackdrop(cb, { 0, 0, 0, 0.5 }, { 0.3, 0.3, 0.3, 1 })

    local check = cb:CreateTexture(nil, "OVERLAY")
    check:SetTexture("Interface\\Buttons\\WHITE8X8")
    check:SetVertexColor(unpack(NS.COLOR_ACCENT))
    PixelSnapSetPoint(check, "TOPLEFT", cb, "TOPLEFT", 3, -3)
    PixelSnapSetPoint(check, "BOTTOMRIGHT", cb, "BOTTOMRIGHT", -3, 3)
    cb:SetCheckedTexture(check)

    cb.Text = cb:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    PixelSnapSetPoint(cb.Text, "LEFT", cb, "RIGHT", 7, 0)
    cb.Text:SetText(label)

    cb:SetScript("OnEnter", function(self) self:SetBackdropBorderColor(unpack(NS.COLOR_ACCENT)) end)
    cb:SetScript("OnLeave", function(self) self:SetBackdropBorderColor(0.3, 0.3, 0.3, 1) end)
    cb:HookScript("OnClick", function() NS.CloseAllDropdowns() end)
    return cb
end

function NS.CreateColorBox(parent, label)
    local frame = CreateFrame("Frame", nil, parent)
    PixelSnapSetSize(frame, 220, 25, 1, 1)

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    PixelSnapSetPoint(title, "LEFT", frame, "LEFT", 30, 0)
    title:SetTextColor(unpack(NS.COLOR_TEXT_OFF))
    title:SetText(label)

    local box = CreateFrame("Button", nil, frame, "BackdropTemplate")
    PixelSnapSetSize(box, 18, 18, 1, 1)
    PixelSnapSetPoint(box, "LEFT", frame, "LEFT", 0, 0)
    NS.CreateBackdrop(box, { 0, 0, 0, 0.6 }, { 0, 0, 0, 1 })

    local colorTex = box:CreateTexture(nil, "OVERLAY")
    PixelSnapSetPoint(colorTex, "TOPLEFT", box, "TOPLEFT", 1, -1)
    PixelSnapSetPoint(colorTex, "BOTTOMRIGHT", box, "BOTTOMRIGHT", -1, 1)
    colorTex:SetColorTexture(1, 1, 1)

    box:SetScript("OnEnter", function(self) self:SetBackdropBorderColor(1, 1, 1) end)
    box:SetScript("OnLeave", function(self) self:SetBackdropBorderColor(0, 0, 0) end)
    box:HookScript("OnMouseDown", function() NS.CloseAllDropdowns() end)

    frame.box = box
    frame.colorTex = colorTex
    return frame
end

local function ApplyDropdownFontColor(fontString, color)
    if not fontString then
        return
    end

    if type(color) == "table" then
        fontString:SetTextColor(color.r or 1, color.g or 1, color.b or 1, color.a or 1)
        return
    end

    fontString:SetTextColor(1, 1, 1, 1)
end

function NS.CreateModernDropdown(parent, label, options, func, width, selectedValue)
    local frame = CreateFrame("Frame", nil, parent)
    width = width or 180

    local frameW = (width < 180) and width or (width + 40)
    PixelSnapSetSize(frame, frameW, 45, 1, 1)

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    PixelSnapSetPoint(title, "TOPLEFT", frame, "TOPLEFT", 0, 0)
    title:SetTextColor(unpack(NS.COLOR_TEXT_OFF))
    title:SetText(label)

    local btn = CreateFrame("Button", nil, frame, "BackdropTemplate")
    PixelSnapSetSize(btn, width, 22, 1, 1)
    PixelSnapSetPoint(btn, "TOPLEFT", frame, "TOPLEFT", 0, -18)
    NS.CreateBackdrop(btn, { 0, 0, 0, 0.5 }, { 0.3, 0.3, 0.3, 1 })
    btn:SetScript("OnEnter", function(self) self:SetBackdropBorderColor(unpack(NS.COLOR_ACCENT)) end)
    btn:SetScript("OnLeave", function(self) self:SetBackdropBorderColor(0.3, 0.3, 0.3, 1) end)

    local arrow = btn:CreateTexture(nil, "OVERLAY")
    arrow:SetTexture("Interface\\ChatFrame\\ChatFrameExpandArrow")
    arrow:SetDesaturated(true)
    arrow:SetVertexColor(unpack(NS.COLOR_ACCENT))
    PixelSnapSetSize(arrow, 10, 10, 1, 1)
    PixelSnapSetPoint(arrow, "RIGHT", btn, "RIGHT", -6, 0)
    if arrow.SetRotation then
        arrow:SetRotation(0)
    end

    btn.Text = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    PixelSnapSetPoint(btn.Text, "LEFT", btn, "LEFT", 8, 0)

    local function ResolveOptions()
        if type(options) == "function" then
            local ok, res = pcall(options)
            if ok then return res end
            return nil
        end
        return options
    end

    local function ClearListChildren(listFrame)
        local kids = { listFrame:GetChildren() }
        for _, c in ipairs(kids) do
            c:Hide()
            c:SetParent(nil)
        end
    end

    local function BuildList(listFrame, btnFrame, opts)
        ClearListChildren(listFrame)
        local count = opts and #opts or 0
        PixelSnapSetSize(listFrame, width, count * 20 + 10, 1, 1)
        if not opts then return end

        for i, optName in ipairs(opts) do
            local display, value, color = optName, optName, nil
            if type(optName) == "table" then
                display = optName.text or ""
                value = optName.value
                color = optName.color
            end

            local opt = CreateFrame("Button", nil, listFrame)
            PixelSnapSetSize(opt, math.max(10, width - 10), 18, 1, 1)
            PixelSnapSetPoint(opt, "TOPLEFT", listFrame, "TOPLEFT", 5, -5 - (i - 1) * 20)

            local ot = opt:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            PixelSnapSetPoint(ot, "LEFT", opt, "LEFT", 5, 0)
            ot:SetText(display)
            ApplyDropdownFontColor(ot, color)

            opt:SetScript("OnEnter", function() ot:SetTextColor(unpack(NS.COLOR_ACCENT)) end)
            opt:SetScript("OnLeave", function() ApplyDropdownFontColor(ot, color) end)
            opt:SetScript("OnClick", function()
                btnFrame._selectedValue = value
                btnFrame._selectedColor = color
                btnFrame.Text:SetText(display)
                ApplyDropdownFontColor(btnFrame.Text, color)
                listFrame:Hide()
                if func then
                    func(value, display)
                end
            end)
        end
    end

    local function GetDisplayForValue(opts, wantedValue)
        if not opts then return nil end
        for _, optName in ipairs(opts) do
            if type(optName) == "table" then
                if optName.value == wantedValue then
                    return optName.text or "", optName.value, optName.color
                end
            elseif optName == wantedValue then
                return optName, optName, nil
            end
        end
        return nil
    end

    local function SetSelection(value, fallbackDisplay)
        local opts = ResolveOptions()
        local display = fallbackDisplay
        local resolvedValue = value
        local resolvedColor = nil

        if display == nil then
            display, resolvedValue, resolvedColor = GetDisplayForValue(opts, value)
        end

        if display == nil then
            local first = opts and opts[1]
            if type(first) == "table" then
                display = first.text or ""
                resolvedValue = first.value
                resolvedColor = first.color
            else
                display = first or ""
                resolvedValue = first
            end
        end

        btn._selectedValue = resolvedValue
        btn._selectedColor = resolvedColor
        btn.Text:SetText(display or "")
        ApplyDropdownFontColor(btn.Text, resolvedColor)
    end

    SetSelection(selectedValue)

    local listParent = NS.DropdownParent or UIParent
    local list = CreateFrame("Frame", nil, listParent, "BackdropTemplate")
    list:ClearAllPoints()
    PixelSnapSetPoint(list, "TOPLEFT", btn, "BOTTOMLEFT", 0, -1)
    local count = (type(options) == "table") and #options or 0
    PixelSnapSetSize(list, width, count * 20 + 10, 1, 1)
    list:SetFrameStrata("TOOLTIP")
    list:SetClampedToScreen(true)
    list:Hide()
    list._arrow = arrow
    list:SetScript("OnShow", function()
        if arrow.SetRotation then
            arrow:SetRotation(math.pi / 2)
        end
    end)
    list:SetScript("OnHide", function()
        if arrow.SetRotation then
            arrow:SetRotation(0)
        end
    end)
    NS.CreateBackdrop(list, { 0.05, 0.05, 0.08, 0.95 }, NS.COLOR_ACCENT)
    table.insert(NS.AllDropdowns, list)

    btn:SetScript("OnClick", function()
        local isShown = list:IsShown()
        NS.CloseAllDropdowns()
        if not isShown then
            local opts = ResolveOptions()
            BuildList(list, btn, opts)
            list:ClearAllPoints()
            PixelSnapSetPoint(list, "TOPLEFT", btn, "BOTTOMLEFT", 0, -1)
            list:Show()
        end
    end)

    if type(options) == "table" then
        BuildList(list, btn, options)
    end

    frame.btn = btn
    frame.list = list
    frame.SetValue = function(_, value)
        SetSelection(value)
    end
    return frame
end

function NS.Widgets.SetEnabled(wrapper, isEnabled)
    if not wrapper then return end
    wrapper:SetAlpha(isEnabled and 1 or 0.4)

    if wrapper.slider then
        wrapper.slider:EnableMouse(isEnabled)
        wrapper.editbox:EnableMouse(isEnabled)
    elseif wrapper.box then
        wrapper.box:EnableMouse(isEnabled)
    elseif wrapper.btn then
        wrapper.btn:EnableMouse(isEnabled)
    elseif wrapper:IsObjectType("CheckButton") or wrapper:IsObjectType("Button") then
        wrapper:EnableMouse(isEnabled)
    end
end

function NS.Widgets.CreateHeader(parent, text)
    return NS.CreateHeader(parent, text)
end

function NS.Widgets.CreateCheckbox(parent, label)
    return NS.CreateModernCheckbox(parent, label)
end

function NS.Widgets.CreateSlider(parent, label, minV, maxV, step)
    return NS.CreateModernSlider(parent, label, minV, maxV, step)
end

function NS.Widgets.CreateColorPicker(parent, label)
    return NS.CreateColorBox(parent, label)
end

function NS.Widgets.CreateDropdown(parent, label, options, width, func, selectedValue)
    return NS.CreateModernDropdown(parent, label, options, func, width, selectedValue)
end

function NS.Widgets.CreateSeparator(parent, orientation, size)
    local f = CreateFrame("Frame", nil, parent)
    local tex = f:CreateTexture(nil, "ARTWORK")
    tex:SetAllPoints()
    local alpha = (orientation == "V") and 0.40 or 0.10
    tex:SetColorTexture(0.5, 0.5, 0.5, alpha)
    if orientation == "V" then
        PixelSnapSetSize(f, 1, size or 100, 1, 1)
    else
        PixelSnapSetSize(f, size or 250, 1, 1, 1)
    end
    return f
end
