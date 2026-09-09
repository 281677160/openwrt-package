#ifndef QMODEM_VOIP_CALL_HISTORY_H
#define QMODEM_VOIP_CALL_HISTORY_H

#include "call_state.h"

#include <json-c/json.h>

#define QMODEM_VOIP_CALL_HISTORY_PATH "/var/lib/qmodem_voip/call-history.json"
#define QMODEM_VOIP_CALL_HISTORY_LIMIT 100U

int qmodem_voip_call_history_append(const char *path,
				    const struct qmodem_voip_completed_call *call);
struct json_object *qmodem_voip_call_history_load(const char *path);

#endif
