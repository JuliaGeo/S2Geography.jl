# `ST_Buffer` has no effect on Windows

`buffer` returns wrong results on Windows and correct results on Linux and macOS,
using identical package and JLL versions. Every other kernel tested behaves
identically across platforms.

## Symptom

On Windows, the buffer distance has no observable effect:

- **Polygon input** — the input geometry is returned unchanged, at every
  distance tested (`-1e9` through `+1e5`). No error is raised.
- **Point / linestring input** — an empty polygon is returned, at every distance.

## Environment

| | |
|---|---|
| Failing platform | `x86_64-w64-mingw32` (`windows-latest`, GitHub Actions) |
| Passing platforms | `x86_64-linux-gnu`, `arm64-apple-darwin24` |
| Julia | 1.11.9 and 1.12.6 (both fail on Windows) |
| `S2Geography_jll` | v0.4.0+0 |
| `S2Geometry_jll` | v0.14.0+0 |
| `abseil_cpp_jll` | 20250814.1 |

Note: the library's self-reported `S2_VERSION` macro is `0.12.0` on all
platforms. Upstream s2geometry declares `project(s2-geometry VERSION 0.12.0)` at
tags v0.12.0, v0.13.1 and v0.14.0 alike, so that string does not identify the
release in use. The resolved package is `S2Geometry_jll` **v0.14.0**.

## Observed values

`buffer(g, 10000)`, reported as `nrings` / `area` in m²:

| input | Windows | Linux & macOS |
|---|---|---|
| `POINT (0 0)` | 0 rings, 0.0 | 1 ring, 3.12144e8 |
| `MULTIPOINT (0 0, 1 1)` | 0 rings, 0.0 | 2 polys, 6.24289e8 |
| `LINESTRING (0 0, 1 0)` | 0 rings, 0.0 | 1 ring, 2.5361e9 |
| `MULTILINESTRING ((0 0, 1 0), (2 2, 3 2))` | 0 rings, 0.0 | 2 polys, 5.07085e9 |
| `POLYGON ((0 0, 1 0, 1 1, 0 1, 0 0))` | 1 ring, **1.2364e10** | 1 ring, 1.71239e10 |
| `MULTIPOLYGON (((0 0, 1 0, 1 1, 0 0)))` | 1 ring, **6.18249e9** | 1 ring, 1.02912e10 |

The two bold Windows values equal the *input* areas exactly.

`buffer(POLYGON ((0 0, 1 0, 1 1, 0 1, 0 0)), d)` across distances — input area is
`1.2364e10`:

| `d` | Windows | Linux |
|---|---|---|
| `-1e9` | 1.2364e10 | 0.0 (empty) |
| `-1e6` | 1.2364e10 | 0.0 (empty) |
| `-1e5` | 1.2364e10 | 0.0 (empty) |
| `-1.0` | 1.2364e10 | 1.23636e10 |
| `0.0` | 1.2364e10 | 1.2364e10 |
| `+1e5` | 1.2364e10 | 8.8052e10 |
| `1e4`, `"quad_segs=64"` | 1.2364e10 | 1.71259e10 |

## Behaviour that is identical on all platforms

These were measured in the same runs and are included to bound the problem.

The `int32` and `string` arguments to the same `st_buffer` kernel reach it and
are parsed — all three raise the correct upstream error on Windows, Linux and
macOS alike:

```
buffer(poly, 1e4, -1)             -> quadrant_segments must be >0 in ST_Buffer()
buffer(poly, 1e4, "bogus=1")      -> Invalid buffer parameter: bogus (accept: 'endcap', ...)
buffer(poly, 1e4, "quad_segs=")   -> Invalid quadrant_segments value: ''. Expected a valid number
```

Other kernels taking the same `(geography, float64)` argument pair return
correct, distance-dependent results on Windows:

```
simplify(LINESTRING (0 0, 0.5 0.0001, 1 0), 1.0)   -> 3 vertices
simplify(LINESTRING (0 0, 0.5 0.0001, 1 0), 20.0)  -> 2 vertices
segmentize(LINESTRING (0 0, 10 0), 1e5)            -> 13 vertices
distance(POINT (0 0), POINT (1 0))                 -> 111195.10117748393
area(POLYGON ((0 0, 1 0, 1 1, 0 1, 0 0)))          -> 1.2364036567076418e10
```

`centroid`, `convex_hull`, `intersection` and `tessellate` also return correct
results on Windows.

## Reproducer

From Julia on Windows:

```julia
using Pkg; Pkg.add("S2Geography")
using S2Geography
import GeoInterface as GI

pg = Geography("POLYGON ((0 0, 1 0, 1 1, 0 1, 0 0))")
area(pg)                      # 1.2364036567076418e10
area(buffer(pg, 100_000.0))   # Windows: 1.2364e10 (unchanged); Linux: 8.8052e10
area(buffer(pg, -1e9))        # Windows: 1.2364e10 (unchanged); Linux: 0.0

GI.ngeom(buffer(Geography("POINT (0 0)"), 10_000.0))   # Windows: 0; Linux: 1
```

Full diagnostic script: see the history of the (deleted) `diagnose-windows-buffer`
branch, or reconstruct from the tables above.

## Relevant upstream code

Kernel registration — `include/s2geography/build.h`:

```cpp
void BufferKernel(struct SedonaCScalarKernel* out);           // (geography, double)
void BufferQuadSegsKernel(struct SedonaCScalarKernel* out);   // (geography, double, int)
void BufferParamsKernel(struct SedonaCScalarKernel* out);     // (geography, double, string)
```

Implementation — `src/s2geography/build.cc`, `BufferParamsExec::Exec` (~line 1611).
All three overloads funnel through it. Abridged:

```cpp
void Exec(arg0_t::c_type value, arg1_t::c_type distance,
          arg2_t::c_type params, out_t* out) {
  if (value.is_empty() || (value.max_dimension() < 2 && distance <= 0)) {
    out->AppendEmpty(GEOARROW_GEOMETRY_TYPE_POLYGON);
    return;
  }

  if (distance != last_distance_ || last_params_ != params) {
    BufferParams parsed = BufferParams::Parse(params);        // <- errors above fire here
    S2BufferOperation::Options options;
    auto buffer_angle = S1Angle::Radians(distance / S2Earth::RadiusMeters());
    options.set_buffer_radius(buffer_angle);
    options.set_circle_segments(parsed.quadrant_segments * 4.0);
    ...
    options_ = options;
    last_distance_ = distance;
    last_params_ = params;
  }

  output_.Clear();
  S2BufferOperation op;
  op.Init(std::make_unique<GeoArrowPolygonLayer>(&output_), options_);
  value.points()->geom().VisitVertices([&](const S2Point& v) { op.AddPoint(v); return true; });
  op.AddShape(*value.lines());
  op.AddShape(*value.polygons());

  S2Error error;
  if (!op.Build(&error)) { throw Exception(...); }             // does not fire
  output_.WriteTo(out, GEOARROW_GEOMETRY_TYPE_POLYGON);
}

double last_distance_{-std::numeric_limits<double>::infinity()};
std::string last_params_;
S2BufferOperation::Options options_;
```

## Suggested next steps on a Windows machine

1. Reproduce in C++ directly against `S2BufferOperation`, with no s2geography and
   no Julia in the picture, to establish which layer the behaviour originates in.
2. If C++ `S2BufferOperation` is correct there, instrument `BufferParamsExec::Exec`
   to print `distance`, `options_.buffer_radius().radians()` and
   `parsed.quadrant_segments` at the point of use.
3. Check whether the s2geometry upstream test suite for `S2BufferOperation` passes
   in a MinGW build.

## Impact on S2Geography.jl

`buffer` is the only affected entry point. For polygon inputs it fails silently,
returning the un-buffered input rather than raising, so callers cannot detect it.
The package's Windows CI currently fails on the `buffer` tests in
`test/runtests.jl` (`@testset "Transformations"` and `@testset "Batch matches scalar"`).
