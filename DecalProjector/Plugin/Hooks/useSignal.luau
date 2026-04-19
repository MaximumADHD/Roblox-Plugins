--!strict

local Root = script.Parent.Parent
local Packages = Root.Packages

local React = require(Packages.React)
local Signal = require(Packages.Signal)

type Signal<T...> = 
    | Signal.Signal<T...>
    | RBXScriptSignal<T...>

local function useSignal<T...>(signal: Signal<T...>?, callback: (T...) -> ()?, deps: {any}?)
    if deps and not table.find(deps, signal) then
        table.insert(deps, signal)
    end

    React.useEffect(function ()
        local signal: Signal<T...>? = signal :: any
        local conn = (signal and callback) and (signal :: any):Connect(callback)

        return function ()
            if conn then
                conn:Disconnect()
            end
        end
    end, deps)
end

return useSignal