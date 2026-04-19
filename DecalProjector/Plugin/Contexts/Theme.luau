local Root = script.Parent.Parent
local React = require(Root.Packages.React)

local Hooks = Root.Hooks
local useProperty = require(Hooks.useProperty)

export type GuideColor =
    | "MainBackground"
    | "Titlebar"
    | "Dropdown"
    | "Tooltip"
    | "Notification"
    | "ScrollBar"
    | "ScrollBarBackground"
    | "TabBar"
    | "Tab"
    | "FilterButtonDefault"
    | "FilterButtonHover"
    | "FilterButtonChecked"
    | "FilterButtonAccent"
    | "FilterButtonBorder"
    | "FilterButtonBorderAlt"
    | "RibbonTab"
    | "RibbonTabTopBar"
    | "Button"
    | "MainButton"
    | "RibbonButton"
    | "ViewPortBackground"
    | "InputFieldBackground"
    | "Item"
    | "TableItem"
    | "CategoryItem"
    | "GameSettingsTableItem"
    | "GameSettingsTooltip"
    | "EmulatorBar"
    | "EmulatorDropDown"
    | "ColorPickerFrame"
    | "CurrentMarker"
    | "Border"
    | "DropShadow"
    | "Shadow"
    | "Light"
    | "Dark"
    | "Mid"
    | "MainText"
    | "SubText"
    | "TitlebarText"
    | "BrightText"
    | "DimmedText"
    | "LinkText"
    | "WarningText"
    | "ErrorText"
    | "InfoText"
    | "SensitiveText"
    | "ScriptSideWidget"
    | "ScriptBackground"
    | "ScriptText"
    | "ScriptSelectionText"
    | "ScriptSelectionBackground"
    | "ScriptFindSelectionBackground"
    | "ScriptMatchingWordSelectionBackground"
    | "ScriptOperator"
    | "ScriptNumber"
    | "ScriptString"
    | "ScriptComment"
    | "ScriptKeyword"
    | "ScriptBuiltInFunction"
    | "ScriptWarning"
    | "ScriptError"
    | "ScriptInformation"
    | "ScriptHint"
    | "ScriptWhitespace"
    | "ScriptRuler"
    | "DocViewCodeBackground"
    | "DebuggerCurrentLine"
    | "DebuggerErrorLine"
    | "DiffFilePathText"
    | "DiffTextHunkInfo"
    | "DiffTextNoChange"
    | "DiffTextAddition"
    | "DiffTextDeletion"
    | "DiffTextSeparatorBackground"
    | "DiffTextNoChangeBackground"
    | "DiffTextAdditionBackground"
    | "DiffTextDeletionBackground"
    | "DiffLineNum"
    | "DiffLineNumSeparatorBackground"
    | "DiffLineNumNoChangeBackground"
    | "DiffLineNumAdditionBackground"
    | "DiffLineNumDeletionBackground"
    | "DiffFilePathBackground"
    | "DiffFilePathBorder"
    | "ChatIncomingBgColor"
    | "ChatIncomingTextColor"
    | "ChatOutgoingBgColor"
    | "ChatOutgoingTextColor"
    | "ChatModeratedMessageColor"
    | "Separator"
    | "ButtonBorder"
    | "ButtonText"
    | "InputFieldBorder"
    | "CheckedFieldBackground"
    | "CheckedFieldBorder"
    | "CheckedFieldIndicator"
    | "HeaderSection"
    | "Midlight"
    | "StatusBar"
    | "DialogButton"
    | "DialogButtonText"
    | "DialogButtonBorder"
    | "DialogMainButton"
    | "DialogMainButtonText"
    | "InfoBarWarningBackground"
    | "InfoBarWarningText"
    | "ScriptEditorCurrentLine"
    | "ScriptMethod"
    | "ScriptProperty"
    | "ScriptNil"
    | "ScriptBool"
    | "ScriptFunction"
    | "ScriptLocal"
    | "ScriptSelf"
    | "ScriptLuauKeyword"
    | "ScriptFunctionName"
    | "ScriptTodo"
    | "ScriptBracket"
    | "AttributeCog"
    | "AICOOverlayText"
    | "AICOOverlayButtonBackground"
    | "AICOOverlayButtonBackgroundHover"
    | "AICOOverlayButtonBackgroundPressed"
    | "OnboardingCover"
    | "OnboardingHighlight"
    | "OnboardingShadow"
    | "BreakpointMarker"
    | "DiffLineNumHover"
    | "DiffLineNumSeparatorBackgroundHover"

export type GuideModifier =
    | "Default"
    | "Selected"
    | "Pressed"
    | "Disabled"
    | "Hover"

export type ThemeColors = {
    [GuideModifier]: Color3
}

export type ThemeState = {
    [GuideColor]: ThemeColors
}

local Studio = settings().Studio
local ThemeContext = React.createContext({} :: ThemeState)

local function ThemeProvider(props)
    local theme = useProperty.State(Studio, "Theme")
    local colors = {} :: ThemeState

    for _, color in Enum.StudioStyleGuideColor:GetEnumItems() do
        local modifiers = {} :: ThemeColors

        for _, modifier in Enum.StudioStyleGuideModifier:GetEnumItems() do
            modifiers[modifier.Name :: any] = theme:GetColor(color, modifier)
        end

        colors[color.Name :: any] = modifiers
    end

    return React.createElement(ThemeContext.Provider, {
        value = colors
    }, props.children)
end

return {
    Context = ThemeContext,
    Provider = ThemeProvider,
}