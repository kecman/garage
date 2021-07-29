#import "Basic";
#import "Check";
#import "Compiler";
#import "Sort";
#import "String";

build :: () {

    {
        // This is a build file that doesn't generate an executable
        using build_options := get_build_options();
        defer set_build_options(build_options);
        output_type = .NO_OUTPUT;
    }

    set_working_directory(#filepath);

    // Create a workspace where we will compile our actual program
    w := compiler_create_workspace();
    if !w exit(1);

    command_line_arguments := compiler_get_command_line_arguments();
    help_found    := array_find(command_line_arguments, "help");
    test_found    := array_find(command_line_arguments, "test");
    demo_found    := array_find(command_line_arguments, "demo");
    release_found := array_find(command_line_arguments, "release");
    checks_found  := array_find(command_line_arguments, "checks");
    boost_found   := array_find(command_line_arguments, "boost_on");

    if help_found {
        print(help_string);
        exit(0);
    }

    {
        using build_options := get_build_options(w);
        defer set_build_options(build_options, w);

        output_type = .EXECUTABLE;
        lazy_foreign_function_lookups = true;

        if      test_found output_executable_name = "test";
        else if demo_found output_executable_name = "demo";
        else               output_executable_name = "garage";

        if checks_found {
            array_bounds_check = .ON;
            cast_bounds_check  = .FATAL;
            math_bounds_check  = .FATAL;
        }

        if release_found {
            set_optimization_level(*build_options, 3, 3);
        } else {
            // memory_debugger = true;
            // llvm_options.debug_options = .["-g"];
        }

        CWD :: #run get_working_directory();

        _import_path : [..]string;
        for import_path array_add(*_import_path, it);
        array_add(*_import_path, join(CWD, "src/modules", separator="/"));
        import_path = _import_path;
    }

    {
        compiler_begin_intercept(w);
        defer compiler_end_intercept(w);

        add_build_string(version_string, w);

        if      test_found add_build_file("src/test.jai", w);
        else if demo_found add_build_file("src/demo.jai", w);
        else               add_build_file("src/main.jai", w);

        if boost_found     add_build_string("ENABLE_BOOST_POLYGON :: true;", w);
        else               add_build_string("ENABLE_BOOST_POLYGON :: false;", w);

        while true {
            message := compiler_wait_for_message();
            if !message                  continue;
            if message.workspace != w    continue;

            do_error_checking(message);

            has_note :: (header: *Code_Procedure_Header, note: string) -> bool {
                for header.notes  if it.text == note  return true;
                return false;
            }

            if message.kind == {
                case .TYPECHECKED;
                  typechecked := cast(*Message_Typechecked) message;

                  for tc: typechecked.procedure_headers {
                      header := tc.expression;
                      if has_note(header, "RegisterCommand") {
                          array_add(*registered_console_commands, header);
                      }
                  }

                case .PHASE;
                    phase := cast(*Message_Phase) message;
                    if phase.phase == .TYPECHECKED_ALL_WE_CAN {
                        if !generated_code {
                            generate_code_to_register_console_commands(message.workspace);
                            generated_code = true;
                        }
                    }

                case .COMPLETE;
                    break;
            }
        }
    }
}

generated_code := false;
registered_console_commands : [..]*Code_Procedure_Header;

// @Incomplete error on pointers
// @Incomplete support optional arguments
// @Incomplete detect and error on overflow
generate_code_to_register_console_commands :: (w : Workspace) {

    Print :: (format_string : string, args : ..Any) #expand {
        print_to_builder(*builder, format_string, ..args);
    }

    builder: String_Builder;
    defer free_buffers(*builder);

    // Sort commands by name so that help lists them in alphabetic order
    quick_sort(registered_console_commands, (a,b) => (compare_strings(a.name, b.name)));

    Print("init_commands :: () {\n");
    for registered_console_commands {
        path := it.enclosing_load.fully_pathed_filename;

        if it.returns.count != 0 {
            compiler_report(path, it.l0, it.c0, tprint("Console commands must have 0 return values, got %", it.returns.count));
        }

        Print("    {\n");
        Print("        info : Command_Info;\n");
        Print("        info.name = \"%\";\n", it.name);
        Print("        info.procedure = %_boiler_plate;\n", it.name);
        Print("        array_add(*app.console.commands, info);\n");
        Print("    }\n");
    }
    Print("}\n\n");

    for command, command_index : registered_console_commands {
        path := command.enclosing_load.fully_pathed_filename;

        Print("%_boiler_plate :: (args : []Any) {\n", command.name);
        Print("    if args.count != % {\n", command.arguments.count);
        plural : string = ifx command.arguments.count == 1 then "" else "s";
        Print("        console_add_log(\"[error] expected % argument%, got %%.\", args.count);\n", command.arguments.count, plural);
        Print("        return;\n");
        Print("    }\n\n");

        // Argument typechecking
        for arg, arg_index : command.arguments {

            if arg.type.type == {
                case .INTEGER;
                    Print("    if args[%].type.type != .INTEGER {\n", arg_index);
                    Print("        console_add_log(\"[error] argument % is not an int\");\n", arg_index);
                    Print("        return;\n");
                    Print("    }\n");
                case .FLOAT;
                    Print("    if args[%1].type.type != .FLOAT || args[%1].type.type != .INTEGER {\n", arg_index);
                    Print("        console_add_log(\"[error] argument % is not a float (or int)\");\n", arg_index);
                    Print("        return;\n");
                    Print("    }\n");
                case .STRING;
                    Print("    if args[%].type.type != .STRING {\n", arg_index);
                    Print("        console_add_log(\"[error] argument % is not an string\");\n", arg_index);
                    Print("        return;\n");
                    Print("    }\n");
                case;
                    compiler_report(path, arg.l0, arg.c0, tprint("Unsupported console command argument type %, only int/float/string are supported.", arg.type.type));
            }

            Print("\n");
        }

        // Assign values to arguments
        for arg, arg_index : command.arguments {

            if arg.type.type == {
                case .INTEGER;
                    Print("    a%1 : int = ---;\n", arg_index);
                    Print("    a%1 = xx <<cast(*s64)(args[%1].value_pointer);\n", arg_index);
                case .FLOAT;
                    Print("    a%1 : float = ---;\n", arg_index);
                    Print("    if args[%1].type.type != .FLOAT {\n", arg_index);
                    Print("        a%1 = xx <<cast(*float64)(args[%1].value_pointer);\n", arg_index);
                    Print("    } else if args[%1].type.type != .INTEGER {\n", arg_index);
                    Print("        a%1 = xx <<cast(*s64)(args[%1].value_pointer);\n", arg_index);
                    Print("    }\n");
                case .STRING;
                    Print("    a%1 : string = ---;\n", arg_index);
                    Print("    a%1 = xx <<cast(*string)(args[%1].value_pointer);\n", arg_index);
                case;
                    compiler_report(path, arg.l0, arg.c0, tprint("Unsupported console command argument type %, only int/float/string are supported.", arg.type.type));
            }

            Print("\n");
        }


        // Call the function
        Print("    %(", command.name);
        for arg, arg_index : command.arguments {
            comma := ifx arg_index != command.arguments.count - 1 then ", " else "";
            Print("a%1%", arg_index, comma);
        }
        Print(");\n");
        Print("}\n\n");
    }

    add_build_string(builder_to_string(*builder), w);
}

#run build();

version_string :: #string DONE
VERSION_STRING :: "0.1.3-rc";
DONE

help_string :: #string DONE

Build Options:
  debug      build debug mode (default)
  release    build release mode
  checks     enable array bounds checks and fatal cast and math bounds checks
  boost_on   compile with boost polygon bindings (default off since the library isn't distributed yet)

Build Targets:
  garage     build garage target (default)
  test       build test target
  demo       build demo target

DONE
