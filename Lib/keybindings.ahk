#Requires AutoHotkey v2+

#Include strings.ahk
#Include constants.ahk

class KeyBinding {
    class Survivor {
        static moveForward => InputMapping.getMapping().bindingFor("MoveForwardSurvivor", 1)
        static moveBack => InputMapping.getMapping().bindingFor("MoveForwardSurvivor", -1)
        static moveLeft => InputMapping.getMapping().bindingFor("MoveRightSurvivor", -1)
        static moveRight => InputMapping.getMapping().bindingFor("MoveRightSurvivor", 1)
        /**
         * Dead hard, Invocation: Spiders, etc.
         */
        static e => InputMapping.getMapping().bindingFor("Action_Camper", -1)
        /**
         * Invocation: Crows
         */
        static f => InputMapping.getMapping().bindingFor("AbilityTwo_Camper", -1)
        /**
         * Heal, repair, open chest, pick up item, etc.
         */
        static interact => InputMapping.getMapping().bindingFor("Interact_Camper", -1)
        /**
         * Med-kit, Flashlight, Toolbox
         */
        static useItem => InputMapping.getMapping().bindingFor("ItemUse_Camper")
        static gesturePoint => InputMapping.getMapping().bindingFor("Gesture01")
        static gestureComeHere => InputMapping.getMapping().bindingFor("Gesture02")
        /**
         * Modifier key
         */
        static run => InputMapping.getMapping().bindingFor("Run_Camper")
        /**
         * Modifier key
         */
        static crouch => InputMapping.getMapping().bindingFor("Crouch")
        /**
         * Wiggle, etc.
         */
        static space => InputMapping.getMapping().bindingFor("SecondaryAction_Camper")

        static dropItem => InputMapping.getMapping().bindingFor("ItemDrop_Camper")
        static eventAbility => InputMapping.getMapping().bindingFor("EventAbility_Survivor")
    }

    class Killer {
        static moveForward => InputMapping.getMapping().bindingFor("MoveForwardKiller", 1)
        static moveBack => InputMapping.getMapping().bindingFor("MoveForwardKiller", -1)
        static moveLeft => InputMapping.getMapping().bindingFor("MoveRightKiller", -1)
        static moveRight => InputMapping.getMapping().bindingFor("MoveRightKiller", 1)
    }
}

/**
 * Parsed mappings from Input.ini
 */
class InputMapping {
    /**
     * Mapping of Input.ini keys (bindingKey(...)) to AHK keys (e.g. ^LButton.)
     */
    ahkKeys := Map()

    /**
     * DBD process path -> InputMapping
     */
    static pathCache := Map()

    /**
     * Gets the InputMapping for the current DBD process.
     * Caches the mappings until the macro is restarted.
     */
    static getMapping() {
        dbdPath := WinGetProcessPath(dbdWinTitle)
        if not InputMapping.pathCache.Has(dbdPath) {
            mapping := InputMapping.parseMappingFor(dbdPath)
            InputMapping.pathCache[dbdPath] := mapping
            return mapping
        } else {
            return InputMapping.pathCache[dbdPath]
        }
    }

    /**
     * Parse the Config/.../Input.ini for some DBD.exe filesystem path.
     */
    static parseMappingFor(dbdPath) {
        SplitPath(dbdPath, &fileName)
        platform := ""
        switch fileName {
            case "DeadByDaylight-EGS-Shipping.exe": platform := "EGS"
            case "DeadByDaylight-Win64-Shipping.exe": platform := "WindowsClient"
            case "DeadByDaylight-WinGDK-Shipping.exe": platform := "WinGDKClient"
            Default: throw Error("Unrecognized DBD process path: " dbdPath)
        }
        configPath := A_AppData "\..\Local\DeadByDaylight\Saved\Config\" platform "\Input.ini"
        mapping := InputMapping(configPath)
    }

    /**
     * Returns the AHK key code for use in Send(...).
     * Caller should always wrap the value in curly braces {} including any optional modifiers (down, up, etc.).
     * 
     * @param name DBD ActionName/AxisName
     * @param scale 1 or -1 for AxisName values
     * @returns {Object}
     */
    bindingFor(name, scale?) {
        key := IsSet(scale) ? this.ahkKeys.Get(InputMapping.bindingKey(name, scale)) : InputMapping.bindingKey(name)
        return this.ahkKeys[key]
    }

    /**
     * @param name DBD ActionName/AxisName
     * @param scale 1 or -1 for AxisName values
     * @returns {String} internal index key for this action
     */
    static bindingKey(name, scale?) {
        if not name
            throw Error("name is empty")

        if IsSet(scale) and not IsNumber(scale)
            throw Error("scale must be a number")

        return IsSet(scale) ? name "__" scale : name
    }

    __New(path) {
        lines := StrSplit(IniRead(path, "/Script/EnhancedInput.EnhancedPlayerInput"), "`n")

        parseBinding(line) {
            attrs := Map()

            ; ActionMappings=(ActionName="Action_Camper",bShift=False,bCtrl=False,bAlt=False,bCmd=False,Key=E)
            ; extract the content inside the parens.
            RegExMatch(line, ".*Mappings=\((.+)\)", &match)
            if match.Count == 1 {
                content := match[1]
                pairs := StrSplit(content, ',')

                for pair in pairs {
                    kv := StrSplit(pair, "=", 2)
                    key := parseValue(kv[1])
                    value := parseValue(kv[2])
                    attrs[key] := value
                }
            }

            return attrs
        }

        parseValue(value) {
            unwrapped := value
            len := StrLen(unwrapped)
            if len > 2 and StrEndsWith(value, '`"') and StrEndsWith(value, '`"') {
                unwrapped := SubStr(value, 2, len - 2)
            }
            switch {
                case unwrapped == "False": return false
                case unwrapped == "True": return true
                case IsNumber(unwrapped): return Number(unwrapped)
                default: return unwrapped
            }
        }

        ; Gather up all bindings, find the best one.
        bindings := Map()
        for line in lines {
            binding := parseBinding(line)

            if not binding.Has("Key") or StrStartsWith(binding["Key"], "Gamepad")
                continue

            if not binding.Has("ActionName") and not binding.Has("AxisName")
                continue

            ; Define an index key for the binding (not the physical key)
            bindingsKey := ""
            if binding.Has("ActionName")
                bindingsKey := InputMapping.bindingKey(binding["ActionName"])
            else
                bindingsKey := InputMapping.bindingKey(binding["AxisName"], binding["Scale"])

            if not bindings.Has(bindingsKey) or not InStr(binding["Key"], "Mouse") {
                ; Prefer non-mouse bindings since they're less flaky
                bindings[bindingsKey] := binding
            }
        }

        ; We don't need the full binding info details anymore.
        ; Preserve only the AHK versions.
        ahkKeys := Map()
        for k, binding in bindings {
            dbdKey := binding["Key"]
            ahkKey := InputMapping.dbdMappingToAhkKey(dbdKey)
            ahkKeys[k] := ahkKey
        }
        this.ahkKeys := ahkKeys

    }

    static dbdMappingToAhkKey(dbdMapping) {
        static mapping := Map(
            "Backslash", "\",
            "SpaceBar", "Space",
            "LeftMouseButton", "LButton",
            "RightMouseButton", "RButton",
            "MiddleMouseButton", "MButton",
            "ThumbMouseButton", "XButton1", ; TODO verify
            "ThumbMouseButton2", "XButton2", ; TODO verify
            "One", 1,
            "Two", 2,
            "Three", 3,
            "Four", 4,
            "Five", 5,
            "Six", 6,
            "Seven", 7,
            "Eight", 8,
            "Nine", 9,
            "Zero", 0,
        )

        key := dbdMapping["Key"]

        modifiers := ""
        if dbdMapping["bShift"]
            modifiers .= "+"
        if dbdMapping["bCtrl"]
            modifiers .= "^"
        if dbdMapping["bAlt"]
            modifiers .= "!"
        if dbdMapping["bCmd"]
            modifiers .= "#"

        rawKey := modifiers mapping.Get(key, key)
        return InputMapping.AhkKey(rawKey)
    }

    /**
     * Wraps a key value to Send().
     * Convenience down/up options, plus wrappings with curly braces (required for special keys).
     * I would otherwise forget to include them and wonder why it's literally sending each letter of "LButton" instead of clicking.
     */
    class AhkKey {
        __New(rawKey) {
            this.key := "{" rawKey "}"
            this.down := "{" rawKey " down}"
            this.up := "{" rawKey " up}"
            this.rawKey := rawKey
        }
    }
}