#include "call_state.h"

#include <assert.h>
#include <stdio.h>
#include <string.h>

static void issue(const char *command, void *opaque)
{
	(void)command;
	(void)opaque;
}

static void event(const struct qmodem_voip_call *call, const char *name,
		  void *opaque)
{
	(void)call;
	(void)name;
	(void)opaque;
}

int main(void)
{
	struct qmodem_voip_call call;
	qmodem_voip_call_init(&call);
	qmodem_voip_call_set_enabled(&call, 1);
	assert(qmodem_voip_call_select_at_port(&call, "/dev/ttyUSB3") == 1);
	call.state = QMODEM_VOIP_OUTGOING_SETUP;
	call.reconcile_pending = 1;
	call.restart_epoch = 77;
	call.sequence = 75;
	assert(qmodem_voip_line(&call, "/dev/ttyUSB4", 77, 42,
		"+CLCC: 3,0,0,0,0,\"test-peer\",129",
		QMODEM_VOIP_CORR_RESPONSE, 9, 0, issue, event, NULL) == 1);
	assert(call.sequence == 75);
	assert(qmodem_voip_call_select_at_port(&call, "/dev/ttyUSB4") == 1);
	assert(call.restart_epoch == 0 && call.sequence == 0);
	assert(qmodem_voip_line(&call, "/dev/ttyUSB4", 77, 42,
		"+CLCC: 3,0,0,0,0,\"test-peer\",129",
		QMODEM_VOIP_CORR_RESPONSE, 9, 0, issue, event, NULL) == 0);
	assert(call.state == QMODEM_VOIP_ACTIVE);
	assert(strcmp(call.at_port, "/dev/ttyUSB4") == 0);
	{
		uint64_t revision = call.revision;
		assert(qmodem_voip_line(&call, "/dev/ttyUSB4", 77, 43,
			"+CLCC: 3,0,0,0,0,\"test-peer\",129",
			QMODEM_VOIP_CORR_RESPONSE, 10, 0, issue, event, NULL) == 0);
		assert(call.state == QMODEM_VOIP_ACTIVE);
		assert(call.revision == revision);
	}
	puts("VoIP AT event port switch contract passed");
	return 0;
}
