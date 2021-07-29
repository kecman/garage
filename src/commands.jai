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
    for app.console.history console_add_log("# % %", it_index, it);
} @RegisterCommand

clear :: () {
    console_clear_log();
} @RegisterCommand

// @Incomplete write usage here too, or write the procedure parameters
help :: () {
    console_add_log("# Available commands:");
    for app.console.commands console_add_log("#  %", it.usage);
} @RegisterCommand

select_if :: (type : Entity_Type) {
    for app.entities {
        it.is_selected = (it.type == type);
    }
}

select_if_Polyline_Soup2 :: () { select_if(.POLYLINE_SOUP2); } @RegisterCommand
select_if_Polyline_Soup3 :: () { select_if(.POLYLINE_SOUP3); } @RegisterCommand
select_if_Polygon_Soup   :: () { select_if(.POLYGON_SOUP);   } @RegisterCommand
select_if_Mesh           :: () { select_if(.MESH);           } @RegisterCommand

sort_by_name :: (alphabetical : int = 1) { // @Incomplete: allow this to be a boolean!
    compare_alphabetical :: (a : *Entity, b : *Entity) -> s64 {
        return compare_strings(a.fully_pathed_filename, b.fully_pathed_filename);
    }

    compare_reverse_alphabetical :: (a : *Entity, b : *Entity) -> s64 {
        return compare_strings(b.fully_pathed_filename, a.fully_pathed_filename);
    }

    if   alphabetical quick_sort(app.entities, compare_alphabetical);
    else              quick_sort(app.entities, compare_reverse_alphabetical);
} @RegisterCommand

// @Cleanup This is a pretty weird way to do this...
sort_by_load_time :: (ascending : int = 1) { // @Incomplete: allow this to be a boolean!
    compare_ascending :: (a : *Entity, b : *Entity) -> s64 {
        at := filetime_to_readable_date(a.loaded_filetime);
        bt := filetime_to_readable_date(b.loaded_filetime);
        if at == bt return compare_strings(b.fully_pathed_filename, a.fully_pathed_filename);
        return compare_strings(bt, at);
    }

    compare_descending :: (a : *Entity, b : *Entity) -> s64 {
        at := filetime_to_readable_date(a.loaded_filetime);
        bt := filetime_to_readable_date(b.loaded_filetime);
        if at == bt return compare_strings(a.fully_pathed_filename, b.fully_pathed_filename);
        return compare_strings(at, bt);
    }

    if   ascending quick_sort(app.entities, compare_ascending);
    else           quick_sort(app.entities, compare_descending);
} @RegisterCommand

sort_by_point_count :: (ascending : int = 1) { // @Incomplete: allow this to be a boolean!
    compare_ascending :: (a : *Entity, b : *Entity) -> s64 {
        if a.mesh.positions.count == b.mesh.positions.count {
            return compare_strings(a.fully_pathed_filename, b.fully_pathed_filename);
        }
        return compare_floats(xx a.mesh.positions.count, xx b.mesh.positions.count);
    }

    compare_descending :: (a : *Entity, b : *Entity) -> s64 {
        if a.mesh.positions.count == b.mesh.positions.count {
            return compare_strings(b.fully_pathed_filename, a.fully_pathed_filename);
        }
        return compare_floats(xx b.mesh.positions.count, xx a.mesh.positions.count);
    }

    if   ascending quick_sort(app.entities, compare_ascending);
    else           quick_sort(app.entities, compare_descending);
} @RegisterCommand

clockwise_boundaries :: (item_index : int) {
    // @Refactor move this to boiler plate e.g., by adding special syntax for ints which are geometry indices
    if !check_geometry_index(item_index) {
        return;
    }

#if ENABLE_BOOST_POLYGON {

    it := app.entities[item_index];

    if it.type != .POLYGON_SOUP {
        console_add_log("[error] clockwise_boundaries not supported for entity type %", it.type);
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
    console_add_log("[error] Feature unavailable: compile with 'boost_on'\n");
    return;
}
} @RegisterCommand

offset :: (item_index : int, radius : float) {
#if ENABLE_BOOST_POLYGON {

    // @Refactor move this to boiler plate e.g., by adding special syntax for ints which are geometry indices
    if !check_geometry_index(item_index) {
        return;
    }

    // @CompilerBug I don't see the entities global in gdb here?? This is probably fixed (according to the Jai changelog, need to verify)

    it := app.entities[item_index];

    if it.type != .POLYLINE_SOUP2 {
        yet := ifx it.type == .POLYGON_SOUP then " yet " else " ";
        console_add_log("[error] offset not%supported for entity type %", yet, it.type);
        return; // @Incomplete support polygons
    }

    console_add_log("# offsetting % by % and returning boundaries", item_index, radius);

    polyline_soup2_entity := cast(*Polyline_Soup2_Entity) it;

    #import "BoostPolygon";
    offset_polygon := BoostPolygon.offset(*polyline_soup2_entity.shape, radius);
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
    console_add_log("[error] Feature unavailable: compile with 'boost_on'\n");
    return;
}
} @RegisterCommand