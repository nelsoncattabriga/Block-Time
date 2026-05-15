# Test Fixtures

## Required: FlightDataModel.sqlite

The migration test suite requires a real v1 `FlightDataModel.sqlite` file to validate
the full Core Data → SwiftData migration path. **This file cannot be synthesised** —
it must come from a device running the production v1 app.

### How to obtain

1. On the development Mac, run a debug build of the v1 app on a Simulator with a
   populated logbook (or restore an iCloud backup containing real flights).
2. In Xcode, with the simulator running: Window → Devices and Simulators →
   Simulators → select the simulator → select Block-Time → "Download Container…".
3. Extract the downloaded `.xcappdata` bundle and find `Library/Application Support/`.
   Locate `FlightDataModel.sqlite`, `FlightDataModel.sqlite-shm`, `FlightDataModel.sqlite-wal`.
4. Copy all three files into this directory: `Block-TimeTests/Fixtures/`.
5. Commit. Tests will automatically pick them up.

### Alternative: extract from a real device

Use a Mac running Finder → Devices → select your iPhone → Files → Block-Time →
drag the container out → locate `FlightDataModel.sqlite` inside.

### If fixture is missing

Migration tests guarded by `try XCTSkip(...)` will SKIP (not fail) when the fixture
is absent. Synthetic-source tests still run. The fixture is REQUIRED before any
TestFlight build is cut (Phase 1 success criterion 1).
