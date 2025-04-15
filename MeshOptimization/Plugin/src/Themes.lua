local Themes: {
    [string]: {
        [string]: any
    }
}

Themes = {
    Div = {
        BackgroundColor3 = Enum.StudioStyleGuideColor.Border,
    },

    Text = {
        TextColor3 = Enum.StudioStyleGuideColor.MainText,
    },

    Input = {
        BackgroundColor3 = Enum.StudioStyleGuideColor.InputFieldBackground,
        BorderColor3 = Enum.StudioStyleGuideColor.InputFieldBorder,
        PlaceholderColor3 = Enum.StudioStyleGuideColor.MainText,
        TextColor3 = Enum.StudioStyleGuideColor.LinkText,
    },

    Window = {
        BorderColor3 = Enum.StudioStyleGuideColor.Border,
        BackgroundColor3 = Enum.StudioStyleGuideColor.MainBackground,
        ScrollBarImageColor3 = Enum.StudioStyleGuideColor.ScrollBar,
    }
}

return Themes