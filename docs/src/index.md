# S2Geography.jl

Julia bindings for [s2geography](https://github.com/paleolimbot/s2geography), providing spherical geometry operations powered by Google's [S2Geometry](https://s2geometry.io/) library.

Unlike planar geometry libraries, S2Geography operates on the sphere, giving correct results for geographic data without projection artifacts.

## Features

- Spherical geometry predicates: `intersects`, `equals`, `contains`, `touches`
- Distance, area, length, and perimeter measurements (in radians/steradians)
- Geometry operations: `centroid`, `convex_hull`, `boundary`
- Boolean operations: `intersection`, `s2_union`, `difference`, `sym_difference`
- Full [GeoInterface.jl](https://github.com/JuliaGeo/GeoInterface.jl) support

## Installation

```julia
using Pkg
Pkg.add(url="https://github.com/JuliaGeo/S2Geography.jl")
```

!!! note
    This package currently requires a locally built `libs2geography_c` shared library
    with the path available via `LD_LIBRARY_PATH` / `DYLD_LIBRARY_PATH`.
    A JLL package is in progress.
