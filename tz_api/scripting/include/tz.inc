#if defined _tz_included
 #endinput
#endif
#define _tz_included

/**
 * Gets the timezone time as a unix timestamp.
 *
 * @param timezone		Timezone to determine the timestamp.
 * @param dst			Daylight Saving 1 or 0.
 * @param offset		Timezone offset.
 * @return				Timezone time as a unix timestamp, or -1 on failure.
 */
native int TZ_GetTime(const char[] timezone, int &dst, &offset);