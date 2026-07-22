-------------------------------------------------------------------------------
--  BetterBags_EllesmereTheme.lua
--  Registers an "EllesmereUI" theme with BetterBags' Themes module so the bag
--  and bank windows match the EllesmereUI design language.
--
--  Design tokens mirror EllesmereUIBags / EllesmereUIBlizzardSkin_WindowEngine:
--    panel  : 0.06 near-black fill, 1px 0.25 gray border
--    header : 30px band, black 50% fill, 1px 0.15 separator below
--    search : 0.02 fill, 1px 0.25 border, gray placeholder text
--    fonts  : EllesmereUI.GetFontPath("bags") + outline flag, shadow when flat
--    close  : EllesmereUI's eui-close.png icon, 0.7 -> 0.9 alpha on hover
--
--  Everything is created inside decoration frames (BetterBags theme contract):
--  Reset() only has to hide them, and no BetterBags frame is modified directly.
-------------------------------------------------------------------------------
local addonName = ... ---@type string

local BetterBags = LibStub('AceAddon-3.0'):GetAddon('BetterBags')
assert(BetterBags, addonName .. ' requires BetterBags')

local themes = BetterBags:GetModule('Themes')
local searchBox = BetterBags:GetModule('SearchBox')

local HEADER_H = 30
local BG     = { r = 0.06, g = 0.06, b = 0.06, a = 0.90 }
local BORDER = { r = 0.25, g = 0.25, b = 0.25, a = 1 }
local SEP    = { r = 0.15, g = 0.15, b = 0.15, a = 1 }
local CLOSE_ICON = 'Interface\\AddOns\\EllesmereUI\\media\\icons\\eui-close.png'

-- EllesmereUI is a hard requirement for Available, but resolve it lazily so a
-- future load-order change can't leave us holding a nil at file scope.
local function GetEUI() return _G.EllesmereUI end

-- Live accent color: read at use time so EUI accent changes apply on the next
-- tab selection without a reload.
local function Accent()
  local EUI = GetEUI()
  local eg = EUI and EUI.ELLESMERE_GREEN
  if eg and eg.r then return eg.r, eg.g, eg.b end
  return 0.047, 0.824, 0.616
end

local function FontPath()
  local EUI = GetEUI()
  return (EUI and EUI.GetFontPath and EUI.GetFontPath('bags')) or STANDARD_TEXT_FONT
end

local function FontFlag()
  local EUI = GetEUI()
  return (EUI and EUI.GetFontOutlineFlag and EUI.GetFontOutlineFlag('bags')) or ''
end

-- Same font treatment as EllesmereUIBags' SetBagFont: user-configured bag font,
-- drop shadow only when no outline is active.
local function SetEUIFont(fs, size)
  local flag = FontFlag()
  fs:SetFont(FontPath(), size, flag)
  if flag == '' then
    fs:SetShadowColor(0, 0, 0, 1)
    fs:SetShadowOffset(1, -1)
  else
    fs:SetShadowColor(0, 0, 0, 0)
  end
end

-- 1px border built from four textures, pixel-snapped via EllesmereUI's PP.mult
-- when available (same approach as EllesmereUIBags' accent/group borders).
local function AddBorder(frame, c)
  local EUI = GetEUI()
  local px = (EUI and EUI.PP and EUI.PP.mult) or 1
  local function line(p1, p2, w, h)
    local t = frame:CreateTexture(nil, 'OVERLAY', nil, 7)
    t:SetColorTexture(c.r, c.g, c.b, c.a)
    t:SetPoint(p1, frame, p1, 0, 0)
    t:SetPoint(p2, frame, p2, 0, 0)
    if w then t:SetWidth(w) end
    if h then t:SetHeight(h) end
  end
  line('TOPLEFT', 'TOPRIGHT', nil, px)
  line('BOTTOMLEFT', 'BOTTOMRIGHT', nil, px)
  line('TOPLEFT', 'BOTTOMLEFT', px, nil)
  line('TOPRIGHT', 'BOTTOMRIGHT', px, nil)
end

---@class EllesmereDecoration: Frame
---@field bg Frame|BackdropTemplate
---@field header Frame
---@field title FontString
---@field search SearchFrame?

---@type table<string, EllesmereDecoration>
local decoratorFrames = {}

---@type table<string, PanelTabButtonTemplate>
local tabDecorations = {}

-- Tab label fonts as Font objects: buttons re-apply their state font object on
-- every draw-state change (hover in particular), so direct SetFont/SetTextColor
-- on the label FontString would be reverted. Swapping font objects sticks.
local tabFontNormal = CreateFont(addonName .. 'TabFontNormal')
local tabFontSelected = CreateFont(addonName .. 'TabFontSelected')
local function RefreshTabFonts()
  local flag = FontFlag()
  tabFontNormal:SetFont(FontPath(), 11, flag)
  tabFontNormal:SetTextColor(0.65, 0.65, 0.65)
  tabFontSelected:SetFont(FontPath(), 11, flag)
  tabFontSelected:SetTextColor(Accent())
end

-- Shared window shell: dark backdrop + 1px border, header band with separator,
-- left-aligned title, optional close button. titleOffsetX leaves room for the
-- bag button on portrait windows.
local function CreateShell(frame, titleOffsetX, onClose)
  local decoration = CreateFrame('Frame', frame:GetName() .. 'ThemeEllesmere', frame) --[[@as EllesmereDecoration]]
  decoration:SetAllPoints()
  decoration:SetFrameLevel(math.max(frame:GetFrameLevel() - 1, 0))

  local bg = CreateFrame('Frame', decoration:GetName() .. 'BG', decoration, 'BackdropTemplate')
  bg:SetAllPoints()
  bg:SetFrameLevel(decoration:GetFrameLevel())
  bg:SetBackdrop({
    bgFile = 'Interface\\ChatFrame\\ChatFrameBackground',
    edgeFile = 'Interface\\ChatFrame\\ChatFrameBackground',
    edgeSize = 1,
  })
  bg:SetBackdropColor(BG.r, BG.g, BG.b, BG.a)
  bg:SetBackdropBorderColor(BORDER.r, BORDER.g, BORDER.b, BORDER.a)
  decoration.bg = bg

  local header = CreateFrame('Frame', nil, decoration)
  header:SetPoint('TOPLEFT', 1, -1)
  header:SetPoint('TOPRIGHT', -1, -1)
  header:SetHeight(HEADER_H)
  local hbg = header:CreateTexture(nil, 'BACKGROUND')
  hbg:SetAllPoints()
  hbg:SetColorTexture(0, 0, 0, 0.5)
  local sep = header:CreateTexture(nil, 'BORDER')
  sep:SetPoint('BOTTOMLEFT')
  sep:SetPoint('BOTTOMRIGHT')
  sep:SetHeight(1)
  sep:SetColorTexture(SEP.r, SEP.g, SEP.b, SEP.a)
  decoration.header = header

  local title = header:CreateFontString(nil, 'OVERLAY')
  SetEUIFont(title, 13)
  title:SetPoint('LEFT', header, 'LEFT', titleOffsetX, 0)
  title:SetTextColor(1, 1, 1)
  decoration.title = title
  if themes.titles[frame:GetName()] then
    title:SetText(themes.titles[frame:GetName()])
  end

  if onClose then
    local close = CreateFrame('Button', nil, decoration)
    close:SetSize(12, 12)
    close:SetPoint('RIGHT', header, 'RIGHT', -9, 0)
    close:SetFrameLevel(1001)
    close.icon = close:CreateTexture(nil, 'OVERLAY')
    close.icon:SetAllPoints()
    close.icon:SetTexture(CLOSE_ICON)
    close.icon:SetAlpha(0.7)
    close:SetScript('OnEnter', function(self) self.icon:SetAlpha(0.9) end)
    close:SetScript('OnLeave', function(self) self.icon:SetAlpha(0.7) end)
    decoration.CloseButton = close
    onClose(close)
  end

  return decoration
end

---@type Theme
local ellesmereTheme = {
  Name = 'EllesmereUI',
  Description = 'Matches the EllesmereUI design language.',
  Available = GetEUI() ~= nil,

  Portrait = function(frame)
    local decoration = decoratorFrames[frame:GetName()]
    if decoration then
      decoration:Show()
      return
    end
    decoration = CreateShell(frame, 32, function(close)
      BetterBags.SetScript(close, 'OnClick', function(ctx)
        frame.Owner:Hide(ctx)
      end)
    end)

    -- Search bar under the header, restyled from BagSearchBoxTemplate to the
    -- EllesmereUIBags search look (stock art stripped, dark fill, 1px border).
    local box = searchBox:CreateBox(frame.Owner.kind, decoration --[[@as Frame]])
    box.frame:SetPoint('TOPLEFT', decoration, 'TOPLEFT', 8, -(HEADER_H + 8))
    box.frame:SetPoint('BOTTOMRIGHT', decoration, 'TOPRIGHT', -8, -(HEADER_H + 30))
    for i = 1, select('#', box.textBox:GetRegions()) do
      local region = select(i, box.textBox:GetRegions())
      if region and region.IsObjectType and region:IsObjectType('Texture') then
        region:SetAlpha(0)
      end
    end
    box.textBox:SetFont(FontPath(), 12, FontFlag())
    box.textBox:SetTextInsets(5, 20, 0, 0)
    if box.helpText then
      SetEUIFont(box.helpText, 11)
      box.helpText:SetTextColor(0.4, 0.4, 0.4)
      box.helpText:ClearAllPoints()
      box.helpText:SetPoint('LEFT', box.textBox, 'LEFT', 5, 0)
    end
    local searchBg = box.frame:CreateTexture(nil, 'BACKGROUND')
    searchBg:SetAllPoints()
    searchBg:SetColorTexture(0.02, 0.02, 0.02, 1)
    AddBorder(box.frame, BORDER)
    decoration.search = box

    -- Bag menu button in the header, portrait shrunk to fit the 30px band.
    local bagButton = themes.SetupBagButton(frame.Owner, decoration --[[@as Frame]])
    bagButton:SetPoint('TOPLEFT', decoration, 'TOPLEFT', -5, 5)
    bagButton.portrait:SetSize(22, 27.5)
    bagButton.highlightTex:SetSize(22, 27.5)

    decoratorFrames[frame:GetName()] = decoration
  end,

  Simple = function(frame)
    local decoration = decoratorFrames[frame:GetName()]
    if decoration then
      decoration:Show()
      return
    end
    decoration = CreateShell(frame, 8, function(close)
      close:SetScript('OnClick', function()
        frame:Hide()
      end)
    end)
    decoratorFrames[frame:GetName()] = decoration
  end,

  Flat = function(frame)
    local decoration = decoratorFrames[frame:GetName()]
    if decoration then
      decoration:Show()
      return
    end
    decoration = CreateShell(frame, 8, nil)
    decoratorFrames[frame:GetName()] = decoration
  end,

  Opacity = function(frame, alpha)
    local decoration = decoratorFrames[frame:GetName()]
    if decoration then
      -- Fade only the fill; the 1px border stays solid (EUI panels keep their
      -- border regardless of fill opacity).
      decoration.bg:SetBackdropColor(BG.r, BG.g, BG.b, alpha / 100)
    end
  end,

  SectionFont = function(font)
    SetEUIFont(font, 12)
    font:SetTextColor(1, 1, 1)
  end,

  SetTitle = function(frame, title)
    local decoration = decoratorFrames[frame:GetName()]
    if decoration then
      decoration.title:SetText(title)
    end
  end,

  Reset = function()
    for _, decoration in pairs(decoratorFrames) do
      decoration:Hide()
    end
    for _, decoration in pairs(tabDecorations) do
      decoration:Hide()
    end
  end,

  -- Bottom tabs (Backpack / bank tabs / "+"), EUI sidebar-button style: flat
  -- dark fill, 1px border, gray label; the selected tab gets accent text, a
  -- 10% accent fill and a 2px accent bar along the top edge.
  --
  -- BetterBags' SelectTab/DeselectTab drive the stock PanelTabButton art by
  -- calling Show/Hide on Left/Middle/Right and *Active directly, so the art is
  -- alpha-0'd (Show keeps it invisible) and selection is observed by hooking
  -- LeftActive:Show/Hide.
  Tab = function(tab)
    local tabName = tab:GetName()
    local decoration = tabDecorations[tabName]
    if decoration then
      decoration:Show()
      return decoration
    end
    decoration = themes.CreateDefaultTabDecoration(tab --[[@as TabButton]])

    for _, key in ipairs({
      'Left', 'Middle', 'Right',
      'LeftActive', 'MiddleActive', 'RightActive',
      'LeftHighlight', 'MiddleHighlight', 'RightHighlight',
    }) do
      local art = decoration[key]
      if art and art.SetAlpha then art:SetAlpha(0) end
    end

    -- Kill the Blizzard selected/deselected text wobble. With symmetric 2px
    -- top / 2px bottom insets the fill is centered on the button, so no text
    -- offset is needed.
    decoration.selectedTextX, decoration.selectedTextY = 0, 0
    decoration.deselectedTextX, decoration.deselectedTextY = 0, 0

    local bg = decoration:CreateTexture(nil, 'BACKGROUND')
    bg:SetPoint('TOPLEFT', decoration, 'TOPLEFT', 1, -2)
    bg:SetPoint('BOTTOMRIGHT', decoration, 'BOTTOMRIGHT', -1, 2)
    bg:SetColorTexture(0.08, 0.08, 0.08, 0.92)

    local border = CreateFrame('Frame', nil, decoration)
    border:SetPoint('TOPLEFT', bg, 'TOPLEFT', 0, 0)
    border:SetPoint('BOTTOMRIGHT', bg, 'BOTTOMRIGHT', 0, 0)
    AddBorder(border, BORDER)

    local selBar = decoration:CreateTexture(nil, 'OVERLAY', nil, 6)
    selBar:SetPoint('TOPLEFT', bg, 'TOPLEFT', 0, 0)
    selBar:SetPoint('TOPRIGHT', bg, 'TOPRIGHT', 0, 0)
    selBar:SetHeight(2)
    selBar:Hide()

    local selFill = decoration:CreateTexture(nil, 'BACKGROUND', nil, 1)
    selFill:SetAllPoints(bg)
    selFill:Hide()

    local hover = decoration:CreateTexture(nil, 'HIGHLIGHT')
    hover:SetAllPoints(bg)
    hover:SetColorTexture(1, 1, 1, 0.06)

    RefreshTabFonts()
    decoration:SetNormalFontObject(tabFontNormal)
    decoration:SetHighlightFontObject(tabFontNormal)
    decoration:SetDisabledFontObject(tabFontSelected)

    local function ApplySelected()
      RefreshTabFonts()
      local r, g, b = Accent()
      selBar:SetColorTexture(r, g, b, 0.9)
      selBar:Show()
      selFill:SetColorTexture(r, g, b, 0.10)
      selFill:Show()
      decoration:SetNormalFontObject(tabFontSelected)
      decoration:SetHighlightFontObject(tabFontSelected)
    end
    local function ApplyDeselected()
      selBar:Hide()
      selFill:Hide()
      decoration:SetNormalFontObject(tabFontNormal)
      decoration:SetHighlightFontObject(tabFontNormal)
    end
    if decoration.LeftActive then
      hooksecurefunc(decoration.LeftActive, 'Show', ApplySelected)
      hooksecurefunc(decoration.LeftActive, 'Hide', ApplyDeselected)
    end

    tabDecorations[tabName] = decoration
    return decoration
  end,

  ToggleSearch = function(frame, shown)
    local decoration = decoratorFrames[frame:GetName()]
    if decoration and decoration.search then
      decoration.search:SetShown(shown)
    end
  end,
}

themes:RegisterTheme('EllesmereUI', ellesmereTheme)
