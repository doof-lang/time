#pragma once

#include "doof_runtime.hpp"

#include <cstdint>
#include <memory>
#include <string>

namespace std_ {
namespace time {
namespace temporal {
struct Instant;
struct Date;
struct Time;
struct DateTime;
struct TimeZone;
struct ZonedDateTime;
enum class DayOfWeek;
}  // namespace temporal
}  // namespace time
}  // namespace std_

using Instant = ::std_::time::temporal::Instant;
using Date = ::std_::time::temporal::Date;
using Time = ::std_::time::temporal::Time;
using DateTime = ::std_::time::temporal::DateTime;
using TimeZone = ::std_::time::temporal::TimeZone;
using ZonedDateTime = ::std_::time::temporal::ZonedDateTime;
using DayOfWeek = ::std_::time::temporal::DayOfWeek;

namespace doof_time {
int64_t system_nanos_epoch();
doof::Result<std::shared_ptr<Instant>, std::string> parse_instant(const std::string& text);
std::string format_instant(int64_t epoch_nanos);
std::shared_ptr<DateTime> instant_to_datetime(int64_t epoch_nanos);
std::shared_ptr<DateTime> instant_to_datetime_in_zone(int64_t epoch_nanos, std::shared_ptr<TimeZone> zone);
std::shared_ptr<ZonedDateTime> instant_to_zoned_datetime(int64_t epoch_nanos, std::shared_ptr<TimeZone> zone);
std::shared_ptr<Instant> datetime_to_instant(std::shared_ptr<Date> date, std::shared_ptr<Time> time);
std::shared_ptr<Instant> datetime_to_instant_in_zone(std::shared_ptr<Date> date, std::shared_ptr<Time> time, std::shared_ptr<TimeZone> zone);
std::shared_ptr<ZonedDateTime> datetime_at_zone(std::shared_ptr<DateTime> dateTime, std::shared_ptr<TimeZone> zone);
doof::Result<std::shared_ptr<Date>, std::string> validate_date(int32_t year, int32_t month, int32_t day);
doof::Result<std::shared_ptr<Date>, std::string> parse_date(const std::string& text);
std::shared_ptr<Date> system_date_utc();
std::shared_ptr<Date> system_date_in_zone(std::shared_ptr<TimeZone> zone);
doof::Result<std::shared_ptr<Time>, std::string> validate_time(int32_t hour, int32_t minute, int32_t second, int32_t nanosecond);
doof::Result<std::shared_ptr<Time>, std::string> parse_time(const std::string& text);
doof::Result<std::shared_ptr<DateTime>, std::string> parse_datetime(const std::string& text);
DayOfWeek date_to_day_of_week(int32_t year, int32_t month, int32_t day);
int32_t date_to_day_of_year(int32_t year, int32_t month, int32_t day);
bool is_leap_year(int32_t year);
int32_t days_in_month(int32_t year, int32_t month);
std::shared_ptr<Date> date_add_days(int32_t year, int32_t month, int32_t day, int32_t delta_days);
std::shared_ptr<Date> date_add_months(int32_t year, int32_t month, int32_t day, int32_t delta_months);
std::shared_ptr<Date> date_add_years(int32_t year, int32_t month, int32_t day, int32_t delta_years);
int32_t date_diff(int32_t year1, int32_t month1, int32_t day1, int32_t year2, int32_t month2, int32_t day2);
std::shared_ptr<Time> time_add_nanos(int32_t hour, int32_t minute, int32_t second, int32_t nanosecond, int64_t delta_nanos);
std::shared_ptr<DateTime> datetime_plus_nanos(std::shared_ptr<Date> date, std::shared_ptr<Time> time, int64_t delta_nanos);
doof::Result<std::shared_ptr<TimeZone>, std::string> lookup_timezone(const std::string& id);
std::shared_ptr<TimeZone> system_timezone();
int32_t zone_offset_at(const std::string& id, int64_t epoch_seconds);
bool zone_dst_at(const std::string& id, int64_t epoch_seconds);
void thread_sleep_nanos(int64_t nanos);

}  // namespace doof_time
