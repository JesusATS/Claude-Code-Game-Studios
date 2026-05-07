# Test Infrastructure

**Engine**: Godot 4.6
**Test Framework**: GdUnit4 (install via AssetLib — see below)
**CI**: `.github/workflows/tests.yml`
**Setup date**: 2026-05-04

## Directory Layout

```
tests/
  unit/           # Isolated unit tests (formulas, state machines, logic)
  integration/    # Cross-system and save/load tests
  smoke/          # Critical path test list for /smoke-check gate
  evidence/       # Screenshot logs and manual test sign-off records
  gdunit4_runner.gd  # Headless runner invoked by CI
```

## Installing GdUnit4

1. Open Godot → AssetLib → search "GdUnit4" → Download & Install
2. Enable the plugin: Project → Project Settings → Plugins → GdUnit4 ✓
3. Restart the editor
4. Verify: `res://addons/gdunit4/` exists

## Running Tests

**In-editor**: GdUnit4 panel appears in the bottom dock after plugin install. Click "Run All".

**Headless (CI / command line)**:
```
godot --headless --script tests/gdunit4_runner.gd
```

## Test Naming

- **Files**: `[system]_[feature]_test.gd`
- **Functions**: `test_[scenario]_[expected]()`
- **Example**: `combat_damage_test.gd` → `test_base_attack_returns_expected_damage()`
- **Classes**: `class_name [System][Feature]Test extends GdUnitTestSuite`

## Story Type → Test Evidence

| Story Type | Required Evidence | Location | Gate Level |
|---|---|---|---|
| Logic (formulas, AI, state machines) | Automated unit test — must pass | `tests/unit/[system]/` | BLOCKING |
| Integration (multi-system) | Integration test OR documented playtest | `tests/integration/[system]/` | BLOCKING |
| Visual/Feel (animation, VFX, feel) | Screenshot + lead sign-off | `tests/evidence/` | ADVISORY |
| UI (menus, HUD, screens) | Manual walkthrough doc OR interaction test | `tests/evidence/` | ADVISORY |
| Config/Data (balance tuning) | Smoke check pass | `production/qa/smoke-*.md` | ADVISORY |

## CI

Tests run automatically on every push to `main` and on every pull request.
A failed test suite blocks merging — never disable or skip a failing test to
make CI pass. Fix the underlying issue.

See `.github/workflows/tests.yml` for the full workflow configuration.
