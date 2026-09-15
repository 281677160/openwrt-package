#ifndef QMODEM_VOIP_SIP_REGISTRATION_H
#define QMODEM_VOIP_SIP_REGISTRATION_H

#include <stdint.h>

#define QMODEM_VOIP_SIP_REGISTER_RETRY_INITIAL_MS 5000U
#define QMODEM_VOIP_SIP_REGISTER_RETRY_MAX_MS 300000U

struct qmodem_voip_sip_registration_retry {
	uint64_t attempts;
	uint64_t failures;
	unsigned next_delay_ms;
	unsigned scheduled_delay_ms;
};

void qmodem_voip_sip_registration_retry_init(
	struct qmodem_voip_sip_registration_retry *retry);
void qmodem_voip_sip_registration_attempt(
	struct qmodem_voip_sip_registration_retry *retry);
unsigned qmodem_voip_sip_registration_failed(
	struct qmodem_voip_sip_registration_retry *retry, uint32_t entropy);
void qmodem_voip_sip_registration_succeeded(
	struct qmodem_voip_sip_registration_retry *retry);
void qmodem_voip_sip_registration_retry_started(
	struct qmodem_voip_sip_registration_retry *retry);

#endif
