check_geometry_index :: (index : int) -> bool #must {
    if index < 0 || index >= app.entities.count {
        console_add_log("[error] invalid/out of range geometry index");
        return false;
    }
    return true;
}

quit :: () {
    app.closing_application = true;
} @RegisterCommand

history :: () {
    for app.console.history {
        console_add_log("# % %", it_index, it);
    }
} @RegisterCommand

clear :: () {
    console_clear_log();
} @RegisterCommand

help :: () {
    console_add_log("# Available commands:");
    for app.console.commands {
        console_add_log("#  %", it.name); // @Incomplete write usage here too, or write the procedure parameters
    }
} @RegisterCommand

// @Incomplete Separate into boiler plate and an actual command (with @RegisterCommand note)
clockwise_boundaries :: (geometry_index : int) {
    // @Refactor move this to boiler plate e.g., by adding special syntax for ints which are geometry indices
    if !check_geometry_index(geometry_index) {
        return;
    }

#if ENABLE_BOOST_POLYGON {

    it := app.entities[geometry_index];

    if it.type != .POLYGON_SOUP {
        console_add_log("[error] clockwise_boundaries not supported for entity type %", it.type);
        issued_error = true;
        return;
    }

    polygon_soup_entity := cast(*Polygon_Soup_Entity) it;

    #import "BoostPolygon";
    boundary := BoostPolygon.clockwise_boundaries(*polygon_soup_entity.shape);
    if boundary.polylines.count == 0 {
        console_add_log("# result is empty");
        return;
    }

    mesh, ok := to_Mesh(boundary);
    assert(ok);

    entity := New(Polyline_Soup2_Entity);
    entity.mesh = mesh;
    entity.shape = boundary;

    array_add(*app.entities, entity);
} else {
    log("Feature unavailable: compile with 'boost_on'\n");
    return;
}
} @RegisterCommand

offset :: (geometry_index : int, offset_radius : float) {
#if ENABLE_BOOST_POLYGON {

    // @Refactor move this to boiler plate e.g., by adding special syntax for ints which are geometry indices
    if !check_geometry_index(geometry_index) {
        return;
    }

    // @CompilerBug I don't see the entities global in gdb here?? This is probably fixed (according to the Jai changelog, need to verify)

    it := app.entities[geometry_index];

    if it.type != .POLYLINE_SOUP2 {
        yet := ifx it.type == .POLYGON_SOUP then " yet " else " ";
        console_add_log("[error] offset not%supported for entity type %", yet, it.type);
        return; // @Incomplete support polygons
    }

    console_add_log("# offsetting % by % and returning boundaries", geometry_index, offset_radius);

    polyline_soup2_entity := cast(*Polyline_Soup2_Entity) it;

    #import "BoostPolygon";
    offset_polygon := BoostPolygon.offset(*polyline_soup2_entity.shape, offset_radius);
    if offset_polygon.polygons.count == 0 {
        console_add_log("# result is empty"); // offsetting a line with a negative value gives nothing
        return;
    }

    mesh, ok := to_Mesh(offset_polygon);
    assert(ok);

    entity := New(Polygon_Soup_Entity);
    entity.mesh = mesh;
    entity.shape = offset_polygon;

    array_add(*app.entities, entity);
} else {
    log("Feature unavailable: compile with 'boost_on'\n");
    return;
}
} @RegisterCommand