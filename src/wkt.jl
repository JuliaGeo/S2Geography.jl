#
# A small recursive-descent WKT reader that emits WKB.
#
# WKB is this package's interchange format in both directions, so parsing
# straight to it avoids an intermediate geometry representation. We read our own
# WKT rather than reusing WellKnownGeometry's because that reader splits
# GEOMETRYCOLLECTION members on commas without tracking nesting, and mis-parses
# any collection whose members contain commas of their own.
#

const WKB_POINT = UInt32(1)
const WKB_LINESTRING = UInt32(2)
const WKB_POLYGON = UInt32(3)
const WKB_MULTIPOINT = UInt32(4)
const WKB_MULTILINESTRING = UInt32(5)
const WKB_MULTIPOLYGON = UInt32(6)
const WKB_GEOMETRYCOLLECTION = UInt32(7)

const WKT_TAGS = Dict(
    "POINT" => WKB_POINT,
    "LINESTRING" => WKB_LINESTRING,
    "LINEARRING" => WKB_LINESTRING,   # not standard WKB; S2 has no ring type
    "POLYGON" => WKB_POLYGON,
    "MULTIPOINT" => WKB_MULTIPOINT,
    "MULTILINESTRING" => WKB_MULTILINESTRING,
    "MULTIPOLYGON" => WKB_MULTIPOLYGON,
    "GEOMETRYCOLLECTION" => WKB_GEOMETRYCOLLECTION,
)

"""
    WKTParseError <: Exception

Raised when a string handed to [`Geography`](@ref) is not valid well-known text.

`pos` is the one-based character offset at which parsing stopped; displaying the
error underlines it in the original `input`.

```julia
julia> Geography("POINT (1 2")
ERROR: WKTParseError: expected ')' at position 11
  POINT (1 2
            ^
```
"""
struct WKTParseError <: Exception
    msg::String
    pos::Int
    input::String
end

function Base.showerror(io::IO, e::WKTParseError)
    print(io, "WKTParseError: ", e.msg, " at position ", e.pos)
    print(io, "\n  ", e.input)
    print(io, "\n  ", " "^max(0, e.pos - 1), "^")
    return nothing
end

mutable struct WKTReader
    s::String
    pos::Int
end

@inline _err(r::WKTReader, msg) = throw(WKTParseError(msg, r.pos, r.s))

function _skipspace!(r::WKTReader)
    while r.pos <= ncodeunits(r.s) && isspace(r.s[r.pos])
        r.pos = nextind(r.s, r.pos)
    end
    return nothing
end

function _peek(r::WKTReader)
    _skipspace!(r)
    return r.pos <= ncodeunits(r.s) ? r.s[r.pos] : '\0'
end

function _expect!(r::WKTReader, c::Char)
    _peek(r) == c || _err(r, "expected '$c'")
    r.pos = nextind(r.s, r.pos)
    return nothing
end

function _accept!(r::WKTReader, c::Char)
    _peek(r) == c || return false
    r.pos = nextind(r.s, r.pos)
    return true
end

"""
    _word!(r) -> String

Read an alphabetic keyword (a geometry tag, `EMPTY`, or a `Z`/`M`/`ZM` marker),
upper-cased.
"""
function _word!(r::WKTReader)
    _skipspace!(r)
    start = r.pos
    while r.pos <= ncodeunits(r.s) && isletter(r.s[r.pos])
        r.pos = nextind(r.s, r.pos)
    end
    return uppercase(r.s[start:prevind(r.s, r.pos)])
end

function _number!(r::WKTReader)
    _skipspace!(r)
    start = r.pos
    while r.pos <= ncodeunits(r.s)
        c = r.s[r.pos]
        (isdigit(c) || c in ('+', '-', '.', 'e', 'E')) || break
        r.pos = nextind(r.s, r.pos)
    end
    start == r.pos && _err(r, "expected a number")
    text = r.s[start:prevind(r.s, r.pos)]
    v = tryparse(Float64, text)
    v === nothing && _err(r, "invalid number \"$text\"")
    return v
end

"""
    _coord!(r) -> Tuple{Float64,Float64}

Read one coordinate. Any ordinates past x and y (Z, M) are parsed and dropped:
S2 is a two-dimensional spherical model, so there is nothing to carry them into.
"""
function _coord!(r::WKTReader)
    x = _number!(r)
    y = _number!(r)
    while true
        c = _peek(r)
        (isdigit(c) || c in ('+', '-', '.')) || break
        _number!(r)
    end
    return (x, y)
end

function _coords!(r::WKTReader)
    _expect!(r, '(')
    pts = Tuple{Float64,Float64}[]
    if !_accept!(r, ')')
        while true
            # MULTIPOINT permits both "(0 0, 1 1)" and "((0 0), (1 1))".
            parenthesised = _accept!(r, '(')
            push!(pts, _coord!(r))
            parenthesised && _expect!(r, ')')
            _accept!(r, ',') || break
        end
        _expect!(r, ')')
    end
    return pts
end

_write_point!(io::IO, x, y) = (write(io, Float64(x)); write(io, Float64(y)); nothing)

function _write_ring!(io::IO, pts)
    write(io, UInt32(length(pts)))
    for (x, y) in pts
        _write_point!(io, x, y)
    end
    return nothing
end

_write_header!(io::IO, type::UInt32) = (write(io, 0x01); write(io, type); nothing)

"""
    _isempty!(r) -> Bool

Consume an `EMPTY` marker if present.
"""
function _isempty!(r::WKTReader)
    save = r.pos
    if _word!(r) == "EMPTY"
        return true
    end
    r.pos = save
    return false
end

function _geometry!(io::IO, r::WKTReader)
    tag = _word!(r)
    isempty(tag) && _err(r, "expected a geometry type")
    type = get(WKT_TAGS, tag, nothing)
    type === nothing && _err(r, "unknown geometry type \"$tag\"")

    # Optional dimensionality marker; the ordinates themselves are dropped.
    save = r.pos
    marker = _word!(r)
    marker in ("Z", "M", "ZM") || (r.pos = save)

    if type == WKB_POINT
        _write_header!(io, type)
        if _isempty!(r)
            # WKB has no empty point, so the conventional NaN encoding is used.
            _write_point!(io, NaN, NaN)
        else
            _expect!(r, '(')
            x, y = _coord!(r)
            _expect!(r, ')')
            _write_point!(io, x, y)
        end
    elseif type == WKB_LINESTRING
        _write_header!(io, type)
        _write_ring!(io, _isempty!(r) ? Tuple{Float64,Float64}[] : _coords!(r))
    elseif type == WKB_POLYGON
        _write_header!(io, type)
        if _isempty!(r)
            write(io, UInt32(0))
        else
            _expect!(r, '(')
            rings = Vector{Tuple{Float64,Float64}}[]
            if !_accept!(r, ')')
                while true
                    push!(rings, _coords!(r))
                    _accept!(r, ',') || break
                end
                _expect!(r, ')')
            end
            write(io, UInt32(length(rings)))
            foreach(ring -> _write_ring!(io, ring), rings)
        end
    elseif type == WKB_MULTIPOINT
        _write_header!(io, type)
        pts = _isempty!(r) ? Tuple{Float64,Float64}[] : _coords!(r)
        write(io, UInt32(length(pts)))
        for (x, y) in pts
            _write_header!(io, WKB_POINT)
            _write_point!(io, x, y)
        end
    else
        # MULTILINESTRING, MULTIPOLYGON and GEOMETRYCOLLECTION are all a count
        # followed by complete child geometries. The first two elide their
        # children's tags, so we supply them.
        child_tag = type == WKB_MULTILINESTRING ? "LINESTRING" :
                    type == WKB_MULTIPOLYGON ? "POLYGON" : nothing
        _write_header!(io, type)
        if _isempty!(r)
            write(io, UInt32(0))
            return nothing
        end
        _expect!(r, '(')
        parts = IOBuffer[]
        if _peek(r) != ')'
            while true
                buf = IOBuffer()
                if child_tag === nothing
                    _geometry!(buf, r)
                else
                    # Re-enter the parser positioned at the child's body by
                    # splicing in the tag it left implicit.
                    _geometry!(buf, WKTReader(child_tag * _child_body!(r), 1))
                end
                push!(parts, buf)
                _accept!(r, ',') || break
            end
        end
        _expect!(r, ')')
        write(io, UInt32(length(parts)))
        foreach(p -> write(io, take!(p)), parts)
    end
    return nothing
end

"""
    _child_body!(r) -> String

Consume a balanced parenthesised group (or `EMPTY`) and return its text, used
for multi-geometry members whose type tag is implied by the parent.
"""
function _child_body!(r::WKTReader)
    _skipspace!(r)
    if _peek(r) != '('
        _isempty!(r) || _err(r, "expected '(' or EMPTY")
        return " EMPTY"
    end
    start = r.pos
    depth = 0
    while r.pos <= ncodeunits(r.s)
        c = r.s[r.pos]
        c == '(' && (depth += 1)
        c == ')' && (depth -= 1)
        r.pos = nextind(r.s, r.pos)
        depth == 0 && break
    end
    depth == 0 || _err(r, "unbalanced parentheses")
    return r.s[start:prevind(r.s, r.pos)]
end

"""
    wkt_to_wkb(wkt) -> Vector{UInt8}

Parse well-known text into little-endian well-known binary.
"""
function wkt_to_wkb(wkt::AbstractString)
    r = WKTReader(String(wkt), 1)
    io = IOBuffer()
    _geometry!(io, r)
    _skipspace!(r)
    r.pos <= ncodeunits(r.s) && _err(r, "unexpected trailing input")
    return take!(io)
end
