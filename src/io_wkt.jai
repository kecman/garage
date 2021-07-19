load_wkt :: (filename : string) -> *Entity {

    log("Loading file '%'... ", filename);

    if !has_extension(filename, "wkt") {
        return null;
    }

    data := read_entire_file(filename);
    defer free(data);

    if !data {
        return null;
    }

    entity : *Entity;

    parser : Parser;
    parser.data = data;
    parser.tokens = get_tokens(filename, parser.data);
    parser.current_token = 0;

    assert(parser.tokens.count > 0);
    assert(parser.tokens[parser.tokens.count - 1].type == .EOF);

    ok : bool = true;

    while peek_token(*parser).type != .EOF && !parser.failed {

        if eat_possible_directive(*parser, "POINT") {

            entity = New(Mesh_Entity);
            entity.mesh.geometry_format = .POINTS;

            expect_and_eat(*parser, xx #char "(");
            point := parse_point(*parser);
            expect_and_eat(*parser, xx #char ")");

            if parser.failed {

                break;

            } else if point.tag == Vector2 {

                array_add(*entity.mesh.positions, make_vector3(<<isa(point, Vector2), 0));

            } else {

                assert(point.tag == Vector3);

                array_add(*entity.mesh.positions, <<isa(point, Vector3));

            }

        } else if eat_possible_directive(*parser, "MULTIPOINT") {

            entity = New(Mesh_Entity);
            entity.mesh.geometry_format = .POINTS;

            expect_and_eat(*parser, xx #char "(");
            points := parse_points(*parser);
            expect_and_eat(*parser, xx #char ")");

            if parser.failed {

                break;

            } else if points.tag == [..]Vector2 {

                for <<isa(points, [..]Vector2) {
                    array_add(*entity.mesh.positions, make_vector3(it, 0));
                }

            } else {

                assert(points.tag == [..]Vector3);

                entity.mesh.positions = <<isa(points, [..]Vector3);

            }

        } else if eat_possible_directive(*parser, "LINESTRING") {

            expect_and_eat(*parser, xx #char "(");
            points := parse_points(*parser);
            expect_and_eat(*parser, xx #char ")");

            if parser.failed {

                break;

            } else if isa(points, [..]Vector2) {

                entity = New(Polyline_Soup2_Entity); // @CompilerBug???????
                e : *Polyline_Soup2_Entity = xx entity;
                array_add(*e.shape.polylines).points = <<isa(points, [..]Vector2);
                e.mesh, ok = to_Mesh(e.shape);
                if !ok parser.failed = true;

            } else {

                assert(isa(points, [..]Vector3) != null);

                entity = New(Polyline_Soup3_Entity);
                e : *Polyline_Soup3_Entity = xx entity; // @CompilerBug???????
                array_add(*e.shape.polylines).points = <<isa(points, [..]Vector3);
                e.mesh, ok = to_Mesh(e.shape);
                if !ok parser.failed = true;

            }

        } else if eat_possible_directive(*parser, "MULTILINESTRING") {

            polyline_soup2 : Polyline_Soup2;
            polyline_soup3 : Polyline_Soup3;

            expect_and_eat(*parser, xx #char "(");
            dim := parse_points_soup(*parser, *polyline_soup2, *polyline_soup3);
            expect_and_eat(*parser, xx #char ")");

            if dim == 2 {

                entity = New(Polyline_Soup2_Entity);
                e : *Polyline_Soup2_Entity = xx entity; // @CompilerBug???????
                e.shape = polyline_soup2;
                e.mesh, ok = to_Mesh(e.shape);
                if !ok parser.failed = true;

            } else if dim == 3 {

                entity = New(Polyline_Soup3_Entity);
                e : *Polyline_Soup3_Entity = xx entity; // @CompilerBug???????
                e.shape = polyline_soup3;
                e.mesh, ok = to_Mesh(e.shape);
                if !ok parser.failed = true;

            } else {
                parser.failed = true;
                break;
            }

        }
        /* else if eat_possible_directive(*parser, "POLYGON") {

            entity := New(Polygon_Soup_Entity);
            parse_polygon(*parser, *entity.shape);
            entity.mesh = to_Mesh(entity.shape);

        }
        */
         else {

            error(*parser, peek_token(*parser), "Unexpected token %.\n", to_string(peek_token(*parser)));
            break;

        }
    }

    if parser.failed || entity.type == .UNKNOWN {
        if entity deinit(entity);
        return null;
    }

    init_entity_base_parameters(entity, filename, entity.mesh);

    return entity;
}

#scope_file

is_number :: (t : Token) -> bool {
    return t.type == .INTEGER || t.type == .FLOAT;
}

// @Refactor: Just pass in the container for the 2d/3d point(s) and return which was filled in!
// @Refactor: Just pass in the container for the 2d/3d point(s) and return which was filled in!
// @Refactor: Just pass in the container for the 2d/3d point(s) and return which was filled in!
// @Refactor: Just pass in the container for the 2d/3d point(s) and return which was filled in!
// @Refactor: Just pass in the container for the 2d/3d point(s) and return which was filled in!
// NB. This should also improve the current debug experience, which isn't great using tagged unions

Parsed_Point :: Tagged_Union(Vector2, Vector3);

// Parses and returns a 2D or 3D point, or sets p.failed to true
parse_point :: (p : *Parser, loc := #caller_location) -> Parsed_Point {
    dim := 0;
    dim += xx is_number(peek_ahead(p, 0));
    dim += xx is_number(peek_ahead(p, 1));
    dim += xx is_number(peek_ahead(p, 2));

    point : Parsed_Point = ---;

    if dim == 2 {
        set(*point, parse_vector2(p));
    } else if dim == 3 {
        set(*point, parse_vector3(p));
    } else {
        error(p, peek_token(p), "Expected 2D or 3D point, got %.\n", peek_token(p).type);
    }

    return point;
}

Parsed_Points :: Tagged_Union([..]Vector2, [..]Vector3);

// Parses and returns an array of 2D or 3D points, or sets p.failed to true
parse_points :: (p : *Parser, loc := #caller_location) -> Parsed_Points {
    points : Parsed_Points = ---;

    while peek_token(p).type != .EOF && peek_token(p).type != xx #char ")" {
        point := parse_point(p);

        if p.failed {
            break;
        } else if point.tag == Vector2 {
            if points.tag == [..]Vector2 {
                array_add(isa(points, [..]Vector2), <<isa(point, Vector2));
            } else if points.tag == [..]Vector3 {
                error(p, peek_token(p), "Expected 3D point but got a 2D point");
            } else {
                points_2d : [..]Vector2;
                array_add(*points_2d, <<isa(point, Vector2));
                set(*points, points_2d);
            }
        } else {
            assert(point.tag == Vector3);
            if points.tag == [..]Vector3 {
                array_add(isa(points, [..]Vector3), <<isa(point, Vector3));
            } else if points.tag == [..]Vector2 {
                error(p, peek_token(p), "Expected 2D point but got a 3D point");
            } else {
                points_3d : [..]Vector3;
                array_add(*points_3d, <<isa(point, Vector3));
                set(*points, points_3d);
            }
        }

        eat_possible_token(p, xx #char ",");
    }

    return points;
}

// Fills in one of the passed point soups and returns a dimension to indicate which
parse_points_soup :: (p : *Parser, polyline_soup2 : *Polyline_Soup2, polyline_soup3 : *Polyline_Soup3, loc := #caller_location) -> dim : int {

    dim := -1;
    while peek_token(p).type != .EOF && peek_token(p).type != xx #char ")" {
        expect_and_eat(p, xx #char "(", loc);

        points := parse_points(p);

        if p.failed {
            break;
        } else if points.tag == [..]Vector2 {
            if dim == 3 {
                error(p, peek_token(p), "Expected 2D point but got a 3D point");
            } else {
                dim = 2;
                polyline : Polyline2;
                polyline.points = <<isa(points, [..]Vector2);
                array_add(*polyline_soup2.polylines, polyline);
            }
        } else if points.tag == [..]Vector3 {
            if dim == 2 {
                error(p, peek_token(p), "Expected 3D point but got a 2D point");
            } else {
                dim = 3;
                polyline : Polyline3;
                polyline.points = <<isa(points, [..]Vector3);
                array_add(*polyline_soup3.polylines, polyline);
            }
        }

        expect_and_eat(p, xx #char ")", loc);
        eat_possible_token(p, xx #char ",");
    }

    return dim;
}


/*
parse_polygon :: (p : *Parser, mesh : *Mesh, loc := #caller_location) {
    mesh.geometry_format = .;

    expect_and_eat(p, xx #char "(", loc);
    point_count_before := mesh.positions.count;

    while peek_token(p).type != .EOF && peek_token(p).type != xx #char ")" {
        parse_point(p, mesh);
        eat_possible_token(p, xx #char ",");
    }

    for point_count_before..mesh.positions.count-2 {
        array_add(*mesh.indices, xx it);
        array_add(*mesh.indices, xx (it + 1));
    }

    expect_and_eat(p, xx #char ")", loc);
}
*/