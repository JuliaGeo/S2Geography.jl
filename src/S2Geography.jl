"""
    S2Geography

Julia bindings for [s2geography](https://github.com/paleolimbot/s2geography), a
geometry library built on Google's [S2](http://s2geometry.io).

S2 works on the sphere rather than the plane: edges are geodesics, and
predicates and measures are exact for geographic coordinates without choosing a
projection first. Distances and areas are reported in metres and square metres.

The central type is [`Geography`](@ref), which implements the GeoInterface
traits and so interoperates with the rest of the JuliaGeo ecosystem.

```julia
using S2Geography

germany = Geography("POLYGON ((5 47, 15 47, 15 55, 5 55, 5 47))")
berlin  = Geography("POINT (13.405 52.52)")

contains(germany, berlin)          # true
area(germany) / 1e6                # square kilometres
distance(berlin, Geography("POINT (2.35 48.86)")) / 1000   # km to Paris
```

Every operation also accepts vectors of geographies and runs them as a single
batch, with scalar arguments broadcasting against vector ones:

```julia
inside = contains(germany, cities)   # Vector{Bool}
sizes  = area(countries)             # Vector{Float64}
```

Batching is worth preferring: a scalar call to a measure, construction or
transformation renegotiates the underlying kernel's return type each time, so
running them one at a time costs roughly five to seven times as much per
element. The six boolean predicates are the exception, having a dedicated
scalar path that is already fast element-by-element.
"""
module S2Geography

using GeoInterface: GeoInterface
using GeoFormatTypes: GeoFormatTypes
using WellKnownGeometry: WellKnownGeometry
using Extents: Extents

const GI = GeoInterface
const GFT = GeoFormatTypes

include("capi.jl")
include("errors.jl")
include("arrow.jl")
include("wkt.jl")
include("geography.jl")
include("kernels.jl")
include("geointerface.jl")
include("operations.jl")

export Geography
export towkb, towkt, prepare!, memory_used
# predicates (`contains` extends Base, so it needs no export)
export intersects, within, equals, disjoint, dwithin
# measures
export area, perimeter, arclength, distance, max_distance
# constructions
export centroid, convex_hull, boundary, point_on_surface
export closest_point, shortest_line, longest_line
export intersection, difference, sym_difference
# transformations
export simplify, buffer, reduce_precision, segmentize, tessellate, tessellate_planar
# linear referencing
export line_interpolate_point, line_locate_point
# S2 cells
export cellid, covering

function __init__()
    _init_release_callbacks!()
    _init_arg_schemas!()
    _load_kernels!()
    CONTEXT[] = Context()
    return nothing
end

end # module
