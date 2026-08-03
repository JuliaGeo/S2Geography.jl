# S2Geography.jl

Julia bindings for [s2geography](https://github.com/paleolimbot/s2geography), a
geometry library built on Google's [S2](https://s2geometry.io).

S2 works on the sphere rather than the plane. Edges are geodesics, and
predicates and measures are exact for longitude/latitude coordinates without
having to pick a projection first — no distortion near the poles, no
antimeridian special cases, no dateline-crossing bugs.

Distances and areas are reported in SI **metres** and **square metres** on the
WGS84 mean sphere (radius 6371008.7714 m).

Binaries come from
[`S2Geography_jll`](https://github.com/JuliaBinaryWrappers/S2Geography_jll.jl),
so there is nothing to build.

## Installation

```julia
using Pkg
Pkg.add("S2Geography")
```

## Quick start

```@example quickstart
using S2Geography
import GeoInterface as GI

germany = Geography("POLYGON ((5 47, 15 47, 15 55, 5 55, 5 47))")
berlin  = Geography("POINT (13.405 52.52)")
paris   = Geography("POINT (2.3522 48.8566)")

contains(germany, berlin)
```

```@example quickstart
area(germany) / 1e6            # square kilometres
```

```@example quickstart
distance(berlin, paris) / 1000 # kilometres
```

## Batching

Every operation also accepts vectors and runs them as a single batch. Scalar
arguments broadcast against vector ones.

```@example quickstart
cities = Geography.(["POINT (13.4 52.5)", "POINT (2.4 48.9)", "POINT (-74.0 40.7)"])

contains(germany, cities)
```

```@example quickstart
round.(distance(germany, cities) ./ 1000; digits=1)   # km to Germany
```

Each argument may be a vector in its own right, so per-element parameters work
too:

```@example quickstart
area.(buffer(cities, [1000, 2000, 3000])) ./ 1e6
```

Batching is worth reaching for. Every scalar call to a measure, construction or
transformation has to renegotiate the underlying kernel's return type, so doing
them one at a time costs around 3.7 µs each; in a batch that happens once and
the per-element cost falls to around 0.9 µs — roughly **5–7× faster** for
[`area`](@ref), [`centroid`](@ref), [`distance`](@ref) and their kin. The six
boolean predicates are the exception: they have a dedicated scalar path and are
already quick one at a time, so batching them is about break-even.

!!! note "`union` is not exported"
    `union(a, b)` works for two geographies through a method on `Base.union`.
    It is deliberately not extended to vectors, because `union(v1, v2)` already
    means set union there and silently redefining it would be a trap. Use
    `S2Geography.union(as, bs)` for the batching form.

## Spherical, not planar

The difference from a planar library shows up as soon as geometries get large.
A line from 45°W to 45°E along the 45th parallel is a *geodesic*: it bows
polewards, so its bounding box reaches almost 55°N — something no planar
bounding box would report.

```@example quickstart
GI.extent(Geography("LINESTRING (-45 45, 45 45)"))
```

Areas shrink towards the poles, as they should:

```@example quickstart
equator = area(Geography("POLYGON ((0 0, 1 0, 1 1, 0 1, 0 0))")) / 1e6
north   = area(Geography("POLYGON ((0 60, 1 60, 1 61, 0 61, 0 60))")) / 1e6
(equator, north)
```

## Feature summary

- **Predicates** — [`contains`](@ref), [`within`](@ref), [`intersects`](@ref),
  [`disjoint`](@ref), [`equals`](@ref), [`dwithin`](@ref)
- **Measures** — [`area`](@ref), [`perimeter`](@ref), [`arclength`](@ref),
  [`distance`](@ref), [`max_distance`](@ref)
- **Constructions** — [`centroid`](@ref), [`convex_hull`](@ref),
  [`boundary`](@ref), [`point_on_surface`](@ref), [`closest_point`](@ref),
  [`shortest_line`](@ref), [`longest_line`](@ref)
- **Overlays** — [`intersection`](@ref), [`S2Geography.union`](@ref),
  [`difference`](@ref), [`sym_difference`](@ref)
- **Transformations** — [`simplify`](@ref), [`buffer`](@ref),
  [`reduce_precision`](@ref), [`segmentize`](@ref), [`tessellate`](@ref),
  [`tessellate_planar`](@ref)
- **Linear referencing** — [`line_interpolate_point`](@ref),
  [`line_locate_point`](@ref)
- **S2 cells** — [`cellid`](@ref), [`covering`](@ref)
- **Indexing** — [`prepare!`](@ref), [`memory_used`](@ref)
- Full [GeoInterface.jl](https://github.com/JuliaGeo/GeoInterface.jl) support,
  including a spherically-correct `GeoInterface.extent`
