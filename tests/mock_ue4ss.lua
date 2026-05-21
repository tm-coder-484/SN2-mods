-- Stubs for UE4SS globals — lets unit tests run with plain Lua (no game)
FindAllOf = function(className) return {} end
FindFirstOf = function(className) return nil end
StaticFindObject = function(path) return nil end
RegisterHook = function(path, pre, post) return 1 end
RegisterInitGameStatePostHook = function(fn) end
