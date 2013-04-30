## Expression Utilities

Useful functions for working with the Julia `Expr` type.

#### `map(f::Function, e::Expr)`

Constructs a new expression similar to `e`, but having had the function
`f` applied to every leaf.

```.jl
julia> map(x -> isa(x, Int) ? x + 1 : x, :(1 + 1))
# => :(+(2,2))
```

#### `walk(f::Function, e::Expr)`

Recursively walk an expression, applying a function `f` to each
subexpression and leaf in `e`. If the function application returns an
expression, that expression will be walked as well. The function can
return the special type `ExpressionUtils.Remove` to indicate that a
subexpression should be omitted.

```.jl
julia> b = quote
         let x=1, y=2, z=3
           x + y + z
         end
       end
# => quote  # none, line 2:
#        let x = 1, y = 2, z = 3 # line 3:
#            +(x,y,z)
#        end
#    end

julia> isline(ex) = isa(ex, Expr) && ex.head == :line
# methods for generic function isline
isline(ex) at none:1

julia> walk(ex -> isline(ex) ? ExpressionUtils.Remove : ex, b)
# => quote
#        let x = 1, y = 2, z = 3
#            +(x,y,z)
#        end
#    end
```

#### `expr_replace(ex, template, out)`

Syntax rewriting!

```.jl
julia> ex = quote
           let x=1, y=2, z=3
               bar
               x + y
               y + z
           end
       end

julia> template = quote
           let _SPLAT_bindings_
               _funname_
               _SPLAT_body_
           end
       end

julia> out = quote
           function _funname_(; _UNSPLAT_bindings_)
               _UNSPLAT_body_
           end
       end

julia> fnexpr = expr_replace(ex, template, out)
# => :(function bar($(Expr(:parameters, :(x = 1), :(y = 2), :(z = 3))))
#          +(x,y)
#          +(y,z)
#      end)

julia> eval(fnexpr)

julia> bar()
# methods for generic function bar
bar()

julia> bar()
# => 5
```

Plays well with macros. See
[ValueDispatch.jl](https://github.com/zachallaun/ValueDispatch.jl/blob/master/src/ValueDispatch.jl)
for another example.
