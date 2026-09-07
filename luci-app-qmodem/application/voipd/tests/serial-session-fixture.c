#define _POSIX_C_SOURCE 200809L

#include "../src/media_serial.h"

#include <assert.h>
#include <fcntl.h>
#include <stdatomic.h>
#include <stdio.h>
#include <string.h>
#include <sys/socket.h>
#include <unistd.h>

void qmodem_voip_profile_default(struct qmodem_voip_modem_profile *profile)
{
	memset(profile, 0, sizeof(*profile));
	profile->frame_bytes = 320;
	profile->transfer_bytes = 320;
}

int qmodem_voip_media_queue_push(struct qmodem_voip_media_queue *queue,
	const int16_t *samples, size_t sample_count, uint64_t timestamp_ms)
{
	(void)queue;
	(void)samples;
	(void)sample_count;
	(void)timestamp_ms;
	return 0;
}

int qmodem_voip_media_queue_pop(struct qmodem_voip_media_queue *queue,
	struct qmodem_voip_media_frame *frame)
{
	(void)queue;
	memset(frame, 0, sizeof(*frame));
	return 1;
}

int main(void)
{
	struct qmodem_voip_media_engine engine;
	int sockets[2];
	int owned_fd;

	memset(&engine, 0, sizeof(engine));
	engine.profile.frame_bytes = 320;
	engine.profile.transfer_bytes = 320;
	assert(socketpair(AF_UNIX, SOCK_STREAM, 0, sockets) == 0);
	assert(qmodem_voip_serial_adopt(&engine, sockets[0], "/dev/ttyUSB1") == 0);
	owned_fd = engine.serial.fd;
	engine.serial.capture_used = 160;
	engine.serial.playback_used = 768;
	engine.serial.playback_offset = 256;
	engine.serial.next_playback_ms = 9000;
	atomic_store(&engine.serial.attached, 0);

	qmodem_voip_serial_prepare_call(&engine);

	assert(engine.serial.fd == owned_fd);
	assert(engine.serial.active);
	assert(fcntl(owned_fd, F_GETFD) != -1);
	assert(engine.serial.capture_used == 0);
	assert(engine.serial.playback_used == 0);
	assert(engine.serial.playback_offset == 0);
	assert(engine.serial.next_playback_ms == 0);
	assert(!atomic_load(&engine.serial.attached));
	assert(!atomic_load(&engine.serial.reopen_pending));

	qmodem_voip_serial_close(&engine);
	assert(close(sockets[1]) == 0);
	puts("PASS: serial call preparation resets framing and retains tty ownership");
	return 0;
}
