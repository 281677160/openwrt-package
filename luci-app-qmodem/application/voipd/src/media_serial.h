#ifndef QMODEM_VOIP_MEDIA_SERIAL_H
#define QMODEM_VOIP_MEDIA_SERIAL_H

#include "media.h"

int qmodem_voip_serial_discover(const char *sysfs_root, const char *device_root,
				const char *slot, char *path, size_t path_size);
int qmodem_voip_serial_adopt(struct qmodem_voip_media_engine *engine, int fd,
			     const char *path);
int qmodem_voip_serial_start(struct qmodem_voip_media_engine *engine,
			     const char *sysfs_root, const char *device_root,
			     const char *slot);
int qmodem_voip_serial_capture(struct qmodem_voip_media_engine *engine,
			       uint64_t timestamp_ms);
int qmodem_voip_serial_playback(struct qmodem_voip_media_engine *engine,
				 uint64_t timestamp_ms);
int qmodem_voip_serial_reopen(struct qmodem_voip_media_engine *engine);
int qmodem_voip_serial_reopen_now(struct qmodem_voip_media_engine *engine);
void qmodem_voip_serial_close(struct qmodem_voip_media_engine *engine);
void qmodem_voip_serial_reset_stream(struct qmodem_voip_media_engine *engine);
void qmodem_voip_serial_set_attached(struct qmodem_voip_media_engine *engine,
				     int attached);
void qmodem_voip_serial_prepare_call(struct qmodem_voip_media_engine *engine);

#endif
