local Root = script.Parent.Parent
local React = require(Root.Packages.React)

type function not_nil(ty: type)
    if ty.tag == "union" then
        local comps = ty:components()

        if #comps == 2 then
            local nilType = types.singleton(nil)
            local a, b = unpack(comps)

            if a == nilType then
                return b
            elseif b == nilType then
                return a
            end
        end
    end

    return ty
end

type function opt_if_nil(nullable: type, ty: type)
    if nullable:is("union") then
        local comps = nullable:components()
        
        if #comps == 2 then
            local nilType = types.singleton(nil)

            if table.find(comps, nilType) then
                return types.optional(ty)
            end
        end
    end

    return ty
end

type function props_of(ty: type?)
    if ty == nil then
        return types.never
    end

    local props = {}

    while ty ~= nil do
        for name, rw in ty:properties() do
            local read = rw.read

            if read then
                if read:is("function") then
                    continue
                end

                table.insert(props, name)
            end
        end

        ty = ty:readparent()
    end

    return types.unionof(table.unpack(props))
end

type IPropertyName<T, PropName> = ((PropName & props_of<not_nil<T>>) | "")
type Property<T, PropName> = opt_if_nil<T, index<not_nil<T>, not_nil<PropName>>>

local function usePropertyState<T, PropName>(instance: T, propName: IPropertyName<T, PropName>?): Property<T, PropName>
    type value_type = Property<T, PropName>

    local value, setValue = React.useState<<value_type>>(function ()
        if instance and propName then
            return (instance :: any)[propName]
        end

        return nil
    end)

    React.useEffect(function ()
        if instance and propName then
            local upcast = instance :: Instance
            local listener = upcast:GetPropertyChangedSignal(propName)

            local conn = listener:Connect(function ()
                local newValue = (instance :: any)[propName]
                setValue(newValue)
            end)

            return function ()
                conn:Disconnect()
            end
        end

        return nil :: any
    end, {
        instance,
        propName,
    } :: { any })

    React.useEffect(function ()
        local newValue = if instance and propName
            then (instance :: any)[propName]
            else nil

        if value ~= newValue then
            setValue(newValue)
        end
    end, {
        instance,
        propName,
        value,
    } :: { any })

    return value
end

local function usePropertyBinding<T, PropName>(instance: T, propName: IPropertyName<T, PropName>?): React.Binding<Property<T, PropName>>
    type value_type = Property<T, PropName>

    local initialValue: value_type = React.useMemo(function ()
        if instance and propName then
            return (instance :: any)[propName]
        end

        return nil
    end, {})

    local value, setValue = React.useBinding<<value_type>>(initialValue)

    React.useEffect(function ()
        if instance and propName then
            local upcast = instance :: Instance
            local listener = upcast:GetPropertyChangedSignal(propName)

            local conn = listener:Connect(function ()
                local newValue = (instance :: any)[propName]
                setValue(newValue)
            end)

            return function ()
                conn:Disconnect()
            end
        end

        return nil :: any
    end, {
        instance,
        propName,
    } :: { any })

    React.useEffect(function ()
        local newValue = if instance and propName
            then (instance :: any)[propName]
            else nil

        if value ~= newValue then
            setValue(newValue)
        end
    end, {
        instance,
        propName,
        value,
    } :: { any })

    return value
end

return {
    State = usePropertyState,
    Binding = usePropertyBinding,
}