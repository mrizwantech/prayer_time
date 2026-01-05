# Testing Prayer Streak Tracker

## Running Tests

### Run all tests:
```bash
flutter test
```

### Run specific test files:
```bash
flutter test test/achievements_test.dart
flutter test test/prayer_tracking_service_test.dart
```

### Run with coverage:
```bash
flutter test --coverage
```

## Test Coverage

### 1. **achievements_test.dart** (8 tests)
Tests the Achievement system:
- ✅ All 3 achievements are defined
- ✅ Each achievement has correct properties (ID, title, required streak, icon, color)
- ✅ Get achievement by ID works correctly
- ✅ Invalid ID returns null
- ✅ All IDs are unique
- ✅ Achievements ordered by difficulty (7 → 30 → 100 days)

### 2. **prayer_tracking_service_test.dart** (13 tests)

**Prayer Completion Tests:**
- ✅ Mark prayer as complete saves correctly
- ✅ Unmark prayer removes completion
- ✅ New day returns all prayers uncompleted

**Streak Calculation Tests:**
- ✅ Empty data returns 0 streak
- ✅ Single complete day returns streak of 1
- ✅ Incomplete day breaks streak

**Badge Unlock Tests:**
- ✅ 7-day streak unlocks Week Warrior badge
- ✅ 30-day streak unlocks Monthly Master badge
- ✅ Badges persist after app restart

**Monthly Completion Tests:**
- ✅ No completions returns 0%
- ✅ All prayers completed returns 100%
- ✅ Partial completions return correct percentage

**Data Persistence Tests:**
- ✅ Prayer completions persist across sessions

## Manual Testing Checklist

### Basic Functionality:
1. Open Achievements tab (trophy icon)
2. Check today's prayers checkboxes
3. Verify streak counter increases when all 5 prayers checked
4. Uncheck a prayer - streak should reset
5. Check monthly progress bar updates

### Streak Testing:
1. Mark all 5 prayers complete for today
2. Close and reopen app - data should persist
3. Complete prayers for multiple consecutive days
4. Verify streak increases daily

### Badge Unlocking:
1. Complete all prayers for 7 consecutive days
2. Verify Week Warrior badge unlocks (gold color)
3. Verify confetti animation plays
4. Check badge appears in color (not grey)

### Edge Cases:
1. Switch to next day at midnight - verify new checkboxes
2. Missing one prayer - verify streak resets to 0
3. Uncheck and recheck prayer - verify updates correctly

## Expected Results

After running `flutter test`:
- All 21 tests should pass
- 0 failures expected
- Coverage should be >80% for core features

## Troubleshooting

If tests fail:
1. Run `flutter clean && flutter pub get`
2. Ensure SharedPreferences mock is initialized
3. Check date/time logic for timezone issues
4. Verify all imports are correct
