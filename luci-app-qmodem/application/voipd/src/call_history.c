#define _POSIX_C_SOURCE 200809L

#include "call_history.h"

#include <errno.h>
#include <fcntl.h>
#include <stdio.h>
#include <string.h>
#include <sys/stat.h>
#include <unistd.h>

static struct json_object *empty_history(void)
{
	return json_object_new_array();
}

struct json_object *qmodem_voip_call_history_load(const char *path)
{
	struct json_object *history;

	errno = 0;
	history = json_object_from_file(path);
	if (!history) {
		if (errno == ENOENT)
			return empty_history();
		return NULL;
	}
	if (!json_object_is_type(history, json_type_array)) {
		json_object_put(history);
		return NULL;
	}
	return history;
}

static int write_all(int descriptor, const char *value, size_t length)
{
	while (length) {
		ssize_t written = write(descriptor, value, length);
		if (written < 0 && errno == EINTR)
			continue;
		if (written <= 0)
			return -1;
		value += written;
		length -= (size_t)written;
	}
	return 0;
}

static int write_history(const char *path, struct json_object *history)
{
	const char *serialized;
	char temporary[256];
	char directory[256];
	char *separator;
	int descriptor;
	int directory_descriptor;
	int result = -1;

	if (strlen(path) + 12U >= sizeof(temporary))
		return -1;
	(void)snprintf(temporary, sizeof(temporary), "%s.XXXXXX", path);
	descriptor = mkstemp(temporary);
	if (descriptor < 0)
		return -1;
	serialized = json_object_to_json_string_ext(history,
		JSON_C_TO_STRING_PLAIN);
	if (fchmod(descriptor, S_IRUSR | S_IWUSR) != 0 ||
	    write_all(descriptor, serialized, strlen(serialized)) != 0 ||
	    write_all(descriptor, "\n", 1) != 0 || fsync(descriptor) != 0) {
		(void)close(descriptor);
		(void)unlink(temporary);
		return -1;
	}
	if (close(descriptor) != 0) {
		(void)unlink(temporary);
		return -1;
	}
	if (rename(temporary, path) != 0) {
		(void)unlink(temporary);
		return -1;
	}

	(void)snprintf(directory, sizeof(directory), "%s", path);
	separator = strrchr(directory, '/');
	if (separator) {
		if (separator == directory)
			separator[1] = '\0';
		else
			*separator = '\0';
		directory_descriptor = open(directory, O_RDONLY);
		if (directory_descriptor >= 0) {
			(void)fsync(directory_descriptor);
			(void)close(directory_descriptor);
		}
	}
	result = 0;
	return result;
}

int qmodem_voip_call_history_append(const char *path,
				    const struct qmodem_voip_completed_call *call)
{
	struct json_object *old_history;
	struct json_object *new_history;
	struct json_object *entry;
	size_t count;
	size_t i;
	int incoming;
	int result = -1;

	if (!path || !call || !call->started_at)
		return -1;
	old_history = qmodem_voip_call_history_load(path);
	if (!old_history)
		return -1;
	new_history = empty_history();
	entry = json_object_new_object();
	if (!new_history || !entry)
		goto out;
	incoming = call->origin == QMODEM_VOIP_ENDPOINT_CELLULAR;
	json_object_object_add(entry, "started_at",
		json_object_new_int64((int64_t)call->started_at));
	json_object_object_add(entry, "ended_at",
		json_object_new_int64((int64_t)call->ended_at));
	json_object_object_add(entry, "duration_seconds",
		json_object_new_int64((int64_t)call->duration_seconds));
	json_object_object_add(entry, "direction",
		json_object_new_string(incoming ? "incoming" : "outgoing"));
	json_object_object_add(entry, "result", json_object_new_string(
		incoming && !call->was_active ? "missed" :
		(call->was_active ? "completed" : "failed")));
	json_object_object_add(entry, "missed",
		json_object_new_boolean(incoming && !call->was_active));
	json_object_object_add(entry, "caller_id_withheld",
		json_object_new_boolean(call->caller_id_withheld));
	json_object_object_add(entry, "number_present",
		json_object_new_boolean(call->number[0] != '\0'));
	json_object_object_add(entry, "remote_number",
		json_object_new_string(call->caller_id_withheld ? "" : call->number));
	json_object_array_add(new_history, entry);
	entry = NULL;
	count = json_object_array_length(old_history);
	if (count >= QMODEM_VOIP_CALL_HISTORY_LIMIT)
		count = QMODEM_VOIP_CALL_HISTORY_LIMIT - 1U;
	for (i = 0; i < count; i++) {
		struct json_object *item = json_object_array_get_idx(old_history, i);
		if (item)
			json_object_array_add(new_history, json_object_get(item));
	}
	result = write_history(path, new_history);
out:
	if (entry)
		json_object_put(entry);
	if (new_history)
		json_object_put(new_history);
	json_object_put(old_history);
	return result;
}
