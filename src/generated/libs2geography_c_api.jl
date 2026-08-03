const S2GeogErrorCode = Cint

const S2GeogError = Cvoid

function S2GeogErrorCreate(err)
    @ccall libs2geography_c.S2GeogErrorCreate(err::Ptr{Ptr{S2GeogError}})::S2GeogErrorCode
end

function S2GeogErrorGetMessage(err)
    unsafe_string(
        @ccall(libs2geography_c.S2GeogErrorGetMessage(err::Ptr{S2GeogError})::Cstring)
    )
end

function S2GeogErrorDestroy(err)
    @ccall libs2geography_c.S2GeogErrorDestroy(err::Ptr{S2GeogError})::Cvoid
end

struct S2GeogVertex
    v::NTuple{4,Cdouble}
end

function S2GeogLngLatToCellId(vertex)
    @ccall libs2geography_c.S2GeogLngLatToCellId(vertex::Ptr{S2GeogVertex})::UInt64
end

const S2Geog = Cvoid

function S2GeogCreate(geog)
    @ccall libs2geography_c.S2GeogCreate(geog::Ptr{Ptr{S2Geog}})::S2GeogErrorCode
end

function S2GeogForcePrepare(geog, err)
    @ccall libs2geography_c.S2GeogForcePrepare(
        geog::Ptr{S2Geog},
        err::Ptr{S2GeogError},
    )::S2GeogErrorCode
end

function S2GeogMemUsed(geog)
    @ccall libs2geography_c.S2GeogMemUsed(geog::Ptr{S2Geog})::Csize_t
end

function S2GeogDestroy(geog)
    @ccall libs2geography_c.S2GeogDestroy(geog::Ptr{S2Geog})::Cvoid
end

const S2GeogFactory = Cvoid

function S2GeogFactoryCreate(geog_factory)
    @ccall libs2geography_c.S2GeogFactoryCreate(
        geog_factory::Ptr{Ptr{S2GeogFactory}},
    )::S2GeogErrorCode
end

function S2GeogFactoryInitFromWkbNonOwning(geog_factory, buf, buf_size, out, err)
    @ccall libs2geography_c.S2GeogFactoryInitFromWkbNonOwning(
        geog_factory::Ptr{S2GeogFactory},
        buf::Ptr{UInt8},
        buf_size::Csize_t,
        out::Ptr{S2Geog},
        err::Ptr{S2GeogError},
    )::S2GeogErrorCode
end

function S2GeogFactoryInitFromWkt(geog_factory, buf, buf_size, out, err)
    @ccall libs2geography_c.S2GeogFactoryInitFromWkt(
        geog_factory::Ptr{S2GeogFactory},
        buf::Cstring,
        buf_size::Csize_t,
        out::Ptr{S2Geog},
        err::Ptr{S2GeogError},
    )::S2GeogErrorCode
end

function S2GeogFactoryDestroy(geog_factory)
    @ccall libs2geography_c.S2GeogFactoryDestroy(geog_factory::Ptr{S2GeogFactory})::Cvoid
end

const S2GeogRectBounder = Cvoid

function S2GeogRectBounderCreate(rect_bounder)
    @ccall libs2geography_c.S2GeogRectBounderCreate(
        rect_bounder::Ptr{Ptr{S2GeogRectBounder}},
    )::S2GeogErrorCode
end

function S2GeogRectBounderClear(rect_bounder)
    @ccall libs2geography_c.S2GeogRectBounderClear(
        rect_bounder::Ptr{S2GeogRectBounder},
    )::Cvoid
end

function S2GeogRectBounderBound(rect_bounder, geog, err)
    @ccall libs2geography_c.S2GeogRectBounderBound(
        rect_bounder::Ptr{S2GeogRectBounder},
        geog::Ptr{S2Geog},
        err::Ptr{S2GeogError},
    )::S2GeogErrorCode
end

function S2GeogRectBounderExpandByDistance(rect_bounder, distance_meters)
    @ccall libs2geography_c.S2GeogRectBounderExpandByDistance(
        rect_bounder::Ptr{S2GeogRectBounder},
        distance_meters::Cdouble,
    )::Cvoid
end

function S2GeogRectBounderExpandByDistanceWithRadius(rect_bounder, distance_meters, radius)
    @ccall libs2geography_c.S2GeogRectBounderExpandByDistanceWithRadius(
        rect_bounder::Ptr{S2GeogRectBounder},
        distance_meters::Cdouble,
        radius::Cdouble,
    )::Cvoid
end

function S2GeogRectBounderUpdateRect(rect_bounder, x_lo, y_lo, x_hi, y_hi)
    @ccall libs2geography_c.S2GeogRectBounderUpdateRect(
        rect_bounder::Ptr{S2GeogRectBounder},
        x_lo::Cdouble,
        y_lo::Cdouble,
        x_hi::Cdouble,
        y_hi::Cdouble,
    )::Cvoid
end

function S2GeogRectBounderIsEmpty(rect_bounder)
    @ccall libs2geography_c.S2GeogRectBounderIsEmpty(
        rect_bounder::Ptr{S2GeogRectBounder},
    )::UInt8
end

function S2GeogRectBounderFinish(rect_bounder, lo, hi, err)
    @ccall libs2geography_c.S2GeogRectBounderFinish(
        rect_bounder::Ptr{S2GeogRectBounder},
        lo::Ptr{S2GeogVertex},
        hi::Ptr{S2GeogVertex},
        err::Ptr{S2GeogError},
    )::S2GeogErrorCode
end

function S2GeogRectBounderDestroy(rect_bounder)
    @ccall libs2geography_c.S2GeogRectBounderDestroy(
        rect_bounder::Ptr{S2GeogRectBounder},
    )::Cvoid
end

function S2GeogNumKernels()
    @ccall libs2geography_c.S2GeogNumKernels()::Csize_t
end

function S2GeogInitKernels(kernels_array, kernels_array_size_bytes, format)
    @ccall libs2geography_c.S2GeogInitKernels(
        kernels_array::Ptr{Cvoid},
        kernels_array_size_bytes::Csize_t,
        format::Cint,
    )::S2GeogErrorCode
end

const S2GeogOp = Cvoid

function S2GeogOpCreate(op, op_id)
    @ccall libs2geography_c.S2GeogOpCreate(
        op::Ptr{Ptr{S2GeogOp}},
        op_id::Cint,
    )::S2GeogErrorCode
end

function S2GeogOpName(op)
    unsafe_string(@ccall(libs2geography_c.S2GeogOpName(op::Ptr{S2GeogOp})::Cstring))
end

function S2GeogOpOutputType(op)
    @ccall libs2geography_c.S2GeogOpOutputType(op::Ptr{S2GeogOp})::Cint
end

function S2GeogOpEvalGeogGeog(op, arg0, arg1, err)
    @ccall libs2geography_c.S2GeogOpEvalGeogGeog(
        op::Ptr{S2GeogOp},
        arg0::Ptr{S2Geog},
        arg1::Ptr{S2Geog},
        err::Ptr{S2GeogError},
    )::S2GeogErrorCode
end

function S2GeogOpEvalGeogGeogDouble(op, arg0, arg1, arg2, err)
    @ccall libs2geography_c.S2GeogOpEvalGeogGeogDouble(
        op::Ptr{S2GeogOp},
        arg0::Ptr{S2Geog},
        arg1::Ptr{S2Geog},
        arg2::Cdouble,
        err::Ptr{S2GeogError},
    )::S2GeogErrorCode
end

function S2GeogOpGetInt(op)
    @ccall libs2geography_c.S2GeogOpGetInt(op::Ptr{S2GeogOp})::Int64
end

function S2GeogOpDestroy(op)
    @ccall libs2geography_c.S2GeogOpDestroy(op::Ptr{S2GeogOp})::Cvoid
end

function S2GeogNanoarrowVersion()
    unsafe_string(@ccall(libs2geography_c.S2GeogNanoarrowVersion()::Cstring))
end

function S2GeogGeoArrowVersion()
    unsafe_string(@ccall(libs2geography_c.S2GeogGeoArrowVersion()::Cstring))
end

function S2GeogOpenSSLVersion()
    unsafe_string(@ccall(libs2geography_c.S2GeogOpenSSLVersion()::Cstring))
end

function S2GeogS2GeometryVersion()
    unsafe_string(@ccall(libs2geography_c.S2GeogS2GeometryVersion()::Cstring))
end

function S2GeogAbseilVersion()
    unsafe_string(@ccall(libs2geography_c.S2GeogAbseilVersion()::Cstring))
end

const S2GEOGRAPHY_OK = 0

const S2GEOGRAPHY_KERNEL_FORMAT_SEDONA_UDF = 1

const S2GEOGRAPHY_OP_INTERSECTS = 1

const S2GEOGRAPHY_OP_CONTAINS = 2

const S2GEOGRAPHY_OP_WITHIN = 3

const S2GEOGRAPHY_OP_EQUALS = 4

const S2GEOGRAPHY_OP_DISTANCE_WITHIN = 5

const S2GEOGRAPHY_OP_DISJOINT = 6

const S2GEOGRAPHY_OUTPUT_TYPE_BOOL = 1
