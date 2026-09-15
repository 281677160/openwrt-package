#include "sip_registration.h"

#include <assert.h>

int main(void)
{
	struct qmodem_voip_sip_registration_retry retry;
	unsigned delay;
	int index;

	qmodem_voip_sip_registration_retry_init(&retry);
	assert(retry.attempts == 0);
	assert(retry.failures == 0);
	assert(retry.next_delay_ms == 5000);

	qmodem_voip_sip_registration_attempt(&retry);
	assert(retry.attempts == 1);
	delay = qmodem_voip_sip_registration_failed(&retry, 0);
	assert(delay == 5000);
	assert(retry.scheduled_delay_ms == 5000);
	assert(retry.next_delay_ms == 10000);

	qmodem_voip_sip_registration_retry_started(&retry);
	assert(retry.scheduled_delay_ms == 0);
	delay = qmodem_voip_sip_registration_failed(&retry, 20);
	assert(delay == 8000);
	assert(retry.scheduled_delay_ms == 8000);
	for (index = 0; index < 10; index++)
		delay = qmodem_voip_sip_registration_failed(&retry, 20);
	assert(delay == 240000);
	assert(retry.next_delay_ms == 300000);

	qmodem_voip_sip_registration_succeeded(&retry);
	assert(retry.scheduled_delay_ms == 0);
	assert(retry.next_delay_ms == 5000);
	assert(retry.failures == 12);
	return 0;
}
