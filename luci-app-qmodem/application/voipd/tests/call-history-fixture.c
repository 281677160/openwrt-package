#include "../src/call_history.h"

#include <assert.h>
#include <json-c/json.h>
#include <string.h>

int main(int argc, char **argv)
{
	struct qmodem_voip_completed_call call = { 0 };
	struct json_object *history;
	struct json_object *entry;
	struct json_object *value;

	assert(argc == 2);
	call.started_at = 100;
	call.ended_at = 110;
	call.origin = QMODEM_VOIP_ENDPOINT_CELLULAR;
	strcpy(call.number, "15500001234");
	assert(qmodem_voip_call_history_append(argv[1], &call) == 0);
	history = qmodem_voip_call_history_load(argv[1]);
	assert(history != NULL);
	assert(json_object_array_length(history) == 1);
	entry = json_object_array_get_idx(history, 0);
	assert(json_object_object_get_ex(entry, "missed", &value));
	assert(json_object_get_boolean(value));
	assert(json_object_object_get_ex(entry, "remote_number", &value));
	assert(strcmp(json_object_get_string(value), "15500001234") == 0);
	json_object_put(history);

	call.started_at = 200;
	call.ended_at = 220;
	call.duration_seconds = 12;
	call.was_active = 1;
	assert(qmodem_voip_call_history_append(argv[1], &call) == 0);
	history = qmodem_voip_call_history_load(argv[1]);
	assert(json_object_array_length(history) == 2);
	entry = json_object_array_get_idx(history, 0);
	assert(json_object_object_get_ex(entry, "result", &value));
	assert(strcmp(json_object_get_string(value), "completed") == 0);
	json_object_put(history);
	return 0;
}
