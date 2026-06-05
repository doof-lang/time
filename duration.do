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

    // Parses ISO 8601 durations such as "PT5S", "P2DT3H4M", or "-PT0.5S".
    static parse(s: string): Result<Duration, string> {
        return parseDuration(s)
    }

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

        let days = remaining \ 86400000000000L
        remaining = remaining % 86400000000000L
        let hours = remaining \ 3600000000000L
        remaining = remaining % 3600000000000L
        let minutes = remaining \ 60000000000L
        remaining = remaining % 60000000000L
        let seconds = remaining \ 1000000000L
        let subsecNanos = remaining % 1000000000L

        let result = "${sign}P"
        if days != 0L {
            result = "${result}${days}D"
        }

        let timePart = ""
        if hours != 0L {
            timePart = "${timePart}${hours}H"
        }
        if minutes != 0L {
            timePart = "${timePart}${minutes}M"
        }
        if subsecNanos != 0L {
            timePart = "${timePart}${seconds}.${string(subsecNanos).padStart(9, '0').trimEnd('0')}S"
        } else if seconds != 0L || days == 0L && hours == 0L && minutes == 0L {
            timePart = "${timePart}${seconds}S"
        }

        if timePart.length > 0 {
            result = "${result}T${timePart}"
        }

        return result
    }
}

function parseDuration(s: string): Result<Duration, string> {
    if s.length < 2 {
        return Failure { error: "Invalid duration format" }
    }

    let index = 0
    let sign = 1L
    if s.charAt(index) == '-' {
        sign = -1L
        index = index + 1
    } else if s.charAt(index) == '+' {
        index = index + 1
    }

    if index >= s.length || s.charAt(index) != 'P' {
        return Failure { error: "Duration must start with 'P'" }
    }
    index = index + 1

    let total = 0L
    let inTime = false
    let sawComponent = false
    let lastOrder = 0

    while index < s.length {
        if s.charAt(index) == 'T' {
            if inTime {
                return Failure { error: "Duration contains duplicate time marker" }
            }
            inTime = true
            index = index + 1
            if index >= s.length {
                return Failure { error: "Duration time marker must be followed by a component" }
            }
            continue
        }

        if !isDigit(s.charAt(index)) {
            return Failure { error: "Duration component must start with a digit" }
        }

        let whole = 0L
        while index < s.length && isDigit(s.charAt(index)) {
            whole = whole * 10L + long(digitValue(s.charAt(index)))
            index = index + 1
        }

        let fractionNanos = 0L
        let hasFraction = false
        if index < s.length && s.charAt(index) == '.' {
            hasFraction = true
            index = index + 1
            let digits = 0
            while index < s.length && isDigit(s.charAt(index)) {
                if digits >= 9 {
                    return Failure { error: "Duration fractional seconds must use at most 9 digits" }
                }
                fractionNanos = fractionNanos * 10L + long(digitValue(s.charAt(index)))
                digits = digits + 1
                index = index + 1
            }
            if digits == 0 {
                return Failure { error: "Duration fraction must contain digits" }
            }
            while digits < 9 {
                fractionNanos = fractionNanos * 10L
                digits = digits + 1
            }
        }

        if index >= s.length {
            return Failure { error: "Duration component missing designator" }
        }

        let designator = s.charAt(index)
        index = index + 1

        let order = 0
        let multiplier = 0L
        if designator == 'D' {
            if inTime || hasFraction {
                return Failure { error: "Invalid duration day component" }
            }
            order = 1
            multiplier = 86400000000000L
        } else if designator == 'H' {
            if !inTime || hasFraction {
                return Failure { error: "Invalid duration hour component" }
            }
            order = 2
            multiplier = 3600000000000L
        } else if designator == 'M' {
            if !inTime || hasFraction {
                return Failure { error: "Invalid duration minute component" }
            }
            order = 3
            multiplier = 60000000000L
        } else if designator == 'S' {
            if !inTime {
                return Failure { error: "Invalid duration second component" }
            }
            order = 4
            multiplier = 1000000000L
        } else {
            return Failure { error: "Invalid duration component designator" }
        }

        if order <= lastOrder {
            return Failure { error: "Duration components must be in ISO order" }
        }
        lastOrder = order

        total = total + whole * multiplier
        if hasFraction {
            total = total + fractionNanos
        }
        sawComponent = true
    }

    if !sawComponent {
        return Failure { error: "Duration must contain at least one component" }
    }

    return Success { value: Duration.ofNanos(total * sign) }
}

function isDigit(c: char): bool => c >= '0' && c <= '9'

function digitValue(c: char): int {
    if c == '0' { return 0 }
    if c == '1' { return 1 }
    if c == '2' { return 2 }
    if c == '3' { return 3 }
    if c == '4' { return 4 }
    if c == '5' { return 5 }
    if c == '6' { return 6 }
    if c == '7' { return 7 }
    if c == '8' { return 8 }
    return 9
}

export class Thread "Utilities for the current operating-system thread." {
    // Blocks the current thread for the given duration. Zero or negative
    // durations return immediately.
    static sleep(duration: Duration): void {
        _threadSleepNanos(duration.toNanos())
    }
}

import function _threadSleepNanos(nanos: long): void from "doof_time.hpp" as doof_time::thread_sleep_nanos
