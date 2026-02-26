using Clang.Generators
using Clang
using JuliaFormatter: format

cd(@__DIR__)

# Path to the s2geography_c header.
# When a JLL package exists, replace this with:
#   include_dir = joinpath(S2GeographyC_jll.artifact_dir, "include") |> normpath
include_dir = normpath(joinpath(@__DIR__, "..", "..", "s2geography_c", "include"))

options = load_options(joinpath(@__DIR__, "generator.toml"))

args = get_default_args()
push!(args, "-I$include_dir")

headers = [joinpath(include_dir, "s2geography_c.h")]

# create context
ctx = create_context(headers, args, options)

# build — parse headers, generate expression DAG, print to output file
build!(ctx, BUILDSTAGE_NO_PRINTING)

# Custom rewriting pass: wrap const char* returns in unsafe_string(),
# and wrap char* returns in string_copy_free().
function rewrite!(dag::Clang.Generators.ExprDAG)
    for node in dag.nodes
        # Only process function declarations
        if !isa(node.cursor, Clang.CLFunctionDecl)
            continue
        end

        for (i, expr) in enumerate(node.exprs)
            node.exprs[i] = rewrite_expr(expr, node.cursor)
        end
    end
end

"""
Check if a function's return type is `const char*`.
"""
function is_const_char_ptr_return(cursor::Clang.CLFunctionDecl)
    result_type = Clang.getCanonicalType(Clang.getCursorResultType(cursor))
    if result_type isa Clang.CLPointer
        pointee = Clang.getPointeeType(result_type)
        return pointee isa Clang.CLChar_S && Clang.isConstQualifiedType(pointee)
    end
    return false
end

"""
Rewrite a generated expression. Functions returning `Cstring` (from `const char*`)
get wrapped in `unsafe_string()`.
"""
function rewrite_expr(ex::Expr, cursor::Clang.CLFunctionDecl)
    # Match: function fname(args...) @ccall lib.cname(cargs...)::rettype end
    if Meta.isexpr(ex, :function) && length(ex.args) == 2
        body = ex.args[2]
        if Meta.isexpr(body, :block)
            for (j, stmt) in enumerate(body.args)
                if Meta.isexpr(stmt, :macrocall) && stmt.args[1] == Symbol("@ccall")
                    # Check if return type is Cstring
                    ccall_expr = stmt
                    # The @ccall macro expression structure:
                    # Expr(:macrocall, Symbol("@ccall"), LineNumberNode, call_expr)
                    # where call_expr is: Expr(:(::), Expr(:call, ...), return_type)
                    if length(ccall_expr.args) >= 3
                        call_part = ccall_expr.args[end]
                        if Meta.isexpr(call_part, :(::)) && call_part.args[end] == :Cstring
                            if is_const_char_ptr_return(cursor)
                                # const char* — wrap in unsafe_string, no free needed
                                body.args[j] = :(unsafe_string($ccall_expr))
                            end
                        end
                    end
                end
            end
        end
    end
    return ex
end

rewrite!(ctx.dag)
build!(ctx, BUILDSTAGE_PRINTING_ONLY)

# Format the generated output
output_path = normpath(joinpath(@__DIR__, "..", "src", "generated"))
if isdir(output_path)
    format(output_path)
end
