#define _POSIX_C_SOURCE 200809L

#include "modem_profile.h"

#include <ctype.h>
#include <json-c/json.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>

void qmodem_voip_profile_default(struct qmodem_voip_modem_profile *profile)
{
	memset(profile, 0, sizeof(*profile));
	snprintf(profile->model, sizeof(profile->model), "%s", "RM520N-GL");
	snprintf(profile->usb_id, sizeof(profile->usb_id), "%s", "2c7c:0801");
	profile->interface_number = 1;
	profile->sample_rate = 8000;
	profile->frame_ms = 20;
	profile->transfer_bytes = 1024;
	profile->transfer_interval_ms = 60;
	snprintf(profile->qaudmod, sizeof(profile->qaudmod), "2");
	snprintf(profile->qpcmv, sizeof(profile->qpcmv), "1,0");
	snprintf(profile->qpcmv_cfg, sizeof(profile->qpcmv_cfg), "8000,20");
	profile->adb_unlock = 0;
	profile->voice_server_media_gate = 0;
	profile->voice_server_restart = 0;
	profile->voice_server_dependency_service[0] = '\0';
	snprintf(profile->voice_server_service, sizeof(profile->voice_server_service),
		"quectel-voice-server.service");
	profile->frame_samples = profile->sample_rate * profile->frame_ms / 1000U;
	profile->frame_bytes = profile->frame_samples * sizeof(int16_t);
}

static void copy_string(char *target, const char *value, size_t size)
{
	if (!value || !value[0])
		return;
	snprintf(target, size, "%s", value);
}

static unsigned json_unsigned(struct json_object *object)
{
	if (!object)
		return 0;
	if (json_object_get_type(object) == json_type_int)
		return (unsigned)json_object_get_int64(object);
	if (json_object_get_type(object) == json_type_boolean)
		return json_object_get_boolean(object) ? 1U : 0U;
	if (json_object_get_type(object) == json_type_string)
		return (unsigned)strtoul(json_object_get_string(object), NULL, 10);
	return 0;
}

static int service_name_valid(const char *service)
{
	const unsigned char *cursor = (const unsigned char *)service;

	if (!service || !isalnum(*cursor))
		return 0;
	for (; *cursor; cursor++)
		if (!isalnum(*cursor) && *cursor != '-' && *cursor != '_' &&
		    *cursor != '.' && *cursor != '@')
			return 0;
	return 1;
}

int qmodem_voip_profile_load(struct qmodem_voip_modem_profile *profile,
			     const char *path, const char *model, const char *usb_id)
{
	struct json_object *root;
	struct json_object *modems;
	struct json_object *property;
	char *text;
	long length;
	FILE *file;
	struct stat status;
	size_t count;

	if (!profile || !path)
		return -1;
	if (stat(path, &status) != 0 || status.st_size <= 0 || status.st_size > 65536)
		return -1;
	length = status.st_size;
	file = fopen(path, "r");
	if (!file)
		return -1;
	text = malloc((size_t)length + 1U);
	if (!text) {
		fclose(file);
		return -1;
	}
	if (fread(text, 1, (size_t)length, file) != (size_t)length) {
		free(text);
		fclose(file);
		return -1;
	}
	fclose(file);
	text[length] = '\0';
	root = json_tokener_parse(text);
	free(text);
	if (!root)
		return -1;
	if (!json_object_object_get_ex(root, "modems", &modems) ||
	    json_object_get_type(modems) != json_type_array) {
		json_object_put(root);
		return -1;
	}
	count = json_object_array_length(modems);
	for (size_t i = 0; i < count; i++) {
		struct json_object *entry = json_object_array_get_idx(modems, i);
		struct json_object *audio;
		struct json_object *entry_model;
		struct json_object *usb_object;
		const char *entry_model_text;
		const char *entry_usb_id_text = NULL;
		if (!entry || json_object_get_type(entry) != json_type_object)
			continue;
		if (!json_object_object_get_ex(entry, "model", &entry_model))
			continue;
		entry_model_text = json_object_get_string(entry_model);
		if (json_object_object_get_ex(entry, "usb_id", &usb_object) &&
		    json_object_get_type(usb_object) == json_type_string)
			entry_usb_id_text = json_object_get_string(usb_object);
		if (model && entry_model_text && strcmp(entry_model_text, model) != 0)
			continue;
		if (model && entry_usb_id_text && usb_id && strcmp(entry_usb_id_text, usb_id) != 0)
			continue;
		if (!json_object_object_get_ex(entry, "audio", &audio) ||
		    json_object_get_type(audio) != json_type_object) {
			json_object_put(root);
			return -1;
		}
		if (entry_model_text)
			snprintf(profile->model, sizeof(profile->model), "%s", entry_model_text);
		if (entry_usb_id_text)
			snprintf(profile->usb_id, sizeof(profile->usb_id), "%s", entry_usb_id_text);
		if (json_object_object_get_ex(audio, "interface_number", &property))
			profile->interface_number = (unsigned)json_object_get_int64(property);
		if (json_object_object_get_ex(audio, "sample_rate", &property))
			profile->sample_rate = json_unsigned(property);
		if (json_object_object_get_ex(audio, "frame_ms", &property))
			profile->frame_ms = json_unsigned(property);
		if (json_object_object_get_ex(audio, "transfer_bytes", &property))
			profile->transfer_bytes = json_unsigned(property);
		if (json_object_object_get_ex(audio, "transfer_interval_ms", &property))
			profile->transfer_interval_ms = json_unsigned(property);
		if (json_object_object_get_ex(audio, "qaudmod", &property))
			copy_string(profile->qaudmod, json_object_get_string(property), sizeof(profile->qaudmod));
		if (json_object_object_get_ex(audio, "qpcmv", &property))
			copy_string(profile->qpcmv, json_object_get_string(property), sizeof(profile->qpcmv));
		if (json_object_object_get_ex(audio, "qpcmv_cfg", &property))
			copy_string(profile->qpcmv_cfg, json_object_get_string(property), sizeof(profile->qpcmv_cfg));
		if (json_object_object_get_ex(entry, "adb_unlock", &property))
			profile->adb_unlock = json_unsigned(property) != 0;
		if (json_object_object_get_ex(entry, "voice_server_media_gate", &property))
			profile->voice_server_media_gate = json_unsigned(property) != 0;
		if (json_object_object_get_ex(entry, "voice_server_restart", &property))
			profile->voice_server_restart = json_unsigned(property) != 0;
		if (json_object_object_get_ex(entry, "voice_server_dependency_service", &property))
			copy_string(profile->voice_server_dependency_service,
				json_object_get_string(property),
				sizeof(profile->voice_server_dependency_service));
		if (json_object_object_get_ex(entry, "voice_server_service", &property))
			copy_string(profile->voice_server_service,
				json_object_get_string(property), sizeof(profile->voice_server_service));
		if ((profile->voice_server_media_gate && !profile->adb_unlock) ||
		    (profile->voice_server_dependency_service[0] &&
		     !service_name_valid(profile->voice_server_dependency_service)) ||
		    (profile->voice_server_restart &&
		     !service_name_valid(profile->voice_server_service))) {
			json_object_put(root);
			return -1;
		}
		profile->frame_samples = profile->sample_rate * profile->frame_ms / 1000U;
		profile->frame_bytes = profile->frame_samples * sizeof(int16_t);
		if (!profile->interface_number || !profile->sample_rate || !profile->frame_samples ||
		    !profile->frame_bytes || !profile->transfer_bytes || !profile->transfer_interval_ms) {
			json_object_put(root);
			return -1;
		}
		json_object_put(root);
		return 0;
	}
	json_object_put(root);
	return -1;
}
