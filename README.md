# std/time

Date, time, duration, and timezone handling for Doof. The package provides UTC instants, timezone-free calendar and clock types, and IANA timezone conversion through the platform time database.

## Examples

### Measure elapsed time and deadlines

```doof
import { Duration, Instant } from "std/time"

startedAt := Instant.now()
timeout := Duration.ofSeconds(30L)
deadline := startedAt.plus(timeout)

pollInterval := Duration.ofMillis(250L)
maxPolls := timeout.toMillis() \ pollInterval.toMillis()

println("deadline: ${deadline.toISOString()}")
println("timeout: ${timeout.toISOString()}")
println("poll interval: ${pollInterval.toMillis()} ms")
println("max polls: ${maxPolls}")
```

`Instant` represents a point in UTC time, while `Duration` models signed elapsed time with nanosecond precision. Both types support arithmetic, comparison, parsing, and ISO formatting. `Duration.toISOString()` uses compact valid forms such as `PT5S`, `PT3H25M10.5S`, and `P2DT3H`.

### Sleep the current thread

```doof
import { Duration, Thread } from "std/time"

Thread.sleep(Duration.ofMillis(50L))
```

`Thread.sleep(...)` blocks the current operating-system thread for the requested duration. Zero or negative durations return immediately.

### Collect named timings

```doof
import { Stopwatch } from "std/time"

sw := Stopwatch()

with span := sw.measure("parse") {
    // ... parsing work ...
}

manual := sw.measure("render")
// ... rendering work ...
manual.finish()

println(sw.count("parse"))
println((try! sw.total("parse")).toMillis())
println((try! sw.p95("render")).toMillis())
```

`Stopwatch` records named spans and reports aggregate `Duration` values for each name. Scoped spans finish automatically when the `with` block exits; manual spans can be finished explicitly and are recorded only once.

### Build calendar values and move them around safely

```doof
import { Date, DateTime, Month, Time } from "std/time"

payrollDate := try! Date.create(2024, Month.January.value, 31)
nextPayrollDate := payrollDate.plusMonths(1)

standup := try! Time.create(9, 45)
reminderTime := standup.plusMinutes(20)

releaseWindow := DateTime.create(nextPayrollDate, reminderTime)

println(payrollDate.dayOfWeek().name)
println(nextPayrollDate.toISOString())
println(releaseWindow.toISOString())
```

`Date` clamps month and year arithmetic to valid calendar days, `Time` wraps around within a 24-hour day, and `DateTime` combines both without attaching a timezone.

### Convert the same meeting between time zones

```doof
import { DateTime, TimeZone } from "std/time"

newYork := try! TimeZone.lookup("America/New_York")
london := try! TimeZone.lookup("Europe/London")
tokyo := try! TimeZone.lookup("Asia/Tokyo")

meetingLocal := try! DateTime.fromParts(2024, 10, 4, 9, 30)
meetingInNewYork := meetingLocal.atZone(newYork)

sameInstantInLondon := meetingInNewYork.withZoneSameInstant(london)
sameWallClockInTokyo := meetingInNewYork.withZoneSameLocal(tokyo)

println(meetingInNewYork.toISOString())
println(sameInstantInLondon.toISOString())
println(sameWallClockInTokyo.toISOString())
```

Use `withZoneSameInstant(...)` when the underlying moment must stay the same and only the presentation zone changes. Use `withZoneSameLocal(...)` when the wall clock time should stay the same and the represented instant is allowed to change.

### Parse input and inspect timezone rules

```doof
import { Date, DateTime, Duration, Instant, TimeZone } from "std/time"

launchDate := try! Date.parse("2026-04-21")
publishedAt := try! Instant.parse("2026-04-21T14:00:00Z")
servedAt := try! Instant.parseHttpDate("Tue, 21 Apr 2026 14:00:00 GMT")
reviewSlot := try! DateTime.parse("2026-04-21T16:30:00")
timeout := try! Duration.parse("PT30S")

sydney := try! TimeZone.lookup("Australia/Sydney")
offsetSeconds := sydney.offsetSecondsAt(publishedAt)

println(launchDate.dayOfYear())
println(reviewSlot.toInstant(sydney).toISOString())
println(servedAt.toHttpDate())
println("Timeout: ${timeout.toISOString()}")
println("UTC offset: ${offsetSeconds} seconds")
println("DST active: ${sydney.isDSTAt(publishedAt)}")
```

Parsing returns `Result<T, string>`, so you can propagate failures with `try!` or handle them explicitly with `case`.

## Type Guide

### `Duration`

Signed elapsed time with nanosecond precision. Use unit constructors like `ofSeconds(...)`, `ofMinutes(...)`, and `ofDays(...)`, parse ISO 8601 durations with `parse(...)`, then combine values with arithmetic or format them as compact ISO 8601 durations.

### `Instant`

UTC timestamp stored as nanoseconds since the Unix epoch. Supports clock reads with `now()`, parsing from RFC 3339 strings and HTTP IMF-fixdate strings, arithmetic with `Duration`, and conversion to `DateTime` or `ZonedDateTime`.

### `Thread`

Current-thread utilities. Use `sleep(...)` with a `Duration` to block the current operating-system thread.

### `Stopwatch`

Named timing collector for lightweight instrumentation. Use `measure(...)` to create spans, `count(...)` for the number of recorded spans, aggregate methods such as `total(...)`, `mean(...)`, `min(...)`, `max(...)`, and `p95(...)` for durations, and `summary()` for per-label stats.

### `Date`

Calendar date without a timezone. Includes validation, leap-year helpers, day-of-week and day-of-year queries, date arithmetic, parsing, and ISO formatting.

### `Time`

Time of day with nanosecond precision. Includes parsing, comparison, ISO formatting, and wraparound arithmetic for hour, minute, second, or nanosecond adjustments.

### `DateTime`

Combined `Date` and `Time` without a timezone. Useful for local wall-clock values that are later interpreted either as UTC or in a specific `TimeZone`.

### `TimeZone`

IANA timezone identifier with offset and DST queries. Use `lookup(...)` for named zones like `Europe/London`, `UTC` for the fixed zero-offset zone, and `local()` for the system timezone.

### `ZonedDateTime`

`DateTime` paired with a `TimeZone`. Supports conversion that either preserves the instant (`withZoneSameInstant`) or preserves the local wall-clock value (`withZoneSameLocal`).

### `DayOfWeek`

Monday-first day-of-week enum with numeric values `1` through `7`.

### `Month`

Month-of-year enum from January through December, useful when you want named calendar values instead of raw integers.
