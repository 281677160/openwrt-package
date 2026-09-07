#define _POSIX_C_SOURCE 200809L

#include "media_serial.h"

#include <dirent.h>
#include <errno.h>
#include <fcntl.h>
#include <stdio.h>
#include <poll.h>
#include <stdlib.h>
#include <string.h>
#include <termios.h>
#include <unistd.h>

static int read_line(const char *path, char *value, size_t size)
{
	FILE *file = fopen(path, "r");
	if (!file || !fgets(value, (int)size, file)) {
		if (file)
			fclose(file);
		return -1;
	}
	fclose(file);
	value[strcspn(value, "\r\n")] = '\0';
	return 0;
}

static int valid_slot(const char *slot)
{
	const unsigned char *cursor = (const unsigned char *)slot;
	if (!slot || !slot[0] || strlen(slot) >= 64)
		return 0;
	while (*cursor) {
		if ((*cursor < '0' || *cursor > '9') && *cursor != '-' && *cursor != '.')
			return 0;
		cursor++;
	}
	return 1;
}

static int modem_identity(const char *root, const char *slot)
{
	char path[512];
	char value[128];
	(void)snprintf(path, sizeof(path), "%s/%s/idVendor", root, slot);
	if (read_line(path, value, sizeof(value)) || strcmp(value, "2c7c"))
		return -1;
	(void)snprintf(path, sizeof(path), "%s/%s/idProduct", root, slot);
	if (read_line(path, value, sizeof(value)) || strcmp(value, "0801"))
		return -1;
	(void)snprintf(path, sizeof(path), "%s/%s/product", root, slot);
	return read_line(path, value, sizeof(value)) ||
		strcmp(value, QMODEM_VOIP_MEDIA_PRODUCT) ? -1 : 0;
}

static int tty_in_directory(const char *directory, char *tty, size_t tty_size)
{
	DIR *entries = opendir(directory);
	struct dirent *entry;
	unsigned matches = 0;
	if (!entries)
		return -1;
	while ((entry = readdir(entries))) {
		if (strncmp(entry->d_name, "ttyUSB", 6) != 0)
			continue;
		if (strlen(entry->d_name) >= tty_size) {
			closedir(entries);
			return -1;
		}
		(void)snprintf(tty, tty_size, "%s", entry->d_name);
		matches++;
	}
	closedir(entries);
	return matches == 1 ? 0 : -1;
}

static int tty_for_interface(const char *interface, char *tty, size_t tty_size)
{
	DIR *entries;
	struct dirent *entry;
	char path[512];
	unsigned matches = 0;

	(void)snprintf(path, sizeof(path), "%s/tty", interface);
	if (tty_in_directory(path, tty, tty_size) == 0)
		return 0;
	entries = opendir(interface);
	if (!entries)
		return -1;
	while ((entry = readdir(entries))) {
		if (strncmp(entry->d_name, "ttyUSB", 6) != 0)
			continue;
		(void)snprintf(path, sizeof(path), "%s/%s/tty", interface,
			entry->d_name);
		if (tty_in_directory(path, tty, tty_size) == 0)
			matches++;
	}
	closedir(entries);
	return matches == 1 ? 0 : -1;
}

int qmodem_voip_serial_discover(const char *sysfs_root, const char *device_root,
				const char *slot, char *path, size_t path_size)
{
	DIR *entries;
	struct dirent *entry;
	char prefix[80];
	char candidate[512];
	char value[16];
	char tty[64];
	unsigned matches = 0;

	if (!sysfs_root || !device_root || !path || !path_size || !valid_slot(slot) ||
		modem_identity(sysfs_root, slot))
		return -1;
	if (snprintf(prefix, sizeof(prefix), "%s:", slot) < 0)
		return -1;
	entries = opendir(sysfs_root);
	if (!entries)
		return -1;
	while ((entry = readdir(entries))) {
		if (strncmp(entry->d_name, prefix, strlen(prefix)) != 0)
			continue;
		(void)snprintf(candidate, sizeof(candidate), "%s/%s/bInterfaceNumber",
			sysfs_root, entry->d_name);
		if (read_line(candidate, value, sizeof(value)) || strcmp(value, "01"))
			continue;
		(void)snprintf(candidate, sizeof(candidate), "%s/%s", sysfs_root,
			entry->d_name);
		if (tty_for_interface(candidate, tty, sizeof(tty)))
			continue;
		if (snprintf(path, path_size, "%s/%s", device_root, tty) < 0 ||
			strlen(device_root) + strlen(tty) + 2U > path_size) {
			closedir(entries);
			return -1;
		}
		matches++;
	}
	closedir(entries);
	return matches == 1 ? 0 : -1;
}

static int nonblocking(int fd)
{
	int flags = fcntl(fd, F_GETFL);
	return flags < 0 || fcntl(fd, F_SETFL, flags | O_NONBLOCK) < 0 ? -1 : 0;
}

int qmodem_voip_serial_adopt(struct qmodem_voip_media_engine *engine, int fd,
			     const char *path)
{
	if (!engine || fd < 0 || !path || !path[0] || strlen(path) >= sizeof(engine->serial.path) ||
		nonblocking(fd) || engine->profile.frame_bytes > sizeof(engine->serial.capture) ||
		engine->profile.transfer_bytes > sizeof(engine->serial.playback))
		return -1;
	memset(&engine->serial, 0, sizeof(engine->serial));
	engine->serial.fd = fd;
	engine->serial.active = 1;
	(void)snprintf(engine->serial.path, sizeof(engine->serial.path), "%s", path);
	engine->device.capture_rate = engine->profile.sample_rate;
	engine->device.playback_rate = engine->profile.sample_rate;
	engine->device.full_duplex = 1;
	engine->backend = QMODEM_VOIP_MEDIA_BACKEND_SERIAL;
	engine->ready = 1;
	return 0;
}

static void *serial_capture_thread(void *opaque)
{
	struct qmodem_voip_media_engine *engine = opaque;
	struct pollfd descriptor = { .fd = engine->serial.fd, .events = POLLIN };
	uint64_t timestamp_ms = 0;
	while (atomic_load(&engine->serial.running)) {
		(void)qmodem_voip_serial_capture(engine, timestamp_ms += 20U);
		descriptor.revents = 0;
		int ready = poll(&descriptor, 1, 20);
		if (ready > 0)
			atomic_fetch_add(&engine->serial.poll_wakeups, 1);
		if (ready < 0 && errno != EINTR) {
			atomic_fetch_add(&engine->serial.read_errors, 1);
			break;
		}
	}
	return NULL;
}

int qmodem_voip_serial_start(struct qmodem_voip_media_engine *engine,
			     const char *sysfs_root, const char *device_root,
			     const char *slot)
{
	char path[256];
	const char *configured_path = getenv("QMODEM_VOIP_PCM_DEVICE");
	struct termios settings;
	int fd;

	if (!engine)
		return -1;
	if (!engine->profile.frame_bytes)
		qmodem_voip_profile_default(&engine->profile);
	if (configured_path && configured_path[0]) {
		if (strncmp(configured_path, "/dev/ttyUSB", 11) &&
		    strncmp(configured_path, "/dev/ttyACM", 11))
			return -1;
		if (snprintf(path, sizeof(path), "%s", configured_path) < 0 ||
		    strlen(configured_path) >= sizeof(path))
			return -1;
	} else if (qmodem_voip_serial_discover(sysfs_root, device_root, slot,
		   path, sizeof(path))) {
		return -1;
	}
	fd = open(path, O_RDWR | O_NOCTTY | O_NONBLOCK | O_CLOEXEC);
	if (fd < 0)
		return -1;
	if (tcgetattr(fd, &settings) < 0) {
		close(fd);
		return -1;
	}
	settings.c_iflag &= ~(IGNBRK | BRKINT | PARMRK | ISTRIP | INLCR | IGNCR |
		ICRNL | IXON | IXOFF | IXANY);
	settings.c_oflag &= ~OPOST;
	settings.c_lflag &= ~(ECHO | ECHONL | ICANON | ISIG | IEXTEN);
	settings.c_cflag &= ~(CSIZE | PARENB);
#ifdef CRTSCTS
	settings.c_cflag &= ~CRTSCTS;
#endif
	settings.c_cflag |= CS8 | CLOCAL | CREAD;
	settings.c_cc[VMIN] = 1;
	settings.c_cc[VTIME] = 0;
	if (tcsetattr(fd, TCSANOW, &settings) < 0 ||
		qmodem_voip_serial_adopt(engine, fd, path)) {
		close(fd);
		return -1;
	}
	atomic_store(&engine->serial.running, 1);
	if (pthread_create(&engine->serial.thread, NULL, serial_capture_thread,
		engine) != 0) {
		atomic_store(&engine->serial.running, 0);
		qmodem_voip_serial_close(engine);
		return -1;
	}
	engine->serial.thread_started = 1;
	(void)snprintf(engine->device.slot, sizeof(engine->device.slot), "%s", slot);
	(void)snprintf(engine->device.pcm_name, sizeof(engine->device.pcm_name),
		"serial:if%02x", engine->profile.interface_number);
	return 0;
}

void qmodem_voip_serial_close(struct qmodem_voip_media_engine *engine)
{
	if (!engine)
		return;
	atomic_store(&engine->serial.running, 0);
	if (engine->serial.thread_started &&
		!pthread_equal(pthread_self(), engine->serial.thread))
		(void)pthread_join(engine->serial.thread, NULL);
	if (engine->serial.active)
		(void)close(engine->serial.fd);
	memset(&engine->serial, 0, sizeof(engine->serial));
}

void qmodem_voip_serial_set_attached(struct qmodem_voip_media_engine *engine,
				     int attached)
{
	if (!engine)
		return;
	atomic_store(&engine->serial.attached, attached != 0);
	atomic_store(&engine->serial.reopen_pending,
		attached != 0 && !engine->serial.active);
}

void qmodem_voip_serial_prepare_call(struct qmodem_voip_media_engine *engine)
{
	if (!engine || engine->backend != QMODEM_VOIP_MEDIA_BACKEND_SERIAL)
		return;
	qmodem_voip_serial_reset_stream(engine);
	/* Do not consume modem PCM while ATD/ATA is still in setup.  RM520
	 * exposes a short, non-audio stream during that interval; accepting it
	 * shifts the first real 20 ms frame and can poison the call lifetime. */
	qmodem_voip_serial_set_attached(engine, 0);
}

int qmodem_voip_serial_reopen(struct qmodem_voip_media_engine *engine)
{
	char slot[sizeof(engine->device.slot)];
	const char *sysfs = getenv("QMODEM_VOIP_SYSFS_ROOT");
	const char *devices = getenv("QMODEM_VOIP_DEVICE_ROOT");
	uint64_t count;
	if (!engine || engine->backend != QMODEM_VOIP_MEDIA_BACKEND_SERIAL ||
	    !atomic_load(&engine->serial.reopen_pending))
		return 0;
	(void)snprintf(slot, sizeof(slot), "%s", engine->device.slot);
	if (!sysfs)
		sysfs = "/sys/bus/usb/devices";
	if (!devices)
		devices = "/dev";
	count = atomic_load(&engine->serial.reopen_count);
	qmodem_voip_serial_close(engine);
	if (qmodem_voip_serial_start(engine, sysfs, devices, slot) != 0)
		return -1;
	atomic_store(&engine->serial.attached, 1);
	atomic_store(&engine->serial.reopen_pending, 0);
	atomic_store(&engine->serial.reopen_count, count + 1U);
	return 0;
}

int qmodem_voip_serial_reopen_now(struct qmodem_voip_media_engine *engine)
{
	if (!engine || engine->backend != QMODEM_VOIP_MEDIA_BACKEND_SERIAL)
		return -1;
	atomic_store(&engine->serial.reopen_pending, 1);
	return qmodem_voip_serial_reopen(engine);
}

void qmodem_voip_serial_reset_stream(struct qmodem_voip_media_engine *engine)
{
	if (!engine)
		return;
	memset(engine->serial.capture, 0, sizeof(engine->serial.capture));
	memset(engine->serial.playback, 0, sizeof(engine->serial.playback));
	engine->serial.capture_used = 0;
	engine->serial.playback_used = 0;
	engine->serial.playback_offset = 0;
	engine->serial.next_playback_ms = 0;
	if (engine->serial.active)
		(void)tcflush(engine->serial.fd, TCIOFLUSH);
}

static int serial_failure(struct qmodem_voip_media_engine *engine)
{
	atomic_store(&engine->serial.running, 0);
	if (!engine->serial.thread_started)
		qmodem_voip_serial_close(engine);
	engine->ready = 0;
	return -1;
}

int qmodem_voip_serial_capture(struct qmodem_voip_media_engine *engine,
			       uint64_t timestamp_ms)
{
	ssize_t received;
	if (!engine || !engine->ready || !engine->serial.active)
		return -1;
	for (;;) {
		if (engine->serial.thread_started &&
		    !atomic_load(&engine->serial.running))
			return 0;
		received = read(engine->serial.fd,
			(unsigned char *)engine->serial.capture + engine->serial.capture_used,
			sizeof(engine->serial.capture) - engine->serial.capture_used);
		if (received > 0) {
			atomic_fetch_add(&engine->serial.read_bytes, (uint64_t)received);
			if (!atomic_load(&engine->serial.attached)) {
				engine->serial.capture_used = 0;
				continue;
			}
			engine->serial.capture_used += (size_t)received;
			while (engine->serial.capture_used >=
			       engine->profile.frame_bytes) {
				if (atomic_load(&engine->serial.attached) &&
					qmodem_voip_media_queue_push(&engine->modem_to_canonical,
					engine->serial.capture,
					QMODEM_VOIP_MEDIA_SAMPLES, timestamp_ms))
					return serial_failure(engine);
				engine->serial.capture_used -= engine->profile.frame_bytes;
				memmove(engine->serial.capture,
					(unsigned char *)engine->serial.capture +
					engine->profile.frame_bytes,
					engine->serial.capture_used);
				memset((unsigned char *)engine->serial.capture +
					engine->serial.capture_used, 0,
					sizeof(engine->serial.capture) - engine->serial.capture_used);
				atomic_fetch_add(&engine->serial.captured_frames, 1);
				timestamp_ms += engine->profile.frame_ms;
			}
			continue;
		}
		if (received == 0)
			return serial_failure(engine);
		if (errno == EAGAIN || errno == EWOULDBLOCK) {
			atomic_fetch_add(&engine->serial.read_eagain, 1);
			return 0;
		}
		if (errno == EINTR)
			continue;
		atomic_fetch_add(&engine->serial.read_errors, 1);
		return serial_failure(engine);
	}
}

int qmodem_voip_serial_playback(struct qmodem_voip_media_engine *engine,
				 uint64_t timestamp_ms)
{
	struct qmodem_voip_media_frame frame;
	ssize_t written;
	size_t transfer = engine->profile.transfer_bytes ?
		engine->profile.transfer_bytes : QMODEM_VOIP_SERIAL_TRANSFER_BYTES;
	if (!engine || !engine->ready || !engine->serial.active ||
	    transfer > sizeof(engine->serial.playback))
		return -1;
	for (;;) {
		if (!engine->serial.playback_offset) {
			if (timestamp_ms < engine->serial.next_playback_ms)
				return 0;
			while (engine->serial.playback_used < transfer) {
			int popped = qmodem_voip_media_queue_pop(
				&engine->canonical_to_modem, &frame);
			if (popped < 0)
				return serial_failure(engine);
			if (popped > 0)
				return 0;
			memcpy((unsigned char *)engine->serial.playback +
				engine->serial.playback_used, frame.samples, sizeof(frame.samples));
			engine->serial.playback_used += sizeof(frame.samples);
			memset(&frame, 0, sizeof(frame));
			}
			engine->serial.playback_offset = 0;
		}
		written = write(engine->serial.fd,
			(unsigned char *)engine->serial.playback + engine->serial.playback_offset,
			transfer - engine->serial.playback_offset);
		if (written > 0) {
			atomic_fetch_add(&engine->serial.write_bytes, (uint64_t)written);
			engine->serial.playback_offset += (size_t)written;
			if (engine->serial.playback_offset == transfer) {
				size_t remaining = engine->serial.playback_used - transfer;
				memmove(engine->serial.playback,
					(unsigned char *)engine->serial.playback +
					transfer, remaining);
				memset((unsigned char *)engine->serial.playback + remaining, 0,
					sizeof(engine->serial.playback) - remaining);
				engine->serial.playback_used = remaining;
				engine->serial.playback_offset = 0;
				engine->serial.next_playback_ms = timestamp_ms +
					engine->profile.transfer_interval_ms;
				return 0;
			}
			continue;
		}
		if (written < 0 && (errno == EAGAIN || errno == EWOULDBLOCK)) {
			atomic_fetch_add(&engine->serial.write_eagain, 1);
			if (!engine->serial.playback_offset)
				engine->serial.next_playback_ms = timestamp_ms + 20U;
			return 0;
		}
		if (written < 0 && errno == EINTR)
			continue;
		atomic_fetch_add(&engine->serial.write_errors, 1);
		return serial_failure(engine);
	}
}
