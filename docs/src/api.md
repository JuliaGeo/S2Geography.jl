# API Reference

```@meta
CurrentModule = S2Geography
```

```@docs
S2Geography
```

## The `Geography` type

```@docs
Geography
towkt
towkb
```

## Predicates

Every predicate takes two geographies and returns a `Bool`, or vectors of
geographies and returns a `Vector{Bool}`.

```@docs
contains
within
intersects
disjoint
equals
dwithin
```

## Measures

Lengths are in metres and areas in square metres.

```@docs
area
perimeter
arclength
distance
max_distance
```

## Constructions

```@docs
centroid
convex_hull
boundary
point_on_surface
closest_point
shortest_line
longest_line
```

## Overlays

```@docs
intersection
union
difference
sym_difference
```

## Transformations

```@docs
simplify
buffer
reduce_precision
segmentize
tessellate
tessellate_planar
```

## Linear referencing

```@docs
line_interpolate_point
line_locate_point
```

## S2 cells

```@docs
cellid
covering
```

## Bounding boxes

```@docs
GeoInterface.extent(::Geography)
```

## Indexing and introspection

```@docs
prepare!
memory_used
```

## Errors

```@docs
S2GeographyError
WKTParseError
```

## Raw C bindings

Everything above is built on a thin, complete wrapping of the s2geography C
header. It is not part of the public API and comes with no stability promise,
but it is there if you need something this package does not expose.

```@docs
S2Geography.CAPI
```
