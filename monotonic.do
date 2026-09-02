import { Duration } from "./duration"

export class MonotonicInstant "A process-local time point from a monotonic clock." {
    private readonly ticksNanos: long

    // Returns a time point from a clock that cannot move backwards as wall-clock
    // time is adjusted. Values are only meaningful within the current process.
    static now(): MonotonicInstant {
        return MonotonicInstant { ticksNanos: _monotonicNanos() }
    }

    plus(duration: Duration): MonotonicInstant =>
        MonotonicInstant { ticksNanos: ticksNanos + duration.toNanos() }

    minus(duration: Duration): MonotonicInstant =>
        MonotonicInstant { ticksNanos: ticksNanos - duration.toNanos() }

    durationUntil(other: MonotonicInstant): Duration =>
        Duration.ofNanos(other.ticksNanos - ticksNanos)

    durationSince(other: MonotonicInstant): Duration =>
        Duration.ofNanos(ticksNanos - other.ticksNanos)

    compareTo(other: MonotonicInstant): int {
        if ticksNanos < other.ticksNanos { return -1 }
        if ticksNanos > other.ticksNanos { return 1 }
        return 0
    }

    isBefore(other: MonotonicInstant): bool => ticksNanos < other.ticksNanos
    isAfter(other: MonotonicInstant): bool => ticksNanos > other.ticksNanos
    equals(other: MonotonicInstant): bool => ticksNanos == other.ticksNanos
}

import isolated function _monotonicNanos(): long from "doof_time.hpp" as doof_time::monotonic_nanos
