module ExpressionUtils

export walk, expr_replace, expr_bind, expr_bindings

immutable Remove end

# Recursively walk an Expr, applying a function to each subexpr and leaf to
# build up a new Expr. If the function returns an Expr, that Expr will be
# walked as well. If the function returns the singleton value
# ExpressionUtils.Remove, that node will be removed.
#
walk(f, leaf) = f(leaf)
function walk(f, ex::Expr)
    ex = copy(ex)

    function reducer(args, e)
        e = f(e)
        is(e, Remove) ? args :
        isa(e, Expr)    ? push!(args, walk(f, e)) :
        push!(args, e)
    end

    ex.args = reduce(reducer, Any[], ex.args)
    ex
end

getesc(d::Dict, k, default) = haskey(d, k) ? esc(d[k]) : default

Base.map(f, ex::Expr) =
    Expr(ex.head, [isa(e, Expr) ? map(f, e) : f(e) for e in ex.args]...)

remove_quote_block(val) = val
remove_quote_block(ex::Expr) =
    ex.head == :block && length(ex.args) == 2 ? ex.args[2] : ex

remove_line_ann(ex::Expr) =
    walk((e) -> isa(e, Expr) && e.head == :line ? Remove : e, ex)

symbeginswith(sym, s) = beginswith(string(sym), s)
issplat(sym)   = isa(sym, Symbol) && symbeginswith(sym, "_SPLAT_")
isunsplat(sym) = isa(sym, Symbol) && symbeginswith(sym, "_UNSPLAT_")
isesc(sym)     = isa(sym, Symbol) && symbeginswith(sym, "_ESC_")
function istemplate(sym::Symbol)
    s = string(sym)
    s[1] == '_' && s[end] == '_'
end

removeprefix(sym) =
    if issplat(sym)
        symbol(string(sym)[7:end])
    elseif isunsplat(sym)
        symbol(string(sym)[9:end])
    elseif isesc(sym)
        symbol(string(sym)[5:end])
    else
        sym
    end

function expr_bindings(ex, template::Symbol, collected::Dict)
    if isesc(template)
        collected[removeprefix(template)] = esc(ex)
    elseif istemplate(template)
        collected[template] = ex
    end
    collected
end
function expr_bindings(ex::Expr, template::Expr, collected::Dict)
    ex.head == template.head || error("Cannot bind dissimilar syntax:\n$ex\nto\n$template")
    for (i, (exsub, templatesub)) in enumerate(zip(ex.args, template.args))
        if issplat(templatesub)
            collected[removeprefix(templatesub)] = ex.args[i:end]
            break
        end
        expr_bindings(exsub, templatesub, collected)
    end
    collected
end
expr_bindings(ex, template, collected) = collected
expr_bindings(ex, template) =
    expr_bindings(ex, template, Dict{Symbol, Any}())

function unsplat(ex::Expr, bindings::Dict)
    r = (args, e) -> isunsplat(e) ?
                     vcat(args, get(bindings, removeprefix(e), {e})) :
                     push!(args, get(bindings, removeprefix(e), e))

    ex = copy(ex)
    ex.args = reduce(r, {}, ex.args)
    ex
end

function expr_bind(ex::Expr, bindings::Dict)
    walker(e::Expr) = unsplat(e, bindings)
    walker(s::Symbol) = get(bindings, removeprefix(s), s)
    walker(e) = e

    ex = copy(ex)

    walk(walker, ex)
end

function expr_replace(ex, template, out)
    ex, template, out = map((e) -> remove_line_ann(remove_quote_block(e)),
                            {ex, template, out})

    bindings = expr_bindings(ex, template)

    expr_bind(remove_quote_block(out), bindings)
end

end # module ExpressionUtils
