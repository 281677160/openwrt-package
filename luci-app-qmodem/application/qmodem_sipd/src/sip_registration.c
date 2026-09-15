#include "sip_registration.h"

#include <stddef.h>

void qmodem_voip_sip_registration_retry_init(
	struct qmodem_voip_sip_registration_retry *retry)
{
	if (!retry)
		return;
	retry->attempts = 0;
	retry->failures = 0;
	retry->next_delay_ms = QMODEM_VOIP_SIP_REGISTER_RETRY_INITIAL_MS;
	retry->scheduled_delay_ms = 0;
}

void qmodem_voip_sip_registration_attempt(
	struct qmodem_voip_sip_registration_retry *retry)
{
	if (retry)
		retry->attempts++;
}

unsigned qmodem_voip_sip_registration_failed(
	struct qmodem_voip_sip_registration_retry *retry, uint32_t entropy)
{
	unsigned delay;
	unsigned jitter;

	if (!retry)
		return QMODEM_VOIP_SIP_REGISTER_RETRY_INITIAL_MS;
	retry->failures++;
	delay = retry->next_delay_ms;
	jitter = (unsigned)(((uint64_t)delay * (entropy % 21U)) / 100U);
	retry->scheduled_delay_ms = delay - jitter;
	if (retry->next_delay_ms < QMODEM_VOIP_SIP_REGISTER_RETRY_MAX_MS / 2U)
		retry->next_delay_ms *= 2U;
	else
		retry->next_delay_ms = QMODEM_VOIP_SIP_REGISTER_RETRY_MAX_MS;
	return retry->scheduled_delay_ms;
}

void qmodem_voip_sip_registration_succeeded(
	struct qmodem_voip_sip_registration_retry *retry)
{
	if (!retry)
		return;
	retry->next_delay_ms = QMODEM_VOIP_SIP_REGISTER_RETRY_INITIAL_MS;
	retry->scheduled_delay_ms = 0;
}

void qmodem_voip_sip_registration_retry_started(
	struct qmodem_voip_sip_registration_retry *retry)
{
	if (retry)
		retry->scheduled_delay_ms = 0;
}
