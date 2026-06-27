// std/time.test.do

import { Assert } from "std/assert"
import {
    Duration, Thread, Instant, Date, Time, DateTime, TimeZone, ZonedDateTime,
    DayOfWeek, Month, Stopwatch, TimerError
} from "../index"

function isSuccess<T, E>(result: Result<T, E>): bool {
    return case result {
        _: Success -> true,
        _: Failure -> false
    }
}

function isFailure<T, E>(result: Result<T, E>): bool {
    return case result {
        _: Success -> false,
        _: Failure -> true
    }
}

function assertTimerFailure(result: Result<Duration, TimerError>, name: string): void {
    case result {
        s: Success -> Assert.fail("expected timer lookup to fail")
        f: Failure -> {
            Assert.equal(f.error.kind, "MissingTimer")
            Assert.equal(f.error.name, name)
            Assert.stringContains(f.error.message, name)
        }
    }
}

// ─── Duration ────────────────────────────────────────────────────────────────

export function testDurationOfUnits(): void {
    Assert.equal(Duration.ofSeconds(1L).toMillis(), 1000L)
    Assert.equal(Duration.ofMinutes(2L).toSeconds(), 120.0)
    Assert.equal(Duration.ofHours(1L).toMinutes(), 60.0)
    Assert.equal(Duration.ofDays(1L).toHours(), 24.0)
    Assert.equal(Duration.ofMillis(500L).toNanos(), 500000000L)
}

export function testDurationFractionalUnits(): void {
    Assert.equal(Duration.ofMillis(500L).toSeconds(), 0.5)
    Assert.equal(Duration.ofSeconds(90L).toMinutes(), 1.5)
    Assert.equal(Duration.ofMinutes(90L).toHours(), 1.5)
    Assert.equal(Duration.ofHours(36L).toDays(), 1.5)
}

export function testDurationArithmetic(): void {
    let a = Duration.ofSeconds(10L)
    let b = Duration.ofSeconds(3L)
    Assert.equal(a.plus(b).toSeconds(), 13.0)
    Assert.equal(a.minus(b).toSeconds(), 7.0)
    Assert.equal(a.multipliedBy(3L).toSeconds(), 30.0)
    Assert.equal(a.dividedBy(2L).toSeconds(), 5.0)
}

export function testDurationNegated(): void {
    let d = Duration.ofSeconds(5L)
    Assert.isTrue(d.negated().isNegative())
    Assert.equal(d.negated().abs().toSeconds(), 5.0)
}

export function testDurationZero(): void {
    Assert.isTrue(Duration.ZERO.isZero())
    Assert.isFalse(Duration.ofSeconds(1L).isZero())
}

export function testDurationCompareTo(): void {
    let short = Duration.ofSeconds(1L)
    let long_ = Duration.ofSeconds(5L)
    Assert.isTrue(short.isLessThan(long_))
    Assert.isTrue(long_.isGreaterThan(short))
    Assert.isTrue(short.equals(Duration.ofMillis(1000L)))
}

export function testDurationISOString(): void {
    Assert.equal(Duration.ofHours(3L).plus(Duration.ofMinutes(25L)).plus(Duration.ofSeconds(10L)).toISOString(), "PT3H25M10S")
    Assert.equal(Duration.ofSeconds(5L).negated().toISOString(), "-PT5S")
    Assert.equal(Duration.ofMillis(250L).toISOString(), "PT0.25S")
    Assert.equal(Duration.ofDays(2L).plus(Duration.ofHours(3L)).toISOString(), "P2DT3H")
    Assert.equal(Duration.ZERO.toISOString(), "PT0S")
}

export function testDurationParse(): void {
    Assert.equal((try! Duration.parse("PT5S")).toNanos(), Duration.ofSeconds(5L).toNanos())
    Assert.equal((try! Duration.parse("-PT5S")).toNanos(), Duration.ofSeconds(5L).negated().toNanos())
    Assert.equal((try! Duration.parse("PT0.25S")).toNanos(), Duration.ofMillis(250L).toNanos())
    Assert.equal((try! Duration.parse("P2DT3H4M5.006S")).toNanos(),
        Duration.ofDays(2L).plus(Duration.ofHours(3L)).plus(Duration.ofMinutes(4L)).plus(Duration.ofSeconds(5L)).plus(Duration.ofMillis(6L)).toNanos())
    Assert.equal((try! Duration.parse("PT0S")).toNanos(), Duration.ZERO.toNanos())
}

export function testDurationParseRejectsInvalidFormats(): void {
    Assert.isTrue(isFailure(Duration.parse("")))
    Assert.isTrue(isFailure(Duration.parse("P")))
    Assert.isTrue(isFailure(Duration.parse("PT")))
    Assert.isTrue(isFailure(Duration.parse("P1M")))
    Assert.isTrue(isFailure(Duration.parse("PT1M2H")))
    Assert.isTrue(isFailure(Duration.parse("PT1.0000000000S")))
    Assert.isTrue(isFailure(Duration.parse("PT1.S")))
}

// ─── Thread ──────────────────────────────────────────────────────────────────

export function testThreadSleepZeroAndNegativeDurationsReturn(): void {
    Thread.sleep(Duration.ZERO)
    Thread.sleep(Duration.ofMillis(1L).negated())
    Assert.isTrue(true)
}

export function testThreadSleepDelaysCurrentThread(): void {
    let startedAt = Instant.now()
    Thread.sleep(Duration.ofMillis(5L))
    let elapsed = startedAt.durationUntil(Instant.now())
    Assert.isTrue(elapsed.toMillis() >= 1L)
}

// ─── Stopwatch ───────────────────────────────────────────────────────────────

export function testStopwatchMissingTimer(): void {
    let sw = Stopwatch()

    Assert.equal(sw.count("missing"), 0)
    assertTimerFailure(sw.total("missing"), "missing")
    assertTimerFailure(sw.mean("missing"), "missing")
    assertTimerFailure(sw.min("missing"), "missing")
    assertTimerFailure(sw.max("missing"), "missing")
    assertTimerFailure(sw.p95("missing"), "missing")
}

export function testStopwatchManualFinishRecordsOnce(): void {
    let sw = Stopwatch()
    let span = sw.measure("manual")

    Thread.sleep(Duration.ofMillis(1L))
    let first = span.finish()
    let second = span.finish()

    Assert.equal(sw.count("manual"), 1)
    Assert.equal(first.toNanos(), second.toNanos())
    Assert.equal((try! sw.total("manual")).toNanos(), first.toNanos())
}

export function testStopwatchScopedMeasureRecordsOnExit(): void {
    let sw = Stopwatch()

    with span := sw.measure("scoped") {
        Thread.sleep(Duration.ofMillis(1L))
    }

    Assert.equal(sw.count("scoped"), 1)
    Assert.isTrue((try! sw.total("scoped")).toNanos() >= 0L)
}

export function testStopwatchAggregatesAndP95(): void {
    let sw = Stopwatch()

    first := sw.measure("task")
    Thread.sleep(Duration.ofMillis(1L))
    let firstDuration = first.finish()

    second := sw.measure("task")
    Thread.sleep(Duration.ofMillis(2L))
    let secondDuration = second.finish()

    let total = try! sw.total("task")
    let mean = try! sw.mean("task")
    let min = try! sw.min("task")
    let max = try! sw.max("task")
    let p95 = try! sw.p95("task")

    Assert.equal(sw.count("task"), 2)
    Assert.equal(total.toNanos(), firstDuration.toNanos() + secondDuration.toNanos())
    Assert.equal(mean.toNanos(), total.toNanos() \ 2L)
    Assert.isTrue(min.toNanos() <= max.toNanos())
    Assert.equal(p95.toNanos(), max.toNanos())
}

export function testStopwatchSummary(): void {
    let sw = Stopwatch()

    a := sw.measure("parse")
    Thread.sleep(Duration.ofMillis(1L))
    let parseDuration = a.finish()

    b := sw.measure("render")
    Thread.sleep(Duration.ofMillis(1L))
    let renderDuration = b.finish()

    let summary = sw.summary()

    Assert.equal(summary.entries.length, 2)
    Assert.equal(summary.entries[0].name, "parse")
    Assert.equal(summary.entries[0].count, 1)
    Assert.equal(summary.entries[0].total.toNanos(), parseDuration.toNanos())
    Assert.equal(summary.entries[1].name, "render")
    Assert.equal(summary.entries[1].count, 1)
    Assert.equal(summary.entries[1].total.toNanos(), renderDuration.toNanos())
}

// ─── Instant ─────────────────────────────────────────────────────────────────

export function testInstantEpoch(): void {
    Assert.equal(Instant.EPOCH.toEpochSeconds(), 0L)
    Assert.equal(Instant.EPOCH.toEpochMillis(), 0L)
    Assert.equal(Instant.EPOCH.toEpochNanos(), 0L)
}

export function testInstantPlusMinus(): void {
    let base = Instant.ofEpochSeconds(1000L)
    let later = base.plus(Duration.ofSeconds(500L))
    Assert.equal(later.toEpochSeconds(), 1500L)

    let earlier = base.minus(Duration.ofSeconds(200L))
    Assert.equal(earlier.toEpochSeconds(), 800L)
}

export function testInstantDuration(): void {
    let a = Instant.ofEpochSeconds(100L)
    let b = Instant.ofEpochSeconds(300L)
    Assert.equal(a.durationUntil(b).toSeconds(), 200.0)
    Assert.equal(b.durationSince(a).toSeconds(), 200.0)
}

export function testInstantComparison(): void {
    let a = Instant.ofEpochMillis(1000L)
    let b = Instant.ofEpochMillis(2000L)
    Assert.isTrue(a.isBefore(b))
    Assert.isTrue(b.isAfter(a))
    Assert.isFalse(a.isAfter(b))
    Assert.isTrue(a.equals(Instant.ofEpochMillis(1000L)))
}

export function testInstantParse(): void {
    let result = Instant.parse("1970-01-01T00:00:00Z")
    Assert.isTrue(isSuccess(result))
    let instant = try! result
    Assert.equal(instant.toEpochSeconds(), 0L)
}

export function testInstantHttpDateFormatting(): void {
    Assert.equal(Instant.EPOCH.toHttpDate(), "Thu, 01 Jan 1970 00:00:00 GMT")
    Assert.equal(Instant.ofEpochSeconds(784111777L).toHttpDate(), "Sun, 06 Nov 1994 08:49:37 GMT")
}

export function testInstantHttpDateParsing(): void {
    instant := try! Instant.parseHttpDate("Sun, 06 Nov 1994 08:49:37 GMT")

    Assert.equal(instant.toEpochSeconds(), 784111777L)
}

export function testInstantHttpDateParsingRejectsInvalidValues(): void {
    Assert.isTrue(isFailure(Instant.parseHttpDate("Sun, 06 Foo 1994 08:49:37 GMT")))
    Assert.isTrue(isFailure(Instant.parseHttpDate("Sun, 06 Nov 1994 08:49:60 GMT")))
    Assert.isTrue(isFailure(Instant.parseHttpDate("1994-11-06T08:49:37Z")))
}

export function testInstantNow(): void {
    let before = Instant.ofEpochSeconds(0L)
    let now = Instant.now()
    Assert.isTrue(now.isAfter(before))
}

// ─── Date ────────────────────────────────────────────────────────────────────

export function testDateOf(): void {
    let d = try! Date.create(2024, 6, 1)
    Assert.equal(d.year, 2024)
    Assert.equal(d.month, 6)
    Assert.equal(d.day, 1)
}

export function testDateInvalid(): void {
    Assert.isTrue(isFailure(Date.create(2024, 13, 1)))   // month out of range
    Assert.isTrue(isFailure(Date.create(2024, 2, 30)))   // day out of range for Feb
    Assert.isTrue(isFailure(Date.create(2024, 0, 1)))    // month zero
}

export function testDateLeapYear(): void {
    let leap = try! Date.create(2024, 1, 1)
    Assert.isTrue(leap.isLeapYear())
    let nonLeap = try! Date.create(2023, 1, 1)
    Assert.isFalse(nonLeap.isLeapYear())
    // 2000 is a leap year (divisible by 400)
    Assert.isTrue((try! Date.create(2000, 1, 1)).isLeapYear())
    // 1900 is not (divisible by 100, not 400)
    Assert.isFalse((try! Date.create(1900, 1, 1)).isLeapYear())
}

export function testDatePlusDays(): void {
    let d = try! Date.create(2024, 1, 30)
    let next = d.plusDays(3)
    Assert.equal(next.month, 2)
    Assert.equal(next.day, 2)
}

export function testDatePlusMonths(): void {
    let d = try! Date.create(2024, 1, 31)
    // Jan 31 + 1 month = Feb 29 (2024 is a leap year, clamps to last valid day)
    let next = d.plusMonths(1)
    Assert.equal(next.month, 2)
    Assert.equal(next.day, 29)
}

export function testDateDaysUntil(): void {
    let a = try! Date.create(2024, 1, 1)
    let b = try! Date.create(2024, 1, 11)
    Assert.equal(a.daysUntil(b), 10)
    Assert.equal(b.daysUntil(a), -10)
}

export function testDateComparison(): void {
    let earlier = try! Date.create(2023, 12, 31)
    let later = try! Date.create(2024, 1, 1)
    Assert.isTrue(earlier.isBefore(later))
    Assert.isTrue(later.isAfter(earlier))
    Assert.isTrue(earlier.equals(try! Date.create(2023, 12, 31)))
}

export function testDateDayOfWeek(): void {
    // 2024-01-01 is a Monday
    let d = try! Date.create(2024, 1, 1)
    Assert.equal(d.dayOfWeek(), DayOfWeek.Monday)
}

export function testDateISOString(): void {
    let d = try! Date.create(2024, 6, 1)
    Assert.equal(d.toISOString(), "2024-06-01")
    let padded = try! Date.create(9, 1, 5)
    Assert.equal(padded.toISOString(), "0009-01-05")
}

export function testDateParse(): void {
    let d = try! Date.parse("2024-06-01")
    Assert.equal(d.year, 2024)
    Assert.equal(d.month, 6)
    Assert.equal(d.day, 1)
    Assert.isTrue(isFailure(Date.parse("not-a-date")))
}

// ─── Time ────────────────────────────────────────────────────────────────────

export function testTimeOf(): void {
    let t = try! Time.create(12, 30, 45, 0)
    Assert.equal(t.hour, 12)
    Assert.equal(t.minute, 30)
    Assert.equal(t.second, 45)
    Assert.equal(t.nanosecond, 0)
}

export function testTimeInvalid(): void {
    Assert.isTrue(isFailure(Time.create(24, 0)))    // hour out of range
    Assert.isTrue(isFailure(Time.create(0, 60)))    // minute out of range
    Assert.isTrue(isFailure(Time.create(0, 0, 60))) // second out of range
}

export function testTimePlusHours(): void {
    let t = try! Time.create(23, 0)
    // wraps around midnight
    let next = t.plusHours(2)
    Assert.equal(next.hour, 1)
}

export function testTimeISOString(): void {
    Assert.equal(Time.MIDNIGHT.toISOString(), "00:00:00")
    Assert.equal(Time.NOON.toISOString(), "12:00:00")
    let withNanos = try! Time.create(9, 5, 3, 500000000)
    Assert.equal(withNanos.toISOString(), "09:05:03.5")
}

export function testTimeParse(): void {
    let t = try! Time.parse("14:30:00")
    Assert.equal(t.hour, 14)
    Assert.equal(t.minute, 30)
    Assert.equal(t.second, 0)
}

// ─── DateTime ────────────────────────────────────────────────────────────────

export function testDateTimeOf(): void {
    let dt = try! DateTime.fromParts(2024, 6, 1, 12, 30)
    Assert.equal(dt.date.year, 2024)
    Assert.equal(dt.time.hour, 12)
    Assert.equal(dt.time.minute, 30)
}

export function testDateTimePlusDays(): void {
    let dt = try! DateTime.fromParts(2024, 1, 31, 23, 0)
    let next = dt.plusDays(1)
    Assert.equal(next.date.month, 2)
    Assert.equal(next.date.day, 1)
    Assert.equal(next.time.hour, 23)
}

export function testDateTimePlusHours(): void {
    // Crossing a day boundary
    let dt = try! DateTime.fromParts(2024, 6, 1, 23, 0)
    let next = dt.plusHours(2)
    Assert.equal(next.date.day, 2)
    Assert.equal(next.time.hour, 1)
}

export function testDateTimeRoundTripUTC(): void {
    let dt = try! DateTime.fromParts(2024, 6, 1, 12, 0)
    let instant = dt.toInstantUTC()
    let back = instant.toDateTime()
    Assert.isTrue(back.equals(dt))
}

export function testDateTimeISOString(): void {
    let dt = try! DateTime.fromParts(2024, 6, 1, 9, 5, 3)
    Assert.equal(dt.toISOString(), "2024-06-01T09:05:03")
}

export function testDateTimeParse(): void {
    let dt = try! DateTime.parse("2024-06-01T12:30:00")
    Assert.equal(dt.date.year, 2024)
    Assert.equal(dt.time.hour, 12)
}

// ─── TimeZone & ZonedDateTime ─────────────────────────────────────────────────

export function testTimeZoneUTC(): void {
    let utc = TimeZone.UTC
    Assert.equal(utc.id, "UTC")
    let offset = utc.offsetSecondsAt(Instant.EPOCH)
    Assert.equal(offset, 0)
}

export function testTimeZoneLookupInvalid(): void {
    Assert.isTrue(isFailure(TimeZone.lookup("Not/AZone")))
}

export function testZonedDateTimeNowUTC(): void {
    let zdt = ZonedDateTime.nowUTC()
    Assert.equal(zdt.zone.id, "UTC")
}

export function testZonedDateTimeConvertZones(): void {
    let utcZone = TimeZone.UTC
    let sydneyZone = try! TimeZone.lookup("Australia/Sydney")

    let dt = try! DateTime.fromParts(2024, 6, 1, 0, 0)
    let utcZdt = ZonedDateTime { dateTime: dt, zone: utcZone }
    let sydneyZdt = utcZdt.withZoneSameInstant(sydneyZone)

    // Sydney is UTC+10 in winter (AEST), so midnight UTC = 10:00 Sydney
    Assert.equal(sydneyZdt.time().hour, 10)
    // Same instant
    Assert.isTrue(utcZdt.toInstant().equals(sydneyZdt.toInstant()))
}

export function testZonedDateTimeISOString(): void {
    let utcZone = TimeZone.UTC
    let dt = try! DateTime.fromParts(2024, 6, 1, 12, 0)
    let zdt = ZonedDateTime { dateTime: dt, zone: utcZone }
    Assert.equal(zdt.toISOString(), "2024-06-01T12:00:00Z")
}

// ─── DayOfWeek & Month enums ─────────────────────────────────────────────────

export function testDayOfWeekValues(): void {
    Assert.equal(DayOfWeek.Monday.value, 1)
    Assert.equal(DayOfWeek.Sunday.value, 7)
}

export function testMonthValues(): void {
    Assert.equal(Month.January.value, 1)
    Assert.equal(Month.December.value, 12)
}
