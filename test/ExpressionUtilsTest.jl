using FactCheck
using ExpressionUtils

@facts "Expression destructuring" begin

    @fact "expr_bindings" begin

        expr_bindings(:(x = 5), :(x = _val_)) => {:_val_ => 5}
        expr_bindings(:(x = 5), :(_sym_ = 5)) => {:_sym_ => :x}
        expr_bindings(:(x = 5), :_ex_) => {:_ex_ => :(x = 5)}

        splatex = Expr(:let, :_body_, :_SPLAT_bindings_)
        ex = :(let x=1, y=2, z=3
                   x + y
                   y + z
               end)

        bindings = expr_bindings(ex, splatex)

        haskey(bindings, :_body_) => true
        haskey(bindings, :_bindings_) => true
        bindings[:_body_] => body -> isa(body, Expr) && body.head == :block
        bindings[:_bindings_] => b -> isa(b, Array) && length(b) == 3

    end

    @fact "expr_replace" begin

        ex = quote
            let x=1, y=2, z=3
                bar
                x + y
                y + z
            end
        end

        template = quote
            let _SPLAT_bindings_
                _funname_
                _SPLAT_body_
            end
        end

        out = quote
            function _funname_(; _UNSPLAT_bindings_)
                _UNSPLAT_body_
            end
        end

        foofun = expr_replace(ex, template, out)

        foofun.head => :function
        eval(foofun)() => 5
        bar() => 5

    end

end
