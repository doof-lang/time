#include "index.hpp"

#include <algorithm>
#include <chrono>
#include <cstdlib>
#include <cstring>
#include <ctime>
#include <limits.h>
#include <mutex>
#include <string>
#include <sys/stat.h>
#include <thread>
#include <unistd.h>

namespace doof_time {

namespace detail {

using InstantPtr = std::shared_ptr<Instant>;
using DatePtr = std::shared_ptr<Date>;
using TimePtr = std::shared_ptr<Time>;
using DateTimePtr = std::shared_ptr<DateTime>;
using TimeZonePtr = std::shared_ptr<TimeZone>;

constexpr int64_t kNanosPerSecond = 1'000'000'000LL;
constexpr int64_t kSecondsPerDay = 86'400LL;
constexpr int64_t kNanosPerDay = kSecondsPerDay * kNanosPerSecond;

int64_t floor_div(int64_t value, int64_t divisor) {
    int64_t quotient = value / divisor;
    int64_t remainder = value % divisor;
    if (remainder != 0 && ((remainder < 0) != (divisor < 0))) {
        --quotient;
    }
    return quotient;
}

int64_t floor_mod(int64_t value, int64_t divisor) {
    return value - floor_div(value, divisor) * divisor;
}

bool is_leap_year_value(int32_t year) {
    return (year % 4 == 0 && year % 100 != 0) || (year % 400 == 0);
}

int32_t days_in_month_value(int32_t year, int32_t month) {
    switch (month) {
        case 1: return 31;
        case 2: return is_leap_year_value(year) ? 29 : 28;
        case 3: return 31;
        case 4: return 30;
        case 5: return 31;
        case 6: return 30;
        case 7: return 31;
        case 8: return 31;
        case 9: return 30;
        case 10: return 31;
        case 11: return 30;
        case 12: return 31;
        default: return 0;
    }
}

bool contains_nul(const std::string& value) {
    return value.find('\0') != std::string::npos;
}

bool is_valid_zone_id(const std::string& id) {
    if (id.empty() || contains_nul(id) || id.front() == '/' || id.find("..") != std::string::npos) {
        return false;
    }
    return true;
}

bool file_exists(const std::string& path) {
    struct stat st {};
    return ::stat(path.c_str(), &st) == 0;
}

bool zone_file_exists(const std::string& id) {
    if (id == "UTC" || id == "Etc/UTC") {
        return true;
    }
    return file_exists("/usr/share/zoneinfo/" + id) || file_exists("/var/db/timezone/zoneinfo/" + id);
}

std::string trim_fractional_nanos(int32_t nanos) {
    std::string fraction = std::to_string(static_cast<int64_t>(nanos));
    while (fraction.size() < 9) {
        fraction.insert(fraction.begin(), '0');
    }
    while (!fraction.empty() && fraction.back() == '0') {
        fraction.pop_back();
    }
    return fraction;
}

bool parse_fixed_digits(const std::string& text, std::size_t offset, std::size_t length, int32_t& out) {
    if (offset + length > text.size()) {
        return false;
    }
    int32_t value = 0;
    for (std::size_t index = 0; index < length; ++index) {
        const char ch = text[offset + index];
        if (ch < '0' || ch > '9') {
            return false;
        }
        value = value * 10 + static_cast<int32_t>(ch - '0');
    }
    out = value;
    return true;
}

bool parse_fractional_nanos(const std::string& text, std::size_t offset, int32_t& nanos) {
    if (offset >= text.size()) {
        nanos = 0;
        return true;
    }
    if (text[offset] != '.') {
        return false;
    }

    ++offset;
    if (offset >= text.size()) {
        return false;
    }

    int32_t value = 0;
    int digits = 0;
    while (offset < text.size()) {
        const char ch = text[offset];
        if (ch < '0' || ch > '9') {
            return false;
        }
        if (digits == 9) {
            return false;
        }
        value = value * 10 + static_cast<int32_t>(ch - '0');
        ++digits;
        ++offset;
    }

    while (digits < 9) {
        value *= 10;
        ++digits;
    }

    nanos = value;
    return true;
}

int64_t days_from_civil(int32_t year, int32_t month, int32_t day) {
    year -= month <= 2 ? 1 : 0;
    const int32_t era = (year >= 0 ? year : year - 399) / 400;
    const uint32_t yoe = static_cast<uint32_t>(year - era * 400);
    const uint32_t moy = static_cast<uint32_t>(month > 2 ? month - 3 : month + 9);
    const uint32_t doy = (153 * moy + 2) / 5 + static_cast<uint32_t>(day - 1);
    const uint32_t doe = yoe * 365 + yoe / 4 - yoe / 100 + doy;
    return static_cast<int64_t>(era) * 146097 + static_cast<int64_t>(doe) - 719468;
}

void civil_from_days(int64_t days, int32_t& year, int32_t& month, int32_t& day) {
    days += 719468;
    const int64_t era = (days >= 0 ? days : days - 146096) / 146097;
    const uint32_t doe = static_cast<uint32_t>(days - era * 146097);
    const uint32_t yoe = (doe - doe / 1460 + doe / 36524 - doe / 146096) / 365;
    year = static_cast<int32_t>(yoe) + static_cast<int32_t>(era) * 400;
    const uint32_t doy = doe - (365 * yoe + yoe / 4 - yoe / 100);
    const uint32_t mp = (5 * doy + 2) / 153;
    day = static_cast<int32_t>(doy - (153 * mp + 2) / 5 + 1);
    month = static_cast<int32_t>(mp < 10 ? mp + 3 : mp - 9);
    year += month <= 2 ? 1 : 0;
}

DatePtr make_date(int32_t year, int32_t month, int32_t day) {
    return std::make_shared<Date>(year, month, day);
}

TimePtr make_time(int32_t hour, int32_t minute, int32_t second, int32_t nanosecond) {
    return std::make_shared<Time>(hour, minute, second, nanosecond);
}

DateTimePtr make_datetime(DatePtr date, TimePtr time) {
    return std::make_shared<DateTime>(std::move(date), std::move(time));
}

InstantPtr make_instant(int64_t epoch_nanos) {
    return std::make_shared<Instant>(epoch_nanos);
}

TimeZonePtr make_timezone(const std::string& id) {
    return std::make_shared<TimeZone>(id);
}

std::string format_two_digits(int32_t value) {
    std::string text = std::to_string(static_cast<int64_t>(value));
    if (text.size() < 2) {
        text.insert(text.begin(), '0');
    }
    return text;
}

std::string format_four_digits(int32_t value) {
    std::string text = std::to_string(static_cast<int64_t>(value));
    while (text.size() < 4) {
        text.insert(text.begin(), '0');
    }
    return text;
}

class ScopedTimeZone {
public:
    explicit ScopedTimeZone(const std::string& id)
        : hadOld_(false) {
        const char* existing = std::getenv("TZ");
        if (existing != nullptr) {
            hadOld_ = true;
            old_ = existing;
        }

        ::setenv("TZ", id.c_str(), 1);
        ::tzset();
    }

    ~ScopedTimeZone() {
        if (hadOld_) {
            ::setenv("TZ", old_.c_str(), 1);
        } else {
            ::unsetenv("TZ");
        }
        ::tzset();
    }

private:
    bool hadOld_;
    std::string old_;
};

std::mutex& timezone_mutex() {
    static std::mutex mutex;
    return mutex;
}

template <typename Func>
auto with_timezone(const std::string& id, Func&& func) -> decltype(func()) {
    std::lock_guard<std::mutex> lock(timezone_mutex());
    ScopedTimeZone scoped(id == "UTC" ? "UTC" : id);
    return func();
}

std::string current_timezone_id() {
    char buffer[PATH_MAX];
    const ssize_t count = ::readlink("/etc/localtime", buffer, sizeof(buffer) - 1);
    if (count > 0) {
        buffer[count] = '\0';
        std::string target(buffer);
        const std::size_t marker = target.find("/zoneinfo/");
        if (marker != std::string::npos) {
            const std::string id = target.substr(marker + std::strlen("/zoneinfo/"));
            if (is_valid_zone_id(id) && zone_file_exists(id)) {
                return id;
            }
        }
    }

    const char* env = std::getenv("TZ");
    if (env != nullptr) {
        std::string id(env);
        if (!id.empty() && id.front() == ':') {
            id.erase(id.begin());
        }
        if (is_valid_zone_id(id) && zone_file_exists(id)) {
            return id;
        }
    }

    return "UTC";
}

bool validate_date_parts(int32_t year, int32_t month, int32_t day, std::string& error) {
    if (year < 1 || year > 9999) {
        error = "Year out of range";
        return false;
    }
    if (month < 1 || month > 12) {
        error = "Month out of range";
        return false;
    }
    const int32_t max_day = days_in_month_value(year, month);
    if (day < 1 || day > max_day) {
        error = "Day out of range";
        return false;
    }
    return true;
}

bool validate_time_parts(int32_t hour, int32_t minute, int32_t second, int32_t nanosecond, std::string& error) {
    if (hour < 0 || hour > 23) {
        error = "Hour out of range";
        return false;
    }
    if (minute < 0 || minute > 59) {
        error = "Minute out of range";
        return false;
    }
    if (second < 0 || second > 59) {
        error = "Second out of range";
        return false;
    }
    if (nanosecond < 0 || nanosecond > 999999999) {
        error = "Nanosecond out of range";
        return false;
    }
    return true;
}

doof::Result<DatePtr, std::string> parse_date_parts(const std::string& text) {
    if (text.size() != 10 || text[4] != '-' || text[7] != '-') {
        return doof::Failure<std::string>{"Invalid date format"};
    }

    int32_t year = 0;
    int32_t month = 0;
    int32_t day = 0;
    if (!parse_fixed_digits(text, 0, 4, year) || !parse_fixed_digits(text, 5, 2, month) || !parse_fixed_digits(text, 8, 2, day)) {
        return doof::Failure<std::string>{"Invalid date format"};
    }

    std::string error;
    if (!validate_date_parts(year, month, day, error)) {
        return doof::Failure<std::string>{error};
    }

    return doof::Success<DatePtr>{make_date(year, month, day)};
}

doof::Result<TimePtr, std::string> parse_time_parts(const std::string& text) {
    if (text.size() < 5 || text[2] != ':') {
        return doof::Failure<std::string>{"Invalid time format"};
    }

    int32_t hour = 0;
    int32_t minute = 0;
    if (!parse_fixed_digits(text, 0, 2, hour) || !parse_fixed_digits(text, 3, 2, minute)) {
        return doof::Failure<std::string>{"Invalid time format"};
    }

    int32_t second = 0;
    int32_t nanosecond = 0;
    if (text.size() > 5) {
        if (text.size() < 8 || text[5] != ':') {
            return doof::Failure<std::string>{"Invalid time format"};
        }
        if (!parse_fixed_digits(text, 6, 2, second)) {
            return doof::Failure<std::string>{"Invalid time format"};
        }
        if (text.size() > 8 && !parse_fractional_nanos(text, 8, nanosecond)) {
            return doof::Failure<std::string>{"Invalid time format"};
        }
    }

    std::string error;
    if (!validate_time_parts(hour, minute, second, nanosecond, error)) {
        return doof::Failure<std::string>{error};
    }

    return doof::Success<TimePtr>{make_time(hour, minute, second, nanosecond)};
}

doof::Result<DateTimePtr, std::string> parse_datetime_parts(const std::string& text) {
    const std::size_t separator = text.find('T');
    if (separator == std::string::npos) {
        return doof::Failure<std::string>{"Invalid datetime format"};
    }

    const auto parsed_date = parse_date_parts(text.substr(0, separator));
    if (doof::is_failure(parsed_date)) {
        return doof::Failure<std::string>{doof::failure_error(parsed_date)};
    }

    const auto parsed_time = parse_time_parts(text.substr(separator + 1));
    if (doof::is_failure(parsed_time)) {
        return doof::Failure<std::string>{doof::failure_error(parsed_time)};
    }

    return doof::Success<DateTimePtr>{make_datetime(doof::success_value(parsed_date), doof::success_value(parsed_time))};
}

DatePtr add_days_to_date(int32_t year, int32_t month, int32_t day, int64_t delta_days) {
    int32_t out_year = 0;
    int32_t out_month = 0;
    int32_t out_day = 0;
    civil_from_days(days_from_civil(year, month, day) + delta_days, out_year, out_month, out_day);
    return make_date(out_year, out_month, out_day);
}

DatePtr add_months_to_date(int32_t year, int32_t month, int32_t day, int32_t delta_months) {
    const int64_t zero_based_month = static_cast<int64_t>(year) * 12 + static_cast<int64_t>(month - 1) + delta_months;
    const int32_t out_year = static_cast<int32_t>(floor_div(zero_based_month, 12));
    const int32_t out_month = static_cast<int32_t>(floor_mod(zero_based_month, 12)) + 1;
    const int32_t out_day = std::min(day, days_in_month_value(out_year, out_month));
    return make_date(out_year, out_month, out_day);
}

DatePtr add_years_to_date(int32_t year, int32_t month, int32_t day, int32_t delta_years) {
    const int32_t out_year = year + delta_years;
    const int32_t out_day = std::min(day, days_in_month_value(out_year, month));
    return make_date(out_year, month, out_day);
}

TimePtr make_time_of_day_from_nanos(int64_t total_nanos) {
    const int64_t wrapped = floor_mod(total_nanos, kNanosPerDay);
    const int32_t hour = static_cast<int32_t>(wrapped / 3'600'000'000'000LL);
    const int32_t minute = static_cast<int32_t>((wrapped % 3'600'000'000'000LL) / 60'000'000'000LL);
    const int32_t second = static_cast<int32_t>((wrapped % 60'000'000'000LL) / kNanosPerSecond);
    const int32_t nanosecond = static_cast<int32_t>(wrapped % kNanosPerSecond);
    return make_time(hour, minute, second, nanosecond);
}

DateTimePtr split_epoch_nanos_utc(int64_t epoch_nanos) {
    const int64_t epoch_seconds = floor_div(epoch_nanos, kNanosPerSecond);
    const int32_t nanosecond = static_cast<int32_t>(floor_mod(epoch_nanos, kNanosPerSecond));
    const int64_t days = floor_div(epoch_seconds, kSecondsPerDay);
    const int64_t second_of_day = floor_mod(epoch_seconds, kSecondsPerDay);

    int32_t year = 0;
    int32_t month = 0;
    int32_t day = 0;
    civil_from_days(days, year, month, day);

    const int32_t hour = static_cast<int32_t>(second_of_day / 3600);
    const int32_t minute = static_cast<int32_t>((second_of_day % 3600) / 60);
    const int32_t second = static_cast<int32_t>(second_of_day % 60);

    return make_datetime(make_date(year, month, day), make_time(hour, minute, second, nanosecond));
}

int64_t combine_datetime_utc(DatePtr date, TimePtr time) {
    const int64_t days = days_from_civil(date->year, date->month, date->day);
    const int64_t seconds = days * kSecondsPerDay
        + static_cast<int64_t>(time->hour) * 3600
        + static_cast<int64_t>(time->minute) * 60
        + static_cast<int64_t>(time->second);
    return seconds * kNanosPerSecond + static_cast<int64_t>(time->nanosecond);
}

}  // namespace detail

int64_t system_nanos_epoch() {
    const auto now = std::chrono::system_clock::now().time_since_epoch();
    return std::chrono::duration_cast<std::chrono::nanoseconds>(now).count();
}

doof::Result<std::shared_ptr<Instant>, std::string> parse_instant(const std::string& text) {
    if (text.empty() || text.back() != 'Z') {
        return doof::Failure<std::string>{"Instant must end with 'Z'"};
    }

    const auto parsed = detail::parse_datetime_parts(text.substr(0, text.size() - 1));
    if (doof::is_failure(parsed)) {
        return doof::Failure<std::string>{doof::failure_error(parsed)};
    }

    return doof::Success<std::shared_ptr<Instant>>{detail::make_instant(detail::combine_datetime_utc(doof::success_value(parsed)->date, doof::success_value(parsed)->time))};
}

std::string format_instant(int64_t epoch_nanos) {
    const auto datetime = detail::split_epoch_nanos_utc(epoch_nanos);
    std::string text =
        detail::format_four_digits(datetime->date->year) + "-" +
        detail::format_two_digits(datetime->date->month) + "-" +
        detail::format_two_digits(datetime->date->day) + "T" +
        detail::format_two_digits(datetime->time->hour) + ":" +
        detail::format_two_digits(datetime->time->minute) + ":" +
        detail::format_two_digits(datetime->time->second);
    if (datetime->time->nanosecond != 0) {
        text += "." + detail::trim_fractional_nanos(datetime->time->nanosecond);
    }
    text += "Z";
    return text;
}

std::shared_ptr<DateTime> instant_to_datetime(int64_t epoch_nanos) {
    return detail::split_epoch_nanos_utc(epoch_nanos);
}

std::shared_ptr<DateTime> instant_to_datetime_in_zone(int64_t epoch_nanos, std::shared_ptr<TimeZone> zone) {
    if (zone->id == "UTC") {
        return instant_to_datetime(epoch_nanos);
    }

    const int64_t epoch_seconds = detail::floor_div(epoch_nanos, detail::kNanosPerSecond);
    const int32_t nanosecond = static_cast<int32_t>(detail::floor_mod(epoch_nanos, detail::kNanosPerSecond));

    return detail::with_timezone(zone->id, [&]() {
        std::time_t raw = static_cast<std::time_t>(epoch_seconds);
        std::tm local_tm {};
        if (::localtime_r(&raw, &local_tm) == nullptr) {
            doof::panic("Failed to convert instant to local datetime");
        }

        auto date = detail::make_date(local_tm.tm_year + 1900, local_tm.tm_mon + 1, local_tm.tm_mday);
        auto time = detail::make_time(local_tm.tm_hour, local_tm.tm_min, local_tm.tm_sec, nanosecond);
        return detail::make_datetime(date, time);
    });
}

std::shared_ptr<ZonedDateTime> instant_to_zoned_datetime(int64_t epoch_nanos, std::shared_ptr<TimeZone> zone) {
    return std::make_shared<ZonedDateTime>(instant_to_datetime_in_zone(epoch_nanos, zone), zone);
}

std::shared_ptr<Instant> datetime_to_instant(std::shared_ptr<Date> date, std::shared_ptr<Time> time) {
    return detail::make_instant(detail::combine_datetime_utc(date, time));
}

std::shared_ptr<Instant> datetime_to_instant_in_zone(std::shared_ptr<Date> date, std::shared_ptr<Time> time, std::shared_ptr<TimeZone> zone) {
    if (zone->id == "UTC") {
        return datetime_to_instant(date, time);
    }

    const int64_t epoch_seconds = detail::with_timezone(zone->id, [&]() {
        std::tm local_tm {};
        local_tm.tm_year = date->year - 1900;
        local_tm.tm_mon = date->month - 1;
        local_tm.tm_mday = date->day;
        local_tm.tm_hour = time->hour;
        local_tm.tm_min = time->minute;
        local_tm.tm_sec = time->second;
        local_tm.tm_isdst = -1;
        const std::time_t value = std::mktime(&local_tm);
        return static_cast<int64_t>(value);
    });

    return detail::make_instant(epoch_seconds * detail::kNanosPerSecond + time->nanosecond);
}

std::shared_ptr<ZonedDateTime> datetime_at_zone(std::shared_ptr<DateTime> dateTime, std::shared_ptr<TimeZone> zone) {
    return std::make_shared<ZonedDateTime>(dateTime, zone);
}

doof::Result<std::shared_ptr<Date>, std::string> validate_date(int32_t year, int32_t month, int32_t day) {
    std::string error;
    if (!detail::validate_date_parts(year, month, day, error)) {
        return doof::Failure<std::string>{error};
    }
    return doof::Success<std::shared_ptr<Date>>{detail::make_date(year, month, day)};
}

doof::Result<std::shared_ptr<Date>, std::string> parse_date(const std::string& text) {
    return detail::parse_date_parts(text);
}

std::shared_ptr<Date> system_date_utc() {
    return instant_to_datetime(system_nanos_epoch())->date;
}

std::shared_ptr<Date> system_date_in_zone(std::shared_ptr<TimeZone> zone) {
    return instant_to_zoned_datetime(system_nanos_epoch(), zone)->dateTime->date;
}

doof::Result<std::shared_ptr<Time>, std::string> validate_time(int32_t hour, int32_t minute, int32_t second, int32_t nanosecond) {
    std::string error;
    if (!detail::validate_time_parts(hour, minute, second, nanosecond, error)) {
        return doof::Failure<std::string>{error};
    }
    return doof::Success<std::shared_ptr<Time>>{detail::make_time(hour, minute, second, nanosecond)};
}

doof::Result<std::shared_ptr<Time>, std::string> parse_time(const std::string& text) {
    return detail::parse_time_parts(text);
}

doof::Result<std::shared_ptr<DateTime>, std::string> parse_datetime(const std::string& text) {
    return detail::parse_datetime_parts(text);
}

DayOfWeek date_to_day_of_week(int32_t year, int32_t month, int32_t day) {
    const int32_t value = static_cast<int32_t>(detail::floor_mod(detail::days_from_civil(year, month, day) + 3, 7)) + 1;
    return static_cast<DayOfWeek>(value);
}

int32_t date_to_day_of_year(int32_t year, int32_t month, int32_t day) {
    static const int32_t cumulative_days[12] = {0, 31, 59, 90, 120, 151, 181, 212, 243, 273, 304, 334};
    int32_t result = cumulative_days[month - 1] + day;
    if (month > 2 && detail::is_leap_year_value(year)) {
        ++result;
    }
    return result;
}

bool is_leap_year(int32_t year) {
    return detail::is_leap_year_value(year);
}

int32_t days_in_month(int32_t year, int32_t month) {
    return detail::days_in_month_value(year, month);
}

std::shared_ptr<Date> date_add_days(int32_t year, int32_t month, int32_t day, int32_t delta_days) {
    return detail::add_days_to_date(year, month, day, delta_days);
}

std::shared_ptr<Date> date_add_months(int32_t year, int32_t month, int32_t day, int32_t delta_months) {
    return detail::add_months_to_date(year, month, day, delta_months);
}

std::shared_ptr<Date> date_add_years(int32_t year, int32_t month, int32_t day, int32_t delta_years) {
    return detail::add_years_to_date(year, month, day, delta_years);
}

int32_t date_diff(int32_t year1, int32_t month1, int32_t day1, int32_t year2, int32_t month2, int32_t day2) {
    return static_cast<int32_t>(detail::days_from_civil(year2, month2, day2) - detail::days_from_civil(year1, month1, day1));
}

std::shared_ptr<Time> time_add_nanos(int32_t hour, int32_t minute, int32_t second, int32_t nanosecond, int64_t delta_nanos) {
    const int64_t total_nanos =
        static_cast<int64_t>(hour) * 3'600'000'000'000LL +
        static_cast<int64_t>(minute) * 60'000'000'000LL +
        static_cast<int64_t>(second) * detail::kNanosPerSecond +
        static_cast<int64_t>(nanosecond) +
        delta_nanos;
    return detail::make_time_of_day_from_nanos(total_nanos);
}

std::shared_ptr<DateTime> datetime_plus_nanos(std::shared_ptr<Date> date, std::shared_ptr<Time> time, int64_t delta_nanos) {
    const int64_t base_nanos =
        static_cast<int64_t>(time->hour) * 3'600'000'000'000LL +
        static_cast<int64_t>(time->minute) * 60'000'000'000LL +
        static_cast<int64_t>(time->second) * detail::kNanosPerSecond +
        static_cast<int64_t>(time->nanosecond);
    const int64_t shifted = base_nanos + delta_nanos;
    const int64_t day_offset = detail::floor_div(shifted, detail::kNanosPerDay);
    auto shifted_date = detail::add_days_to_date(date->year, date->month, date->day, day_offset);
    auto shifted_time = detail::make_time_of_day_from_nanos(shifted);
    return detail::make_datetime(shifted_date, shifted_time);
}

doof::Result<std::shared_ptr<TimeZone>, std::string> lookup_timezone(const std::string& id) {
    if (!detail::is_valid_zone_id(id) || !detail::zone_file_exists(id)) {
        return doof::Failure<std::string>{"Unknown timezone: " + id};
    }
    return doof::Success<std::shared_ptr<TimeZone>>{detail::make_timezone(id == "Etc/UTC" ? "UTC" : id)};
}

std::shared_ptr<TimeZone> system_timezone() {
    return detail::make_timezone(detail::current_timezone_id());
}

int32_t zone_offset_at(const std::string& id, int64_t epoch_seconds) {
    if (id == "UTC") {
        return 0;
    }

    return detail::with_timezone(id, [&]() {
        std::time_t raw = static_cast<std::time_t>(epoch_seconds);
        std::tm local_tm {};
        if (::localtime_r(&raw, &local_tm) == nullptr) {
            doof::panic("Failed to resolve timezone offset");
        }

        const std::time_t local_as_utc = ::timegm(&local_tm);
        return static_cast<int32_t>(local_as_utc - raw);
    });
}

bool zone_dst_at(const std::string& id, int64_t epoch_seconds) {
    if (id == "UTC") {
        return false;
    }

    return detail::with_timezone(id, [&]() {
        std::time_t raw = static_cast<std::time_t>(epoch_seconds);
        std::tm local_tm {};
        if (::localtime_r(&raw, &local_tm) == nullptr) {
            doof::panic("Failed to resolve DST state");
        }
        return local_tm.tm_isdst > 0;
    });
}

void thread_sleep_nanos(int64_t nanos) {
    if (nanos <= 0) {
        return;
    }
    std::this_thread::sleep_for(std::chrono::nanoseconds(nanos));
}

}  // namespace doof_time
