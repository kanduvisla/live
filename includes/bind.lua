-- Bind the scope to a function
function bind(fn, obj)
    return function(...)
        return fn(obj, ...)
    end
end