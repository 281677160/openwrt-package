#include "../src/call_state.h"

#include <assert.h>
#include <string.h>

static char issued[32];

static void capture_command(const char *command, void *opaque)
{
	(void)opaque;
	strncpy(issued, command, sizeof(issued) - 1U);
	issued[sizeof(issued) - 1U] = '\0';
}

int main(void)
{
	struct qmodem_voip_call call;

	qmodem_voip_call_init(&call);
	qmodem_voip_call_set_enabled(&call, 1);
	call.state = QMODEM_VOIP_INCOMING_RINGING;
	call.origin = QMODEM_VOIP_ENDPOINT_CELLULAR;
	assert(qmodem_voip_answer(&call, QMODEM_VOIP_ENDPOINT_BROWSER,
		capture_command, NULL) == 0);
	assert(strcmp(issued, "ATA") == 0);
	assert(call.active_since_msec > 0);
	assert(qmodem_voip_call_duration_seconds(&call) <= 1);
	assert(call.active_since_msec > 3000U);
	call.active_since_msec -= 3000U;
	assert(qmodem_voip_call_duration_seconds(&call) >= 3);

	issued[0] = '\0';
	assert(qmodem_voip_send_dtmf(&call, QMODEM_VOIP_ENDPOINT_BROWSER,
		'#', capture_command, NULL) == 0);
	assert(strcmp(issued, "AT+VTS=\"#\"") == 0);
	issued[0] = '\0';
	assert(qmodem_voip_send_dtmf(&call, QMODEM_VOIP_ENDPOINT_BROWSER,
		'X', capture_command, NULL) == -4);
	assert(issued[0] == '\0');
	assert(qmodem_voip_send_dtmf(&call, QMODEM_VOIP_ENDPOINT_LAN_SIP,
		'1', capture_command, NULL) == -3);

	qmodem_voip_call_init(&call);
	qmodem_voip_call_set_enabled(&call, 1);
	assert(qmodem_voip_call_select_at_port(&call, "ttyUSB2") == 1);
	assert(qmodem_voip_line(&call, "ttyUSB2", 1, 1, "RING",
		QMODEM_VOIP_CORR_IDLE, 0, 0, NULL, NULL, NULL) == 0);
	assert(call.state == QMODEM_VOIP_INCOMING_RINGING);
	assert(qmodem_voip_poll_active(&call, capture_command, NULL) == 0);
	assert(strcmp(issued, "AT+CLCC") == 0);
	assert(qmodem_voip_line(&call, "ttyUSB2", 1, 2,
		"+CLCC: 1,0,0,1,0,\"\",128",
		QMODEM_VOIP_CORR_RESPONSE, 7, 0, NULL, NULL, NULL) == 0);
	assert(qmodem_voip_line(&call, "ttyUSB2", 1, 3,
		"+CLCC: 2,0,0,1,0,\"\",128",
		QMODEM_VOIP_CORR_RESPONSE, 7, 0, NULL, NULL, NULL) == 0);
	assert(qmodem_voip_line(&call, "ttyUSB2", 1, 4,
		"+CLCC: 3,1,4,0,0,\"15500001234\",128",
		QMODEM_VOIP_CORR_RESPONSE, 7, 0, NULL, NULL, NULL) == 0);
	assert(call.state == QMODEM_VOIP_INCOMING_RINGING);
	assert(strcmp(call.number, "15500001234") == 0);
	assert(call.caller_id_withheld == 0);
	assert(qmodem_voip_poll_active(&call, capture_command, NULL) == 0);
	assert(strcmp(issued, "AT+CLCC") == 0);
	assert(qmodem_voip_line(&call, "ttyUSB2", 1, 5, "OK",
		QMODEM_VOIP_CORR_TERMINAL, 8, 0, NULL, NULL, NULL) == 0);
	assert(call.state == QMODEM_VOIP_INCOMING_RINGING);
	assert(strcmp(call.number, "15500001234") == 0);

	qmodem_voip_call_set_enabled(&call, 0);
	assert(qmodem_voip_call_duration_seconds(&call) == 0);
	return 0;
}
