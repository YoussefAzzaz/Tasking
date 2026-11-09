# Contract Vectors

This directory contains **canonical JSON test vectors** that validate core domain logic in the Flutter/Dart implementation.

## Files

| File | Written in sprint | Covers |
|------|----------|--------|
| `ids.json` | S03 | UUIDv5 deterministic ID generation |
| `quickadd.json` | S04 | Quick-add natural-language parser |
| `recurrence.json` | S05 | RRULE recurrence advancement |
| `scheduler.json` | S05 | Auto-scheduler output |
| `filters.json` | S06 | In-memory filter evaluation |
| `streaks.json` | S06 | Habit streak calculation |
| `xp.json` | S06 | XP, levels, badges |

## Rules

1. Vectors are **authored by the first platform** that implements the logic.
2. Vectors are **reviewed by the human** and then **frozen**.
3. **Never edit a vector to make a test pass** without explicit human approval.
4. Any domain logic changes must continue to pass all vector test suites.

## Format (all files)

```json
{
  "version": 1,
  "cases": [
    {
      "description": "...",
      "input": { ... },
      "expected": { ... }
    }
  ]
}
```
