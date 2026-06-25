# std/time Guide

`std/time` provides elapsed durations, UTC instants, timezone-free calendar
values, IANA timezone conversion, current-thread sleeping, and named stopwatch
measurements.

## Choosing A Type

- `Duration` represents signed elapsed time with nanosecond precision.
- `Instant` represents a UTC point in time.
- `Date`, `Time`, and `DateTime` represent wall-clock calendar values without a
  timezone.
- `TimeZone` represents an IANA timezone.
- `ZonedDateTime` pairs a local `DateTime` with a `TimeZone`.
- `Stopwatch` records named elapsed spans for instrumentation.

## Arithmetic And Conversion

Use `Duration` for timeouts and elapsed work. Use `Instant` for deadlines and
ordering events. Convert `DateTime` to an instant only after deciding which
timezone should interpret the wall-clock value.

`withZoneSameInstant` preserves the underlying moment and changes presentation.
`withZoneSameLocal` preserves the wall-clock fields and changes the represented
moment.

Date month/year arithmetic clamps to valid calendar days. Time arithmetic wraps
within a 24-hour day.

## Parsing And Formatting

Parsing returns `Result<T, string>`. Types support ISO-style parse/format helpers
where appropriate. `Instant` also supports HTTP date parsing/formatting for
headers and cache validators.

## Sleeping And Measuring

`Thread.sleep(duration)` blocks the current OS thread. Zero or negative
durations return immediately.

`Stopwatch.measure(name)` returns a span that records on `finish()` or at the
end of a `with` block. Aggregates such as `total`, `mean`, `min`, `max`, and
`p95` return `Result<Duration, TimerError>` when the label has no samples.

## API Map

Elapsed and UTC:

- `Duration`
- `Instant`
- `Thread`

Calendar and zones:

- `Date`
- `Time`
- `DateTime`
- `TimeZone`
- `ZonedDateTime`
- `DayOfWeek`
- `Month`

Measurement:

- `Stopwatch`
- `StopwatchSpan`
- `TimerError`
- `TimerStats`
- `TimerSummary`

Declarations are defined in [duration.do](../duration.do), [temporal.do](../temporal.do),
and [stopwatch.do](../stopwatch.do).
