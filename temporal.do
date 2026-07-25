import { parseInt } from "std/parse"

import { Duration } from "./duration"

export class Instant "A point in UTC time with nanosecond precision." {
    // Nanoseconds since Unix epoch (1970-01-01T00:00:00Z).
    // Negative values represent instants before the epoch.
    private readonly epochNanos: long

    // ââ Static constructors ââââââââââââââââââââââââââââââââââââââââââââââââââ

    // Returns the current instant using the system clock.
    static now(): Instant {
        return Instant { epochNanos: _systemNanosEpoch() }
    }

    static ofEpochNanos(nanos: long): Instant => Instant { epochNanos: nanos }
    static ofEpochMillis(ms: long): Instant => Instant { epochNanos: ms * 1000000L }
    static ofEpochSeconds(s: long): Instant => Instant { epochNanos: s * 1000000000L }

    // Parses an RFC 3339 / ISO 8601 UTC string, e.g. "2024-06-01T12:00:00Z"
    static parse(s: string): Result<Instant, string> {
        return _parseInstant(s)
    }

    static readonly EPOCH = Instant { epochNanos: 0L }

    // ââ Accessors ââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââ

    toEpochNanos(): long => epochNanos
    toEpochMillis(): long => epochNanos \ 1000000L
    toEpochSeconds(): long => epochNanos \ 1000000000L

    // ââ Arithmetic âââââââââââââââââââââââââââââââââââââââââââââââââââââââââââ

    plus(d: Duration): Instant => Instant { epochNanos: epochNanos + d.toNanos() }
    minus(d: Duration): Instant => Instant { epochNanos: epochNanos - d.toNanos() }
    durationUntil(other: Instant): Duration => Duration.ofNanos(other.epochNanos - epochNanos)
    durationSince(other: Instant): Duration => Duration.ofNanos(epochNanos - other.epochNanos)

    // ââ Comparison âââââââââââââââââââââââââââââââââââââââââââââââââââââââââââ

    compareTo(other: Instant): int {
        if epochNanos < other.epochNanos { return -1 }
        if epochNanos > other.epochNanos { return 1 }
        return 0
    }

    isBefore(other: Instant): bool => epochNanos < other.epochNanos
    isAfter(other: Instant): bool => epochNanos > other.epochNanos
    equals(other: Instant): bool => epochNanos == other.epochNanos

    // ââ Conversion âââââââââââââââââââââââââââââââââââââââââââââââââââââââââââ

    toDateTime(): DateTime => _instantToDateTime(epochNanos)
    toZonedDateTime(zone: TimeZone): ZonedDateTime => _instantToZonedDateTime(epochNanos, zone)

    // ââ Formatting âââââââââââââââââââââââââââââââââââââââââââââââââââââââââââ

    // Returns ISO 8601 UTC string, e.g. "2024-06-01T12:00:00.123456789Z"
    toISOString(): string => _formatInstant(epochNanos)

    // Parses an HTTP IMF-fixdate string, e.g. "Thu, 01 Jan 1970 00:00:00 GMT".
    static parseHttpDate(s: string): Result<Instant, string> {
        if s.length != 29 {
            return Failure { error: "HTTP date must use IMF-fixdate format" }
        }
        if s.substring(3, 5) != ", " || s.charAt(7) != ' ' || s.charAt(11) != ' ' ||
           s.charAt(16) != ' ' || s.charAt(19) != ':' || s.charAt(22) != ':' ||
           s.slice(25) != " GMT" {
            return Failure { error: "HTTP date must use IMF-fixdate format" }
        }

        day := try? parseInt(s.substring(5, 7)) else {
            return Failure { error: "HTTP date day is invalid" }
        }
        month := httpMonthNumber(s.substring(8, 11)) else {
            return Failure { error: "HTTP date month is invalid" }
        }
        year := try? parseInt(s.substring(12, 16)) else {
            return Failure { error: "HTTP date year is invalid" }
        }
        hour := try? parseInt(s.substring(17, 19)) else {
            return Failure { error: "HTTP date hour is invalid" }
        }
        minute := try? parseInt(s.substring(20, 22)) else {
            return Failure { error: "HTTP date minute is invalid" }
        }
        second := try? parseInt(s.substring(23, 25)) else {
            return Failure { error: "HTTP date second is invalid" }
        }
        try date := Date.create(year, month, day)
        try time := Time.create(hour, minute, second)
        return Success { value: DateTime.create(date, time).toInstantUTC() }
    }

    // Returns an HTTP IMF-fixdate string, e.g. "Thu, 01 Jan 1970 00:00:00 GMT".
    toHttpDate(): string {
        dateTime := this.toDateTime()
        return "${httpWeekdayName(dateTime.date.dayOfWeek())}, ${string(dateTime.date.day).padStart(2, '0')} ${httpMonthName(dateTime.date.month)} ${string(dateTime.date.year).padStart(4, '0')} ${string(dateTime.time.hour).padStart(2, '0')}:${string(dateTime.time.minute).padStart(2, '0')}:${string(dateTime.time.second).padStart(2, '0')} GMT"
    }
}

export class Date "A calendar date (year, month, day) with no time-of-day or timezone." {
    readonly year: int
    readonly month: int   // 1-12
    readonly day: int     // 1-31

    // ââ Static constructors ââââââââââââââââââââââââââââââââââââââââââââââââââ

    static create(year: int, month: int, day: int): Result<Date, string> {
        return _validateDate(year, month, day)
    }

    // Returns today's date in UTC.
    static todayUTC(): Date => _systemDateUTC()

    // Returns today's date in the given timezone.
    static today(zone: TimeZone): Date => _systemDateInZone(zone)

    // Parses an ISO 8601 date string, e.g. "2024-06-01"
    static parse(s: string): Result<Date, string> {
        return _parseDate(s)
    }

    static readonly MIN = Date { year: 1, month: 1, day: 1 }
    static readonly MAX = Date { year: 9999, month: 12, day: 31 }

    // ââ Derived properties âââââââââââââââââââââââââââââââââââââââââââââââââââ

    dayOfWeek(): DayOfWeek => _dateToDayOfWeek(year, month, day)
    dayOfYear(): int => _dateToDayOfYear(year, month, day)
    isLeapYear(): bool => _isLeapYear(year)
    daysInMonth(): int => _daysInMonth(year, month)

    // ââ Arithmetic âââââââââââââââââââââââââââââââââââââââââââââââââââââââââââ

    plusDays(n: int): Date => _dateAddDays(year, month, day, n)
    minusDays(n: int): Date => _dateAddDays(year, month, day, -n)
    plusMonths(n: int): Date => _dateAddMonths(year, month, day, n)
    minusMonths(n: int): Date => _dateAddMonths(year, month, day, -n)
    plusYears(n: int): Date => _dateAddYears(year, month, day, n)
    minusYears(n: int): Date => _dateAddYears(year, month, day, -n)

    // Returns the number of days from this date to the other (may be negative).
    daysUntil(other: Date): int => _dateDiff(year, month, day, other.year, other.month, other.day)

    // ââ Comparison âââââââââââââââââââââââââââââââââââââââââââââââââââââââââââ

    compareTo(other: Date): int {
        if year != other.year { return if year < other.year then -1 else 1 }
        if month != other.month { return if month < other.month then -1 else 1 }
        if day != other.day { return if day < other.day then -1 else 1 }
        return 0
    }

    isBefore(other: Date): bool => this.compareTo(other) < 0
    isAfter(other: Date): bool => this.compareTo(other) > 0
    equals(other: Date): bool => year == other.year && month == other.month && day == other.day

    // ââ Formatting âââââââââââââââââââââââââââââââââââââââââââââââââââââââââââ

    // Returns ISO 8601 date string, e.g. "2024-06-01"
    toISOString(): string =>
        "${string(year).padStart(4, '0')}-${string(month).padStart(2, '0')}-${string(day).padStart(2, '0')}"
}

export class Time "A time-of-day with nanosecond precision. No date or timezone." {
    readonly hour: int         // 0-23
    readonly minute: int       // 0-59
    readonly second: int       // 0-59
    readonly nanosecond: int   // 0-999_999_999

    // ââ Static constructors ââââââââââââââââââââââââââââââââââââââââââââââââââ

    static create(hour: int, minute: int, second: int = 0, nanosecond: int = 0): Result<Time, string> {
        return _validateTime(hour, minute, second, nanosecond)
    }

    // Parses "HH:MM", "HH:MM:SS", or "HH:MM:SS.nnnnnnnnn"
    static parse(s: string): Result<Time, string> {
        return _parseTime(s)
    }

    static readonly MIDNIGHT = Time { hour: 0, minute: 0, second: 0, nanosecond: 0 }
    static readonly NOON = Time { hour: 12, minute: 0, second: 0, nanosecond: 0 }

    // ââ Arithmetic âââââââââââââââââââââââââââââââââââââââââââââââââââââââââââ

    plusHours(n: int): Time => _timeAddNanos(hour, minute, second, nanosecond, long(n) * 3600000000000L)
    plusMinutes(n: int): Time => _timeAddNanos(hour, minute, second, nanosecond, long(n) * 60000000000L)
    plusSeconds(n: int): Time => _timeAddNanos(hour, minute, second, nanosecond, long(n) * 1000000000L)
    plusNanos(n: long): Time => _timeAddNanos(hour, minute, second, nanosecond, n)

    // ââ Comparison âââââââââââââââââââââââââââââââââââââââââââââââââââââââââââ

    compareTo(other: Time): int {
        if hour != other.hour { return if hour < other.hour then -1 else 1 }
        if minute != other.minute { return if minute < other.minute then -1 else 1 }
        if second != other.second { return if second < other.second then -1 else 1 }
        if nanosecond != other.nanosecond { return if nanosecond < other.nanosecond then -1 else 1 }
        return 0
    }

    isBefore(other: Time): bool => this.compareTo(other) < 0
    isAfter(other: Time): bool => this.compareTo(other) > 0
    equals(other: Time): bool =>
        hour == other.hour && minute == other.minute &&
        second == other.second && nanosecond == other.nanosecond

    // ââ Formatting âââââââââââââââââââââââââââââââââââââââââââââââââââââââââââ

    // Returns "HH:MM:SS" or "HH:MM:SS.nnnnnnnnn" (trailing zeros trimmed)
    toISOString(): string {
        let base = "${string(hour).padStart(2, '0')}:${string(minute).padStart(2, '0')}:${string(second).padStart(2, '0')}"
        if nanosecond == 0 { return base }
        return "${base}.${string(nanosecond).padStart(9, '0').trimEnd('0')}"
    }
}

export class DateTime "A combined calendar date and time-of-day. No timezone." {
    readonly date: Date
    readonly time: Time

    // ââ Static constructors ââââââââââââââââââââââââââââââââââââââââââââââââââ

    static create(date: Date, time: Time): DateTime => DateTime { date, time }

    static fromParts(
        year: int, month: int, day: int,
        hour: int, minute: int, second: int = 0, nanosecond: int = 0
    ): Result<DateTime, string> {
        try d := Date.create(year, month, day)
        try t := Time.create(hour, minute, second, nanosecond)
        return Success { value: DateTime { date: d, time: t } }
    }

    static nowUTC(): DateTime => Instant.now().toDateTime()

    // Parses ISO 8601, e.g. "2024-06-01T12:30:00" or "2024-06-01T12:30:00.5"
    static parse(s: string): Result<DateTime, string> {
        return _parseDateTime(s)
    }

    // ââ Arithmetic âââââââââââââââââââââââââââââââââââââââââââââââââââââââââââ

    plusDays(n: int): DateTime => DateTime { date: date.plusDays(n), time }
    minusDays(n: int): DateTime => DateTime { date: date.minusDays(n), time }
    plusHours(n: int): DateTime => _dateTimePlusNanos(date, time, long(n) * 3600000000000L)
    plusMinutes(n: int): DateTime => _dateTimePlusNanos(date, time, long(n) * 60000000000L)
    plusSeconds(n: int): DateTime => _dateTimePlusNanos(date, time, long(n) * 1000000000L)
    plus(d: Duration): DateTime => _dateTimePlusNanos(date, time, d.toNanos())
    minus(d: Duration): DateTime => _dateTimePlusNanos(date, time, -d.toNanos())

    // ââ Conversion âââââââââââââââââââââââââââââââââââââââââââââââââââââââââââ

    // Interprets this DateTime as UTC and returns the corresponding Instant.
    toInstantUTC(): Instant => _dateTimeToInstant(date, time)

    // Interprets this DateTime in the given timezone and returns the corresponding Instant.
    toInstant(zone: TimeZone): Instant => _dateTimeToInstantInZone(date, time, zone)

    atZone(zone: TimeZone): ZonedDateTime => _dateTimeAtZone(this, zone)

    // ââ Comparison âââââââââââââââââââââââââââââââââââââââââââââââââââââââââââ

    compareTo(other: DateTime): int {
        let dc = date.compareTo(other.date)
        if dc != 0 { return dc }
        return time.compareTo(other.time)
    }

    isBefore(other: DateTime): bool => this.compareTo(other) < 0
    isAfter(other: DateTime): bool => this.compareTo(other) > 0
    equals(other: DateTime): bool => date.equals(other.date) && time.equals(other.time)

    // ââ Formatting âââââââââââââââââââââââââââââââââââââââââââââââââââââââââââ

    // Returns ISO 8601 string, e.g. "2024-06-01T12:30:00"
    toISOString(): string => "${date.toISOString()}T${time.toISOString()}"
}

export class TimeZone "An IANA timezone identifier (e.g. \"America/New_York\", \"UTC\")." {
    readonly id: string

    // ââ Static constructors ââââââââââââââââââââââââââââââââââââââââââââââââââ

    // Returns a timezone for the given IANA identifier, or Failure if unknown.
    static lookup(id: string): Result<TimeZone, string> => _lookupTimeZone(id)

    static readonly UTC = TimeZone { id: "UTC" }

    // Returns the system's local timezone.
    static local(): TimeZone => _systemTimeZone()

    // ââ Queries ââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââ

    // UTC offset in seconds at the given instant (accounts for DST).
    offsetSecondsAt(instant: Instant): int => _zoneOffsetAt(id, instant.toEpochSeconds())

    // Whether DST is in effect at the given instant.
    isDSTAt(instant: Instant): bool => _zoneDSTAt(id, instant.toEpochSeconds())
}

export class ZonedDateTime "A DateTime with an explicit TimeZone." {
    readonly dateTime: DateTime
    readonly zone: TimeZone

    // ââ Static constructors ââââââââââââââââââââââââââââââââââââââââââââââââââ

    static now(zone: TimeZone): ZonedDateTime => Instant.now().toZonedDateTime(zone)
    static nowUTC(): ZonedDateTime => Instant.now().toZonedDateTime(TimeZone.UTC)

    // ââ Derived properties âââââââââââââââââââââââââââââââââââââââââââââââââââ

    date(): Date => dateTime.date
    time(): Time => dateTime.time
    offsetSeconds(): int => zone.offsetSecondsAt(this.toInstant())

    // ââ Conversion âââââââââââââââââââââââââââââââââââââââââââââââââââââââââââ

    toInstant(): Instant => dateTime.toInstant(zone)
    withZoneSameInstant(newZone: TimeZone): ZonedDateTime =>
        this.toInstant().toZonedDateTime(newZone)
    withZoneSameLocal(newZone: TimeZone): ZonedDateTime =>
        ZonedDateTime { dateTime, zone: newZone }
    toDateTime(): DateTime => dateTime
    toUTC(): ZonedDateTime => this.withZoneSameInstant(TimeZone.UTC)

    // ââ Comparison âââââââââââââââââââââââââââââââââââââââââââââââââââââââââââ

    compareTo(other: ZonedDateTime): int =>
        this.toInstant().compareTo(other.toInstant())

    isBefore(other: ZonedDateTime): bool => this.toInstant().isBefore(other.toInstant())
    isAfter(other: ZonedDateTime): bool => this.toInstant().isAfter(other.toInstant())

    // ââ Formatting âââââââââââââââââââââââââââââââââââââââââââââââââââââââââââ

    // Returns ISO 8601 with offset, e.g. "2024-06-01T12:30:00+10:00" or "...Z"
    toISOString(): string {
        let offset = this.offsetSeconds()
        if offset == 0 {
            return "${dateTime.toISOString()}Z"
        }

        let sign = if offset < 0 then "-" else "+"
        let abs = if offset < 0 then -offset else offset
        let h = abs \ 3600
        let m = (abs % 3600) \ 60
        let suffix = "${sign}${string(h).padStart(2, '0')}:${string(m).padStart(2, '0')}"
        return "${dateTime.toISOString()}${suffix}"
    }
}

export enum DayOfWeek {
    Monday = 1,
    Tuesday = 2,
    Wednesday = 3,
    Thursday = 4,
    Friday = 5,
    Saturday = 6,
    Sunday = 7
}

export enum Month {
    January = 1,
    February = 2,
    March = 3,
    April = 4,
    May = 5,
    June = 6,
    July = 7,
    August = 8,
    September = 9,
    October = 10,
    November = 11,
    December = 12
}

function httpWeekdayName(day: DayOfWeek): string {
    return case day {
        DayOfWeek.Monday -> "Mon",
        DayOfWeek.Tuesday -> "Tue",
        DayOfWeek.Wednesday -> "Wed",
        DayOfWeek.Thursday -> "Thu",
        DayOfWeek.Friday -> "Fri",
        DayOfWeek.Saturday -> "Sat",
        DayOfWeek.Sunday -> "Sun",
    }
}

function httpMonthName(month: int): string {
    return case month {
        Month.January.value -> "Jan",
        Month.February.value -> "Feb",
        Month.March.value -> "Mar",
        Month.April.value -> "Apr",
        Month.May.value -> "May",
        Month.June.value -> "Jun",
        Month.July.value -> "Jul",
        Month.August.value -> "Aug",
        Month.September.value -> "Sep",
        Month.October.value -> "Oct",
        Month.November.value -> "Nov",
        Month.December.value -> "Dec",
        _ -> "Jan",
    }
}

function httpMonthNumber(text: string): int | none {
    return case text {
        "Jan" -> Month.January.value,
        "Feb" -> Month.February.value,
        "Mar" -> Month.March.value,
        "Apr" -> Month.April.value,
        "May" -> Month.May.value,
        "Jun" -> Month.June.value,
        "Jul" -> Month.July.value,
        "Aug" -> Month.August.value,
        "Sep" -> Month.September.value,
        "Oct" -> Month.October.value,
        "Nov" -> Month.November.value,
        "Dec" -> Month.December.value,
        _ -> none,
    }
}

import isolated function _systemNanosEpoch(): long from "doof_time.hpp" as doof_time::system_nanos_epoch
import isolated function _parseInstant(s: string): Result<Instant, string> from "doof_time.hpp" as doof_time::parse_instant
import isolated function _formatInstant(nanos: long): string from "doof_time.hpp" as doof_time::format_instant
import isolated function _instantToDateTime(nanos: long): DateTime from "doof_time.hpp" as doof_time::instant_to_datetime
import isolated function _instantToDateTimeInZone(nanos: long, zone: TimeZone): DateTime from "doof_time.hpp" as doof_time::instant_to_datetime_in_zone
import isolated function _instantToZonedDateTime(nanos: long, zone: TimeZone): ZonedDateTime from "doof_time.hpp" as doof_time::instant_to_zoned_datetime
import isolated function _dateTimeToInstant(date: Date, time: Time): Instant from "doof_time.hpp" as doof_time::datetime_to_instant
import isolated function _dateTimeToInstantInZone(date: Date, time: Time, zone: TimeZone): Instant from "doof_time.hpp" as doof_time::datetime_to_instant_in_zone
import isolated function _dateTimeAtZone(dateTime: DateTime, zone: TimeZone): ZonedDateTime from "doof_time.hpp" as doof_time::datetime_at_zone
import isolated function _validateDate(year: int, month: int, day: int): Result<Date, string> from "doof_time.hpp" as doof_time::validate_date
import isolated function _parseDate(s: string): Result<Date, string> from "doof_time.hpp" as doof_time::parse_date
import isolated function _systemDateUTC(): Date from "doof_time.hpp" as doof_time::system_date_utc
import isolated function _systemDateInZone(zone: TimeZone): Date from "doof_time.hpp" as doof_time::system_date_in_zone
import isolated function _validateTime(hour: int, minute: int, second: int, nanosecond: int): Result<Time, string> from "doof_time.hpp" as doof_time::validate_time
import isolated function _parseTime(s: string): Result<Time, string> from "doof_time.hpp" as doof_time::parse_time
import isolated function _parseDateTime(s: string): Result<DateTime, string> from "doof_time.hpp" as doof_time::parse_datetime
import isolated function _dateToDayOfWeek(year: int, month: int, day: int): DayOfWeek from "doof_time.hpp" as doof_time::date_to_day_of_week
import isolated function _dateToDayOfYear(year: int, month: int, day: int): int from "doof_time.hpp" as doof_time::date_to_day_of_year
import isolated function _isLeapYear(year: int): bool from "doof_time.hpp" as doof_time::is_leap_year
import isolated function _daysInMonth(year: int, month: int): int from "doof_time.hpp" as doof_time::days_in_month
import isolated function _dateAddDays(year: int, month: int, day: int, n: int): Date from "doof_time.hpp" as doof_time::date_add_days
import isolated function _dateAddMonths(year: int, month: int, day: int, n: int): Date from "doof_time.hpp" as doof_time::date_add_months
import isolated function _dateAddYears(year: int, month: int, day: int, n: int): Date from "doof_time.hpp" as doof_time::date_add_years
import isolated function _dateDiff(y1: int, m1: int, d1: int, y2: int, m2: int, d2: int): int from "doof_time.hpp" as doof_time::date_diff
import isolated function _timeAddNanos(hour: int, minute: int, second: int, nanosecond: int, nanos: long): Time from "doof_time.hpp" as doof_time::time_add_nanos
import isolated function _dateTimePlusNanos(date: Date, time: Time, nanos: long): DateTime from "doof_time.hpp" as doof_time::datetime_plus_nanos
import isolated function _lookupTimeZone(id: string): Result<TimeZone, string> from "doof_time.hpp" as doof_time::lookup_timezone
import isolated function _systemTimeZone(): TimeZone from "doof_time.hpp" as doof_time::system_timezone
import isolated function _zoneOffsetAt(id: string, epochSeconds: long): int from "doof_time.hpp" as doof_time::zone_offset_at
import isolated function _zoneDSTAt(id: string, epochSeconds: long): bool from "doof_time.hpp" as doof_time::zone_dst_at
