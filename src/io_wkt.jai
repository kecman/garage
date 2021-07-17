test_load_wkt :: () {
    filename :: "data/test-geometry/multi_point.wkt";
    load_wkt(filename);
}

load_wkt :: (filename : string) -> Mesh, success : bool {

    result : Mesh;

    data := read_entire_file(filename);
    defer free(data);

    if !data {
        return result, false;
    }

    parser : Parser;
    parser.data = data;
    parser.tokens = get_tokens(filename, parser.data);
    parser.current_token = 0;

    assert(parser.tokens.count > 0);
    assert(parser.tokens[parser.tokens.count - 1].type == .EOF);

    ok : bool = true;

    while peek_token(*parser).type != .EOF {
        if eat_possible_directive(*parser, "POINT") {
            parse_point(*parser, *result);
        } else if eat_possible_directive(*parser, "MULTIPOINT") {
            parse_multipoint(*parser, *result);
        } else if eat_possible_directive(*parser, "MULTILINESTRING") {
            parse_multilinestring(*parser, *result);
        } else if eat_possible_directive(*parser, "LINESTRING") {
            parse_linestring(*parser, *result);
        } else {
            tok := peek_token(*parser);
            error(*parser, "Parse error at %:%:%. Unexpected token %.\n",
                  tok.location.fully_pathed_filename,
                  tok.location.line_number,
                  tok.location.character_number,
                  to_string(tok));
            break;
        }
    }

    if parser.failed {
        deinit(*result);
        empty : Mesh;
        return empty, false;
    }

    // print_Mesh(result);

    return result, true;
}

is_number :: (t : Token) -> bool {
    return t.type == .INTEGER || t.type == .FLOAT;
}

parse_point :: (p : *Parser, mesh : *Mesh, loc := #caller_location) {
    dim := 0;
    dim += xx is_number(peek_ahead(p, 0));
    dim += xx is_number(peek_ahead(p, 1));
    dim += xx is_number(peek_ahead(p, 2));

    if dim == 2 {
        array_add(*mesh.positions, make_vector3(parse_vector2(p), 0));
    } else if dim == 3 {
        array_add(*mesh.positions, parse_vector3(p));
    } else {
        tok := peek_token(p);
        error(p, "Parse error at %:%:%. Expected 2D or 3D point, got %.\n",
              tok.location.fully_pathed_filename,
              tok.location.line_number,
              tok.location.character_number,
              tok.type);
    }
}

parse_multipoint :: (p : *Parser, mesh : *Mesh, loc := #caller_location) {
    mesh.geometry_format = .POINTS;

    expect_and_eat(p, xx #char "(", loc);

    while peek_token(p).type != .EOF && peek_token(p).type != xx #char ")" {
        parse_point(p, mesh);
        eat_possible_token(p, xx #char ",");
    }

    expect_and_eat(p, xx #char ")", loc);
}

parse_linestring :: (p : *Parser, mesh : *Mesh, loc := #caller_location) {
    mesh.geometry_format = .LINES;

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

parse_multilinestring :: (p : *Parser, mesh : *Mesh, loc := #caller_location) {
    mesh.geometry_format = .LINES;

    expect_and_eat(p, xx #char "(", loc);

    while peek_token(p).type != .EOF && peek_token(p).type != xx #char ")" {
        parse_linestring(p, mesh);
        eat_possible_token(p, xx #char ",");
    }

    expect_and_eat(p, xx #char ")", loc);
}
