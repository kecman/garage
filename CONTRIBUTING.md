# Coding style

Non-dogmatic, mostly do what you want but sticking to the following conventions would be appreciated:

- function_names
- Macro_Names
- Structs_And_Types
- COMPILE_TIME_CONSTANTS (including enum names)

Using a single space between a name and the ::, : or := makes searching for declarations easier

# Release process

This tool is intended to be hackable and compiled from source as you use it. So it doesn't really make sense to release binaries, however, this is what we do while Jai is in closed beta.

From the top-level project directory do the following:

1. Update `build.jai` with the new version number
2. Update `CHANGELOG.md` to add the release date
3. Update `PLAN.md` checking tasks are placed appropriately in the prioritized/backlog sections
4. Compile using: `jai build.jai -x64 -- release boost_on`
5. Make a release folder: `mkdir garage-vNNN`
6. Copy artefacts to this folder: `cp -r *.md src/modules/BoostPolygon/linux/libinterface.so garage data/ garage-vNNN/`
7. Zip the release folder: `tar -cvzf garage-vNNN.tar.gz garage-vNNN`
8. Move the zip elsewhere and test it unzips and works
9. Tag the release commit: `git tag vNNN && git push --tags`

Note: Delete tags using: `git tag --delete vNNN && git push --delete origin vNNN`