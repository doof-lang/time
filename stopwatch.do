import { Duration } from "./duration"
import { Instant } from "./temporal"

export class TimerError {
    readonly kind: string
    readonly name: string
    readonly message: string
}

export class TimerStats {
    readonly name: string
    readonly count: int
    readonly total: Duration
    readonly mean: Duration
    readonly min: Duration
    readonly max: Duration
    readonly p95: Duration
}

export class TimerSummary {
    readonly entries: readonly TimerStats[]
}

class TimerBucket {
    count: int = 0
    totalNanos: long = 0L
    minNanos: long = 0L
    maxNanos: long = 0L
    durations: long[] = []

    record(duration: Duration): void {
        let nanos = duration.toNanos()
        if count == 0 {
            minNanos = nanos
            maxNanos = nanos
        } else {
            if nanos < minNanos { minNanos = nanos }
            if nanos > maxNanos { maxNanos = nanos }
        }

        count += 1
        totalNanos += nanos
        insertSorted(nanos)
    }

    total(): Duration => Duration.ofNanos(totalNanos)
    mean(): Duration => Duration.ofNanos(totalNanos \ long(count))
    min(): Duration => Duration.ofNanos(minNanos)
    max(): Duration => Duration.ofNanos(maxNanos)

    p95(): Duration {
        let index = ((count * 95 + 99) \ 100) - 1
        return Duration.ofNanos(durations[index])
    }

    private insertSorted(nanos: long): void {
        durations.push(nanos)
        let index = durations.length - 1

        while index > 0 && durations[index - 1] > nanos {
            durations[index] = durations[index - 1]
            index -= 1
        }

        durations[index] = nanos
    }
}

export class Stopwatch {
    private timers: Map<string, TimerBucket> = {}

    measure(name: string): StopwatchSpan {
        return StopwatchSpan {
            stopwatch: this,
            name,
            startedAt: Instant.now(),
        }
    }

    count(name: string): int {
        bucket := bucketFor(name) else { return 0 }
        return bucket.count
    }

    total(name: string): Result<Duration, TimerError> {
        try bucket := requireBucket(name)
        return Success { value: bucket.total() }
    }

    mean(name: string): Result<Duration, TimerError> {
        try bucket := requireBucket(name)
        return Success { value: bucket.mean() }
    }

    min(name: string): Result<Duration, TimerError> {
        try bucket := requireBucket(name)
        return Success { value: bucket.min() }
    }

    max(name: string): Result<Duration, TimerError> {
        try bucket := requireBucket(name)
        return Success { value: bucket.max() }
    }

    p95(name: string): Result<Duration, TimerError> {
        try bucket := requireBucket(name)
        return Success { value: bucket.p95() }
    }

    summary(): TimerSummary {
        entries: TimerStats[] := []

        for name, bucket of timers {
            entries.push(TimerStats {
                name,
                count: bucket.count,
                total: bucket.total(),
                mean: bucket.mean(),
                min: bucket.min(),
                max: bucket.max(),
                p95: bucket.p95(),
            })
        }

        return TimerSummary {
            entries: entries.buildReadonly(),
        }
    }

    private record(name: string, duration: Duration): void {
        let bucket = bucketFor(name) ?? TimerBucket {}
        if !timers.has(name) {
            timers.set(name, bucket)
        }
        bucket.record(duration)
    }

    private bucketFor(name: string): TimerBucket | null {
        return case timers.get(name) {
            s: Success -> s.value,
            _: Failure -> null
        }
    }

    private requireBucket(name: string): Result<TimerBucket, TimerError> {
        bucket := bucketFor(name) else {
            return Failure { error: missingTimer(name) }
        }
        return Success { value: bucket }
    }
}

export class StopwatchSpan {
    stopwatch: Stopwatch
    readonly name: string
    readonly startedAt: Instant
    private finished: bool = false
    private finishedDuration: Duration | null = null

    finish(): Duration {
        if finished {
            return finishedDuration!
        }

        let elapsed = startedAt.durationUntil(Instant.now())
        stopwatch.record(name, elapsed)
        finished = true
        finishedDuration = elapsed
        return elapsed
    }

    destructor {
        this.finish()
    }
}

function missingTimer(name: string): TimerError {
    return TimerError {
        kind: "MissingTimer",
        name,
        message: "No timings recorded for '${name}'",
    }
}
