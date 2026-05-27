export class Duration "A signed elapsed duration with nanosecond precision." {
    // Internal representation: total nanoseconds (may be negative)
    private readonly nanos: long

    // ── Static constructors ──────────────────────────────────────────────────

    static ofNanos(n: long): Duration => Duration { nanos: n }
    static ofMicros(us: long): Duration => Duration { nanos: us * 1000L }
    static ofMillis(ms: long): Duration => Duration { nanos: ms * 1000000L }
    static ofSeconds(s: long): Duration => Duration { nanos: s * 1000000000L }
    static ofMinutes(m: long): Duration => Duration { nanos: m * 60L * 1000000000L }
    static ofHours(h: long): Duration => Duration { nanos: h * 3600L * 1000000000L }
    static ofDays(d: long): Duration => Duration { nanos: d * 86400L * 1000000000L }

    static readonly ZERO = Duration { nanos: 0L }

    // ── Accessors ────────────────────────────────────────────────────────────

    toNanos(): long => nanos
    toMicros(): long => nanos \ 1000L
    toMillis(): long => nanos \ 1000000L
    toSeconds(): long => nanos \ 1000000000L
    toMinutes(): long => nanos \ 60L \ 1000000000L
    toHours(): long => nanos \ 3600L \ 1000000000L
    toDays(): long => nanos \ 86400L \ 1000000000L

    isNegative(): bool => nanos < 0L
    isZero(): bool => nanos == 0L
    abs(): Duration => Duration { nanos: if nanos < 0L then -nanos else nanos }
    negated(): Duration => Duration { nanos: -nanos }

    // ── Arithmetic ───────────────────────────────────────────────────────────

    plus(other: Duration): Duration => Duration { nanos: nanos + other.nanos }
    minus(other: Duration): Duration => Duration { nanos: nanos - other.nanos }
    multipliedBy(factor: long): Duration => Duration { nanos: nanos * factor }
    dividedBy(divisor: long): Duration => Duration { nanos: nanos \ divisor }

    // ── Comparison ───────────────────────────────────────────────────────────

    compareTo(other: Duration): int {
        if nanos < other.nanos { return -1 }
        if nanos > other.nanos { return 1 }
        return 0
    }

    isLessThan(other: Duration): bool => nanos < other.nanos
    isGreaterThan(other: Duration): bool => nanos > other.nanos
    equals(other: Duration): bool => nanos == other.nanos

    // ── Formatting ───────────────────────────────────────────────────────────

    // Returns ISO 8601 duration string, e.g. "PT3H25M10.5S" or "-PT5S"
    toISOString(): string {
        let remaining = if nanos < 0L then -nanos else nanos
        let sign = if nanos < 0L then "-" else ""

        let hours = remaining \ 3600000000000L
        remaining = remaining % 3600000000000L
        let minutes = remaining \ 60000000000L
        remaining = remaining % 60000000000L
        let seconds = remaining \ 1000000000L
        let subsecNanos = remaining % 1000000000L

        let timePart = if subsecNanos == 0L
            then "${hours}H${minutes}M${seconds}S"
            else "${hours}H${minutes}M${seconds}.${string(subsecNanos).padStart(9, '0').trimEnd('0')}S"
        return "${sign}PT${timePart}"
    }
}

export class Thread "Utilities for the current operating-system thread." {
    // Blocks the current thread for the given duration. Zero or negative
    // durations return immediately.
    static sleep(duration: Duration): void {
        _threadSleepNanos(duration.toNanos())
    }
}

import function _threadSleepNanos(nanos: long): void from "doof_time.hpp" as doof_time::thread_sleep_nanos
