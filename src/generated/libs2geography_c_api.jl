const ArrowSchema = Cvoid

const ArrowArray = Cvoid

function s2geog_last_error()
    unsafe_string(@ccall(libs2geography_c.s2geog_last_error()::Cstring))
end

const S2GeogGeography = Cvoid

const S2GeogShapeIndex = Cvoid

const S2GeogGeographyIndex = Cvoid

const S2GeogWKTReader = Cvoid

const S2GeogWKTWriter = Cvoid

const S2GeogWKBReader = Cvoid

const S2GeogWKBWriter = Cvoid

const S2GeogGeoArrowReader = Cvoid

const S2GeogGeoArrowWriter = Cvoid

const S2GeogCentroidAggregator = Cvoid

const S2GeogConvexHullAggregator = Cvoid

const S2GeogRebuildAggregator = Cvoid

const S2GeogCoverageUnionAggregator = Cvoid

const S2GeogUnionAggregator = Cvoid

const S2GeogArrowUDF = Cvoid

const S2GeogProjection = Cvoid

function s2geog_string_free(str)
    @ccall libs2geography_c.s2geog_string_free(str::Cstring)::Cvoid
end

function s2geog_bytes_free(bytes)
    @ccall libs2geography_c.s2geog_bytes_free(bytes::Ptr{UInt8})::Cvoid
end

function s2geog_cell_ids_free(cell_ids)
    @ccall libs2geography_c.s2geog_cell_ids_free(cell_ids::Ptr{UInt64})::Cvoid
end

function s2geog_int32_free(ptr)
    @ccall libs2geography_c.s2geog_int32_free(ptr::Ptr{Int32})::Cvoid
end

function s2geog_geography_array_free(arr, n)
    @ccall libs2geography_c.s2geog_geography_array_free(
        arr::Ptr{Ptr{S2GeogGeography}},
        n::Int64,
    )::Cvoid
end

function s2geog_geography_destroy(geog)
    @ccall libs2geography_c.s2geog_geography_destroy(geog::Ptr{S2GeogGeography})::Cvoid
end

function s2geog_geography_kind(geog)
    @ccall libs2geography_c.s2geog_geography_kind(geog::Ptr{S2GeogGeography})::Cint
end

function s2geog_geography_dimension(geog)
    @ccall libs2geography_c.s2geog_geography_dimension(geog::Ptr{S2GeogGeography})::Cint
end

function s2geog_geography_num_shapes(geog)
    @ccall libs2geography_c.s2geog_geography_num_shapes(geog::Ptr{S2GeogGeography})::Cint
end

function s2geog_geography_is_empty(geog, out)
    @ccall libs2geography_c.s2geog_geography_is_empty(
        geog::Ptr{S2GeogGeography},
        out::Ptr{Cint},
    )::Cint
end

function s2geog_make_point_lnglat(lng, lat)
    @ccall libs2geography_c.s2geog_make_point_lnglat(
        lng::Cdouble,
        lat::Cdouble,
    )::Ptr{S2GeogGeography}
end

function s2geog_make_point_xyz(x, y, z)
    @ccall libs2geography_c.s2geog_make_point_xyz(
        x::Cdouble,
        y::Cdouble,
        z::Cdouble,
    )::Ptr{S2GeogGeography}
end

function s2geog_make_multipoint_lnglat(lnglat, n)
    @ccall libs2geography_c.s2geog_make_multipoint_lnglat(
        lnglat::Ptr{Cdouble},
        n::Int64,
    )::Ptr{S2GeogGeography}
end

function s2geog_make_multipoint_xyz(xyz, n)
    @ccall libs2geography_c.s2geog_make_multipoint_xyz(
        xyz::Ptr{Cdouble},
        n::Int64,
    )::Ptr{S2GeogGeography}
end

function s2geog_make_polyline_lnglat(lnglat, n)
    @ccall libs2geography_c.s2geog_make_polyline_lnglat(
        lnglat::Ptr{Cdouble},
        n::Int64,
    )::Ptr{S2GeogGeography}
end

function s2geog_make_polyline_xyz(xyz, n)
    @ccall libs2geography_c.s2geog_make_polyline_xyz(
        xyz::Ptr{Cdouble},
        n::Int64,
    )::Ptr{S2GeogGeography}
end

function s2geog_make_polygon_lnglat(lnglat, ring_offsets, n_rings)
    @ccall libs2geography_c.s2geog_make_polygon_lnglat(
        lnglat::Ptr{Cdouble},
        ring_offsets::Ptr{Int64},
        n_rings::Int64,
    )::Ptr{S2GeogGeography}
end

function s2geog_make_polygon_xyz(xyz, ring_offsets, n_rings)
    @ccall libs2geography_c.s2geog_make_polygon_xyz(
        xyz::Ptr{Cdouble},
        ring_offsets::Ptr{Int64},
        n_rings::Int64,
    )::Ptr{S2GeogGeography}
end

function s2geog_make_collection(geogs, n)
    @ccall libs2geography_c.s2geog_make_collection(
        geogs::Ptr{Ptr{S2GeogGeography}},
        n::Int64,
    )::Ptr{S2GeogGeography}
end

function s2geog_wkt_reader_new()
    @ccall libs2geography_c.s2geog_wkt_reader_new()::Ptr{S2GeogWKTReader}
end

function s2geog_wkt_reader_destroy(reader)
    @ccall libs2geography_c.s2geog_wkt_reader_destroy(reader::Ptr{S2GeogWKTReader})::Cvoid
end

function s2geog_wkt_reader_read(reader, wkt, size)
    @ccall libs2geography_c.s2geog_wkt_reader_read(
        reader::Ptr{S2GeogWKTReader},
        wkt::Cstring,
        size::Int64,
    )::Ptr{S2GeogGeography}
end

function s2geog_wkt_writer_new(precision)
    @ccall libs2geography_c.s2geog_wkt_writer_new(precision::Cint)::Ptr{S2GeogWKTWriter}
end

function s2geog_wkt_writer_destroy(writer)
    @ccall libs2geography_c.s2geog_wkt_writer_destroy(writer::Ptr{S2GeogWKTWriter})::Cvoid
end

function s2geog_wkt_writer_write(writer, geog)
    @ccall libs2geography_c.s2geog_wkt_writer_write(
        writer::Ptr{S2GeogWKTWriter},
        geog::Ptr{S2GeogGeography},
    )::Cstring
end

function s2geog_wkb_reader_new()
    @ccall libs2geography_c.s2geog_wkb_reader_new()::Ptr{S2GeogWKBReader}
end

function s2geog_wkb_reader_destroy(reader)
    @ccall libs2geography_c.s2geog_wkb_reader_destroy(reader::Ptr{S2GeogWKBReader})::Cvoid
end

function s2geog_wkb_reader_read(reader, bytes, size)
    @ccall libs2geography_c.s2geog_wkb_reader_read(
        reader::Ptr{S2GeogWKBReader},
        bytes::Ptr{UInt8},
        size::Int64,
    )::Ptr{S2GeogGeography}
end

function s2geog_wkb_writer_new()
    @ccall libs2geography_c.s2geog_wkb_writer_new()::Ptr{S2GeogWKBWriter}
end

function s2geog_wkb_writer_destroy(writer)
    @ccall libs2geography_c.s2geog_wkb_writer_destroy(writer::Ptr{S2GeogWKBWriter})::Cvoid
end

function s2geog_wkb_writer_write(writer, geog, out, out_size)
    @ccall libs2geography_c.s2geog_wkb_writer_write(
        writer::Ptr{S2GeogWKBWriter},
        geog::Ptr{S2GeogGeography},
        out::Ptr{Ptr{UInt8}},
        out_size::Ptr{Int64},
    )::Cint
end

function s2geog_shape_index_new(geog)
    @ccall libs2geography_c.s2geog_shape_index_new(
        geog::Ptr{S2GeogGeography},
    )::Ptr{S2GeogShapeIndex}
end

function s2geog_shape_index_destroy(idx)
    @ccall libs2geography_c.s2geog_shape_index_destroy(idx::Ptr{S2GeogShapeIndex})::Cvoid
end

function s2geog_area(geog, out)
    @ccall libs2geography_c.s2geog_area(geog::Ptr{S2GeogGeography}, out::Ptr{Cdouble})::Cint
end

function s2geog_length(geog, out)
    @ccall libs2geography_c.s2geog_length(
        geog::Ptr{S2GeogGeography},
        out::Ptr{Cdouble},
    )::Cint
end

function s2geog_perimeter(geog, out)
    @ccall libs2geography_c.s2geog_perimeter(
        geog::Ptr{S2GeogGeography},
        out::Ptr{Cdouble},
    )::Cint
end

function s2geog_x(geog, out)
    @ccall libs2geography_c.s2geog_x(geog::Ptr{S2GeogGeography}, out::Ptr{Cdouble})::Cint
end

function s2geog_y(geog, out)
    @ccall libs2geography_c.s2geog_y(geog::Ptr{S2GeogGeography}, out::Ptr{Cdouble})::Cint
end

function s2geog_num_points(geog, out)
    @ccall libs2geography_c.s2geog_num_points(
        geog::Ptr{S2GeogGeography},
        out::Ptr{Cint},
    )::Cint
end

function s2geog_is_collection(geog, out)
    @ccall libs2geography_c.s2geog_is_collection(
        geog::Ptr{S2GeogGeography},
        out::Ptr{Cint},
    )::Cint
end

function s2geog_find_validation_error(geog, buf, buf_size, out)
    @ccall libs2geography_c.s2geog_find_validation_error(
        geog::Ptr{S2GeogGeography},
        buf::Cstring,
        buf_size::Int64,
        out::Ptr{Cint},
    )::Cint
end

function s2geog_intersects(a, b, out)
    @ccall libs2geography_c.s2geog_intersects(
        a::Ptr{S2GeogShapeIndex},
        b::Ptr{S2GeogShapeIndex},
        out::Ptr{Cint},
    )::Cint
end

function s2geog_equals(a, b, out)
    @ccall libs2geography_c.s2geog_equals(
        a::Ptr{S2GeogShapeIndex},
        b::Ptr{S2GeogShapeIndex},
        out::Ptr{Cint},
    )::Cint
end

function s2geog_contains(a, b, out)
    @ccall libs2geography_c.s2geog_contains(
        a::Ptr{S2GeogShapeIndex},
        b::Ptr{S2GeogShapeIndex},
        out::Ptr{Cint},
    )::Cint
end

function s2geog_touches(a, b, out)
    @ccall libs2geography_c.s2geog_touches(
        a::Ptr{S2GeogShapeIndex},
        b::Ptr{S2GeogShapeIndex},
        out::Ptr{Cint},
    )::Cint
end

function s2geog_distance(a, b, out)
    @ccall libs2geography_c.s2geog_distance(
        a::Ptr{S2GeogShapeIndex},
        b::Ptr{S2GeogShapeIndex},
        out::Ptr{Cdouble},
    )::Cint
end

function s2geog_max_distance(a, b, out)
    @ccall libs2geography_c.s2geog_max_distance(
        a::Ptr{S2GeogShapeIndex},
        b::Ptr{S2GeogShapeIndex},
        out::Ptr{Cdouble},
    )::Cint
end

function s2geog_closest_point(a, b)
    @ccall libs2geography_c.s2geog_closest_point(
        a::Ptr{S2GeogShapeIndex},
        b::Ptr{S2GeogShapeIndex},
    )::Ptr{S2GeogGeography}
end

function s2geog_minimum_clearance_line_between(a, b)
    @ccall libs2geography_c.s2geog_minimum_clearance_line_between(
        a::Ptr{S2GeogShapeIndex},
        b::Ptr{S2GeogShapeIndex},
    )::Ptr{S2GeogGeography}
end

function s2geog_centroid(geog)
    @ccall libs2geography_c.s2geog_centroid(
        geog::Ptr{S2GeogGeography},
    )::Ptr{S2GeogGeography}
end

function s2geog_boundary(geog)
    @ccall libs2geography_c.s2geog_boundary(
        geog::Ptr{S2GeogGeography},
    )::Ptr{S2GeogGeography}
end

function s2geog_convex_hull(geog)
    @ccall libs2geography_c.s2geog_convex_hull(
        geog::Ptr{S2GeogGeography},
    )::Ptr{S2GeogGeography}
end

function s2geog_intersection(a, b)
    @ccall libs2geography_c.s2geog_intersection(
        a::Ptr{S2GeogShapeIndex},
        b::Ptr{S2GeogShapeIndex},
    )::Ptr{S2GeogGeography}
end

function s2geog_union(a, b)
    @ccall libs2geography_c.s2geog_union(
        a::Ptr{S2GeogShapeIndex},
        b::Ptr{S2GeogShapeIndex},
    )::Ptr{S2GeogGeography}
end

function s2geog_difference(a, b)
    @ccall libs2geography_c.s2geog_difference(
        a::Ptr{S2GeogShapeIndex},
        b::Ptr{S2GeogShapeIndex},
    )::Ptr{S2GeogGeography}
end

function s2geog_sym_difference(a, b)
    @ccall libs2geography_c.s2geog_sym_difference(
        a::Ptr{S2GeogShapeIndex},
        b::Ptr{S2GeogShapeIndex},
    )::Ptr{S2GeogGeography}
end

function s2geog_unary_union(geog)
    @ccall libs2geography_c.s2geog_unary_union(
        geog::Ptr{S2GeogShapeIndex},
    )::Ptr{S2GeogGeography}
end

function s2geog_rebuild(geog)
    @ccall libs2geography_c.s2geog_rebuild(geog::Ptr{S2GeogGeography})::Ptr{S2GeogGeography}
end

function s2geog_build_point(geog)
    @ccall libs2geography_c.s2geog_build_point(
        geog::Ptr{S2GeogGeography},
    )::Ptr{S2GeogGeography}
end

function s2geog_build_polyline(geog)
    @ccall libs2geography_c.s2geog_build_polyline(
        geog::Ptr{S2GeogGeography},
    )::Ptr{S2GeogGeography}
end

function s2geog_build_polygon(geog)
    @ccall libs2geography_c.s2geog_build_polygon(
        geog::Ptr{S2GeogGeography},
    )::Ptr{S2GeogGeography}
end

function s2geog_covering(geog, max_cells, cell_ids_out, n_out)
    @ccall libs2geography_c.s2geog_covering(
        geog::Ptr{S2GeogGeography},
        max_cells::Cint,
        cell_ids_out::Ptr{Ptr{UInt64}},
        n_out::Ptr{Int64},
    )::Cint
end

function s2geog_interior_covering(geog, max_cells, cell_ids_out, n_out)
    @ccall libs2geography_c.s2geog_interior_covering(
        geog::Ptr{S2GeogGeography},
        max_cells::Cint,
        cell_ids_out::Ptr{Ptr{UInt64}},
        n_out::Ptr{Int64},
    )::Cint
end

function s2geog_project_normalized(geog1, geog2, out)
    @ccall libs2geography_c.s2geog_project_normalized(
        geog1::Ptr{S2GeogGeography},
        geog2::Ptr{S2GeogGeography},
        out::Ptr{Cdouble},
    )::Cint
end

function s2geog_interpolate_normalized(geog, distance_norm)
    @ccall libs2geography_c.s2geog_interpolate_normalized(
        geog::Ptr{S2GeogGeography},
        distance_norm::Cdouble,
    )::Ptr{S2GeogGeography}
end

function s2geog_op_point_to_lnglat(point, lnglat_out)
    @ccall libs2geography_c.s2geog_op_point_to_lnglat(
        point::Ptr{Cdouble},
        lnglat_out::Ptr{Cdouble},
    )::Cvoid
end

function s2geog_op_point_to_point(lnglat, point_out)
    @ccall libs2geography_c.s2geog_op_point_to_point(
        lnglat::Ptr{Cdouble},
        point_out::Ptr{Cdouble},
    )::Cvoid
end

function s2geog_op_cell_from_token(token, out)
    @ccall libs2geography_c.s2geog_op_cell_from_token(
        token::Cstring,
        out::Ptr{UInt64},
    )::Cint
end

function s2geog_op_cell_from_debug_string(debug_str, out)
    @ccall libs2geography_c.s2geog_op_cell_from_debug_string(
        debug_str::Cstring,
        out::Ptr{UInt64},
    )::Cint
end

function s2geog_op_cell_from_point(point, out)
    @ccall libs2geography_c.s2geog_op_cell_from_point(
        point::Ptr{Cdouble},
        out::Ptr{UInt64},
    )::Cint
end

function s2geog_op_cell_to_point(cell_id, point_out)
    @ccall libs2geography_c.s2geog_op_cell_to_point(
        cell_id::UInt64,
        point_out::Ptr{Cdouble},
    )::Cint
end

function s2geog_op_cell_to_token(cell_id, buf, buf_size)
    @ccall libs2geography_c.s2geog_op_cell_to_token(
        cell_id::UInt64,
        buf::Cstring,
        buf_size::Int64,
    )::Cint
end

function s2geog_op_cell_to_debug_string(cell_id, buf, buf_size)
    @ccall libs2geography_c.s2geog_op_cell_to_debug_string(
        cell_id::UInt64,
        buf::Cstring,
        buf_size::Int64,
    )::Cint
end

function s2geog_op_cell_is_valid(cell_id, out)
    @ccall libs2geography_c.s2geog_op_cell_is_valid(cell_id::UInt64, out::Ptr{Cint})::Cint
end

function s2geog_op_cell_center(cell_id, point_out)
    @ccall libs2geography_c.s2geog_op_cell_center(
        cell_id::UInt64,
        point_out::Ptr{Cdouble},
    )::Cint
end

function s2geog_op_cell_vertex(cell_id, vertex_id, point_out)
    @ccall libs2geography_c.s2geog_op_cell_vertex(
        cell_id::UInt64,
        vertex_id::Int8,
        point_out::Ptr{Cdouble},
    )::Cint
end

function s2geog_op_cell_level(cell_id, out)
    @ccall libs2geography_c.s2geog_op_cell_level(cell_id::UInt64, out::Ptr{Int8})::Cint
end

function s2geog_op_cell_area(cell_id, out)
    @ccall libs2geography_c.s2geog_op_cell_area(cell_id::UInt64, out::Ptr{Cdouble})::Cint
end

function s2geog_op_cell_area_approx(cell_id, out)
    @ccall libs2geography_c.s2geog_op_cell_area_approx(
        cell_id::UInt64,
        out::Ptr{Cdouble},
    )::Cint
end

function s2geog_op_cell_parent(cell_id, level, out)
    @ccall libs2geography_c.s2geog_op_cell_parent(
        cell_id::UInt64,
        level::Int8,
        out::Ptr{UInt64},
    )::Cint
end

function s2geog_op_cell_child(cell_id, k, out)
    @ccall libs2geography_c.s2geog_op_cell_child(
        cell_id::UInt64,
        k::Int8,
        out::Ptr{UInt64},
    )::Cint
end

function s2geog_op_cell_edge_neighbor(cell_id, k, out)
    @ccall libs2geography_c.s2geog_op_cell_edge_neighbor(
        cell_id::UInt64,
        k::Int8,
        out::Ptr{UInt64},
    )::Cint
end

function s2geog_op_cell_contains(cell_id, cell_id_test, out)
    @ccall libs2geography_c.s2geog_op_cell_contains(
        cell_id::UInt64,
        cell_id_test::UInt64,
        out::Ptr{Cint},
    )::Cint
end

function s2geog_op_cell_may_intersect(cell_id, cell_id_test, out)
    @ccall libs2geography_c.s2geog_op_cell_may_intersect(
        cell_id::UInt64,
        cell_id_test::UInt64,
        out::Ptr{Cint},
    )::Cint
end

function s2geog_op_cell_distance(cell_id, cell_id_test, out)
    @ccall libs2geography_c.s2geog_op_cell_distance(
        cell_id::UInt64,
        cell_id_test::UInt64,
        out::Ptr{Cdouble},
    )::Cint
end

function s2geog_op_cell_max_distance(cell_id, cell_id_test, out)
    @ccall libs2geography_c.s2geog_op_cell_max_distance(
        cell_id::UInt64,
        cell_id_test::UInt64,
        out::Ptr{Cdouble},
    )::Cint
end

function s2geog_op_cell_common_ancestor_level(cell_id, cell_id_test, out)
    @ccall libs2geography_c.s2geog_op_cell_common_ancestor_level(
        cell_id::UInt64,
        cell_id_test::UInt64,
        out::Ptr{Int8},
    )::Cint
end

function s2geog_centroid_aggregator_new()
    @ccall libs2geography_c.s2geog_centroid_aggregator_new()::Ptr{S2GeogCentroidAggregator}
end

function s2geog_centroid_aggregator_destroy(agg)
    @ccall libs2geography_c.s2geog_centroid_aggregator_destroy(
        agg::Ptr{S2GeogCentroidAggregator},
    )::Cvoid
end

function s2geog_centroid_aggregator_add(agg, geog)
    @ccall libs2geography_c.s2geog_centroid_aggregator_add(
        agg::Ptr{S2GeogCentroidAggregator},
        geog::Ptr{S2GeogGeography},
    )::Cint
end

function s2geog_centroid_aggregator_finalize(agg)
    @ccall libs2geography_c.s2geog_centroid_aggregator_finalize(
        agg::Ptr{S2GeogCentroidAggregator},
    )::Ptr{S2GeogGeography}
end

function s2geog_convex_hull_aggregator_new()
    @ccall libs2geography_c.s2geog_convex_hull_aggregator_new()::Ptr{
        S2GeogConvexHullAggregator,
    }
end

function s2geog_convex_hull_aggregator_destroy(agg)
    @ccall libs2geography_c.s2geog_convex_hull_aggregator_destroy(
        agg::Ptr{S2GeogConvexHullAggregator},
    )::Cvoid
end

function s2geog_convex_hull_aggregator_add(agg, geog)
    @ccall libs2geography_c.s2geog_convex_hull_aggregator_add(
        agg::Ptr{S2GeogConvexHullAggregator},
        geog::Ptr{S2GeogGeography},
    )::Cint
end

function s2geog_convex_hull_aggregator_finalize(agg)
    @ccall libs2geography_c.s2geog_convex_hull_aggregator_finalize(
        agg::Ptr{S2GeogConvexHullAggregator},
    )::Ptr{S2GeogGeography}
end

function s2geog_rebuild_aggregator_new()
    @ccall libs2geography_c.s2geog_rebuild_aggregator_new()::Ptr{S2GeogRebuildAggregator}
end

function s2geog_rebuild_aggregator_destroy(agg)
    @ccall libs2geography_c.s2geog_rebuild_aggregator_destroy(
        agg::Ptr{S2GeogRebuildAggregator},
    )::Cvoid
end

function s2geog_rebuild_aggregator_add(agg, geog)
    @ccall libs2geography_c.s2geog_rebuild_aggregator_add(
        agg::Ptr{S2GeogRebuildAggregator},
        geog::Ptr{S2GeogGeography},
    )::Cint
end

function s2geog_rebuild_aggregator_finalize(agg)
    @ccall libs2geography_c.s2geog_rebuild_aggregator_finalize(
        agg::Ptr{S2GeogRebuildAggregator},
    )::Ptr{S2GeogGeography}
end

function s2geog_coverage_union_aggregator_new()
    @ccall libs2geography_c.s2geog_coverage_union_aggregator_new()::Ptr{
        S2GeogCoverageUnionAggregator,
    }
end

function s2geog_coverage_union_aggregator_destroy(agg)
    @ccall libs2geography_c.s2geog_coverage_union_aggregator_destroy(
        agg::Ptr{S2GeogCoverageUnionAggregator},
    )::Cvoid
end

function s2geog_coverage_union_aggregator_add(agg, geog)
    @ccall libs2geography_c.s2geog_coverage_union_aggregator_add(
        agg::Ptr{S2GeogCoverageUnionAggregator},
        geog::Ptr{S2GeogGeography},
    )::Cint
end

function s2geog_coverage_union_aggregator_finalize(agg)
    @ccall libs2geography_c.s2geog_coverage_union_aggregator_finalize(
        agg::Ptr{S2GeogCoverageUnionAggregator},
    )::Ptr{S2GeogGeography}
end

function s2geog_union_aggregator_new()
    @ccall libs2geography_c.s2geog_union_aggregator_new()::Ptr{S2GeogUnionAggregator}
end

function s2geog_union_aggregator_destroy(agg)
    @ccall libs2geography_c.s2geog_union_aggregator_destroy(
        agg::Ptr{S2GeogUnionAggregator},
    )::Cvoid
end

function s2geog_union_aggregator_add(agg, geog)
    @ccall libs2geography_c.s2geog_union_aggregator_add(
        agg::Ptr{S2GeogUnionAggregator},
        geog::Ptr{S2GeogGeography},
    )::Cint
end

function s2geog_union_aggregator_finalize(agg)
    @ccall libs2geography_c.s2geog_union_aggregator_finalize(
        agg::Ptr{S2GeogUnionAggregator},
    )::Ptr{S2GeogGeography}
end

function s2geog_geography_index_new()
    @ccall libs2geography_c.s2geog_geography_index_new()::Ptr{S2GeogGeographyIndex}
end

function s2geog_geography_index_destroy(index)
    @ccall libs2geography_c.s2geog_geography_index_destroy(
        index::Ptr{S2GeogGeographyIndex},
    )::Cvoid
end

function s2geog_geography_index_add(index, geog, value)
    @ccall libs2geography_c.s2geog_geography_index_add(
        index::Ptr{S2GeogGeographyIndex},
        geog::Ptr{S2GeogGeography},
        value::Cint,
    )::Cint
end

function s2geog_geography_index_query(index, geog, results_out, n_out)
    @ccall libs2geography_c.s2geog_geography_index_query(
        index::Ptr{S2GeogGeographyIndex},
        geog::Ptr{S2GeogGeography},
        results_out::Ptr{Ptr{Int32}},
        n_out::Ptr{Int64},
    )::Cint
end

function s2geog_arrow_udf_destroy(udf)
    @ccall libs2geography_c.s2geog_arrow_udf_destroy(udf::Ptr{S2GeogArrowUDF})::Cvoid
end

function s2geog_arrow_udf_init(udf, arg_schema, options, out)
    @ccall libs2geography_c.s2geog_arrow_udf_init(
        udf::Ptr{S2GeogArrowUDF},
        arg_schema::Ptr{ArrowSchema},
        options::Cstring,
        out::Ptr{ArrowSchema},
    )::Cint
end

function s2geog_arrow_udf_execute(udf, args, n_args, out)
    @ccall libs2geography_c.s2geog_arrow_udf_execute(
        udf::Ptr{S2GeogArrowUDF},
        args::Ptr{Ptr{ArrowArray}},
        n_args::Int64,
        out::Ptr{ArrowArray},
    )::Cint
end

function s2geog_arrow_udf_get_last_error(udf)
    unsafe_string(
        @ccall(
            libs2geography_c.s2geog_arrow_udf_get_last_error(
                udf::Ptr{S2GeogArrowUDF},
            )::Cstring
        )
    )
end

function s2geog_arrow_udf_distance()
    @ccall libs2geography_c.s2geog_arrow_udf_distance()::Ptr{S2GeogArrowUDF}
end

function s2geog_arrow_udf_max_distance()
    @ccall libs2geography_c.s2geog_arrow_udf_max_distance()::Ptr{S2GeogArrowUDF}
end

function s2geog_arrow_udf_shortest_line()
    @ccall libs2geography_c.s2geog_arrow_udf_shortest_line()::Ptr{S2GeogArrowUDF}
end

function s2geog_arrow_udf_closest_point()
    @ccall libs2geography_c.s2geog_arrow_udf_closest_point()::Ptr{S2GeogArrowUDF}
end

function s2geog_arrow_udf_intersects()
    @ccall libs2geography_c.s2geog_arrow_udf_intersects()::Ptr{S2GeogArrowUDF}
end

function s2geog_arrow_udf_contains()
    @ccall libs2geography_c.s2geog_arrow_udf_contains()::Ptr{S2GeogArrowUDF}
end

function s2geog_arrow_udf_equals()
    @ccall libs2geography_c.s2geog_arrow_udf_equals()::Ptr{S2GeogArrowUDF}
end

function s2geog_arrow_udf_length()
    @ccall libs2geography_c.s2geog_arrow_udf_length()::Ptr{S2GeogArrowUDF}
end

function s2geog_arrow_udf_area()
    @ccall libs2geography_c.s2geog_arrow_udf_area()::Ptr{S2GeogArrowUDF}
end

function s2geog_arrow_udf_perimeter()
    @ccall libs2geography_c.s2geog_arrow_udf_perimeter()::Ptr{S2GeogArrowUDF}
end

function s2geog_arrow_udf_centroid()
    @ccall libs2geography_c.s2geog_arrow_udf_centroid()::Ptr{S2GeogArrowUDF}
end

function s2geog_arrow_udf_convex_hull()
    @ccall libs2geography_c.s2geog_arrow_udf_convex_hull()::Ptr{S2GeogArrowUDF}
end

function s2geog_arrow_udf_point_on_surface()
    @ccall libs2geography_c.s2geog_arrow_udf_point_on_surface()::Ptr{S2GeogArrowUDF}
end

function s2geog_arrow_udf_difference()
    @ccall libs2geography_c.s2geog_arrow_udf_difference()::Ptr{S2GeogArrowUDF}
end

function s2geog_arrow_udf_sym_difference()
    @ccall libs2geography_c.s2geog_arrow_udf_sym_difference()::Ptr{S2GeogArrowUDF}
end

function s2geog_arrow_udf_intersection()
    @ccall libs2geography_c.s2geog_arrow_udf_intersection()::Ptr{S2GeogArrowUDF}
end

function s2geog_arrow_udf_udf_union()
    @ccall libs2geography_c.s2geog_arrow_udf_udf_union()::Ptr{S2GeogArrowUDF}
end

function s2geog_arrow_udf_line_interpolate_point()
    @ccall libs2geography_c.s2geog_arrow_udf_line_interpolate_point()::Ptr{S2GeogArrowUDF}
end

function s2geog_arrow_udf_line_locate_point()
    @ccall libs2geography_c.s2geog_arrow_udf_line_locate_point()::Ptr{S2GeogArrowUDF}
end

function s2geog_geoarrow_reader_new()
    @ccall libs2geography_c.s2geog_geoarrow_reader_new()::Ptr{S2GeogGeoArrowReader}
end

function s2geog_geoarrow_reader_destroy(reader)
    @ccall libs2geography_c.s2geog_geoarrow_reader_destroy(
        reader::Ptr{S2GeogGeoArrowReader},
    )::Cvoid
end

function s2geog_geoarrow_reader_init(reader, schema)
    @ccall libs2geography_c.s2geog_geoarrow_reader_init(
        reader::Ptr{S2GeogGeoArrowReader},
        schema::Ptr{ArrowSchema},
    )::Cint
end

function s2geog_geoarrow_reader_read(reader, array, offset, length, out, n_out)
    @ccall libs2geography_c.s2geog_geoarrow_reader_read(
        reader::Ptr{S2GeogGeoArrowReader},
        array::Ptr{ArrowArray},
        offset::Int64,
        length::Int64,
        out::Ptr{Ptr{Ptr{S2GeogGeography}}},
        n_out::Ptr{Int64},
    )::Cint
end

function s2geog_geoarrow_writer_new()
    @ccall libs2geography_c.s2geog_geoarrow_writer_new()::Ptr{S2GeogGeoArrowWriter}
end

function s2geog_geoarrow_writer_destroy(writer)
    @ccall libs2geography_c.s2geog_geoarrow_writer_destroy(
        writer::Ptr{S2GeogGeoArrowWriter},
    )::Cvoid
end

function s2geog_geoarrow_writer_init(writer, schema)
    @ccall libs2geography_c.s2geog_geoarrow_writer_init(
        writer::Ptr{S2GeogGeoArrowWriter},
        schema::Ptr{ArrowSchema},
    )::Cint
end

function s2geog_geoarrow_writer_write_geography(writer, geog)
    @ccall libs2geography_c.s2geog_geoarrow_writer_write_geography(
        writer::Ptr{S2GeogGeoArrowWriter},
        geog::Ptr{S2GeogGeography},
    )::Cint
end

function s2geog_geoarrow_writer_write_null(writer)
    @ccall libs2geography_c.s2geog_geoarrow_writer_write_null(
        writer::Ptr{S2GeogGeoArrowWriter},
    )::Cint
end

function s2geog_geoarrow_writer_finish(writer, out)
    @ccall libs2geography_c.s2geog_geoarrow_writer_finish(
        writer::Ptr{S2GeogGeoArrowWriter},
        out::Ptr{ArrowArray},
    )::Cint
end

function s2geog_geoarrow_version()
    unsafe_string(@ccall(libs2geography_c.s2geog_geoarrow_version()::Cstring))
end

function s2geog_projection_lnglat()
    @ccall libs2geography_c.s2geog_projection_lnglat()::Ptr{S2GeogProjection}
end

function s2geog_projection_pseudo_mercator()
    @ccall libs2geography_c.s2geog_projection_pseudo_mercator()::Ptr{S2GeogProjection}
end

function s2geog_projection_destroy(proj)
    @ccall libs2geography_c.s2geog_projection_destroy(proj::Ptr{S2GeogProjection})::Cvoid
end
