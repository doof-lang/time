import { Assert } from "std/assert"
import { Date, DateTime, Duration, Instant, Time, TimeZone, Month, DayOfWeek } from "../index"

export function testReadmeMeasureElapsedTimeAndDeadlines(): void {
    let startedAt = Instant.ofEpochSeconds(1_000L)
    let timeout = Duration.ofSeconds(30L)
    let deadline = startedAt.plus(timeout)

    let pollInterval = Duration.ofMillis(250L)
    let maxPolls = timeout.toMillis() \ pollInterval.toMillis()

    Assert.equal(deadline.toEpochSeconds(), 1_030L)
    Assert.equal(timeout.toISOString(), "PT0H0M30S")
    Assert.equal(pollInterval.toMillis(), 250L)
    Assert.equal(maxPolls, 120L)
}

export function testReadmeBuildCalendarValuesAndMoveThemAroundSafely(): void {
    let payrollDate = try! Date.create(2024, Month.January.value, 31)
    let nextPayrollDate = payrollDate.plusMonths(1)

    let standup = try! Time.create(9, 45)
    let reminderTime = standup.plusMinutes(20)

    let releaseWindow = DateTime.create(nextPayrollDate, reminderTime)

    Assert.equal(payrollDate.dayOfWeek(), DayOfWeek.Wednesday)
    Assert.equal(nextPayrollDate.toISOString(), "2024-02-29")
    Assert.equal(releaseWindow.toISOString(), "2024-02-29T10:05:00")
}

export function testReadmeConvertTheSameMeetingBetweenTimeZones(): void {
    let newYork = try! TimeZone.lookup("America/New_York")
    let london = try! TimeZone.lookup("Europe/London")
    let tokyo = try! TimeZone.lookup("Asia/Tokyo")

    let meetingLocal = try! DateTime.fromParts(2024, 10, 4, 9, 30)
    let meetingInNewYork = meetingLocal.atZone(newYork)

    let sameInstantInLondon = meetingInNewYork.withZoneSameInstant(london)
    let sameWallClockInTokyo = meetingInNewYork.withZoneSameLocal(tokyo)

    Assert.equal(meetingInNewYork.toISOString(), "2024-10-04T09:30:00-04:00")
    Assert.equal(sameInstantInLondon.toISOString(), "2024-10-04T14:30:00+01:00")
    Assert.equal(sameWallClockInTokyo.toISOString(), "2024-10-04T09:30:00+09:00")
}

export function testReadmeParseInputAndInspectTimezoneRules(): void {
    let launchDate = try! Date.parse("2026-04-21")
    let publishedAt = try! Instant.parse("2026-04-21T14:00:00Z")
    let reviewSlot = try! DateTime.parse("2026-04-21T16:30:00")

    let sydney = try! TimeZone.lookup("Australia/Sydney")
    let offsetSeconds = sydney.offsetSecondsAt(publishedAt)

    Assert.equal(launchDate.dayOfYear(), 111)
    Assert.equal(reviewSlot.toInstant(sydney).toISOString(), "2026-04-21T06:30:00Z")
    Assert.equal(offsetSeconds, 36000)
    Assert.isFalse(sydney.isDSTAt(publishedAt))
}