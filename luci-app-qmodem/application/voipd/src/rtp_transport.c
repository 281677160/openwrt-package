#define _POSIX_C_SOURCE 200809L

#include "rtp_transport.h"

#include <arpa/inet.h>
#include <errno.h>
#include <fcntl.h>
#include <string.h>
#include <sys/socket.h>
#include <unistd.h>

#define RTP_HEADER_SIZE 12U
#define RTP_PACKET_SIZE (RTP_HEADER_SIZE + QMODEM_VOIP_MEDIA_SAMPLES)

static int payload_offset(const uint8_t *packet, size_t length,
			  size_t *offset, size_t *payload_length)
{
	size_t value;
	size_t end = length;
	unsigned extension_words;
	if (!packet || !offset || !payload_length || length < RTP_HEADER_SIZE ||
	    (packet[0] >> 6) != 2)
		return -1;
	value = RTP_HEADER_SIZE + (size_t)(packet[0] & 15U) * 4U;
	if (value > length)
		return -1;
	if (packet[0] & 0x10U) {
		if (length - value < 4U)
			return -1;
		extension_words = ((unsigned)packet[value + 2] << 8) |
			packet[value + 3];
		if (extension_words > (length - value - 4U) / 4U)
			return -1;
		value += 4U + (size_t)extension_words * 4U;
	}
	if (packet[0] & 0x20U) {
		unsigned padding = packet[length - 1U];
		if (!padding || padding > length - value)
			return -1;
		end -= padding;
	}
	if (value > end)
		return -1;
	*offset = value;
	*payload_length = end - value;
	return 0;
}

static int receive_audio(struct qmodem_voip_rtp_transport *transport,
			 const uint8_t *packet, size_t length,
			 uint64_t timestamp_ms)
{
	int16_t samples[QMODEM_VOIP_MEDIA_SAMPLES];
	size_t offset;
	size_t payload_length;
	if (payload_offset(packet, length, &offset, &payload_length) != 0 ||
	    (packet[1] & 127U) != (unsigned)transport->codec ||
	    payload_length != QMODEM_VOIP_MEDIA_SAMPLES ||
	    qmodem_voip_media_rtp_receive(transport->engine, packet, length,
		transport->peer.sin_addr.s_addr, ntohs(transport->peer.sin_port),
		NULL, NULL) != 0 ||
	    qmodem_voip_media_g711_decode(transport->codec, packet + offset,
		payload_length, samples) != 0)
		return 0;
	if (qmodem_voip_media_queue_push(&transport->engine->canonical_to_modem,
		samples, QMODEM_VOIP_MEDIA_SAMPLES, timestamp_ms) != 0)
		return -1;
	transport->engine->rtp.received_packets++;
	atomic_fetch_add(&transport->engine->rtp_received_packets, 1);
	memset(samples, 0, sizeof(samples));
	return 1;
}

static int send_audio(struct qmodem_voip_rtp_transport *transport)
{
	struct qmodem_voip_media_frame frame;
	uint8_t packet[RTP_PACKET_SIZE] = { 0 };
	ssize_t sent;
	if (!transport->engine->modem_to_canonical.count)
		return 0;
	if (qmodem_voip_media_queue_pop(&transport->engine->modem_to_canonical,
		&frame) != 0)
		return -1;
	packet[0] = 0x80;
	packet[1] = (uint8_t)transport->codec;
	packet[2] = (uint8_t)(transport->sequence >> 8);
	packet[3] = (uint8_t)transport->sequence;
	packet[4] = (uint8_t)(transport->timestamp >> 24);
	packet[5] = (uint8_t)(transport->timestamp >> 16);
	packet[6] = (uint8_t)(transport->timestamp >> 8);
	packet[7] = (uint8_t)transport->timestamp;
	packet[8] = (uint8_t)(transport->ssrc >> 24);
	packet[9] = (uint8_t)(transport->ssrc >> 16);
	packet[10] = (uint8_t)(transport->ssrc >> 8);
	packet[11] = (uint8_t)transport->ssrc;
	if (qmodem_voip_media_g711_encode(transport->codec, frame.samples,
		QMODEM_VOIP_MEDIA_SAMPLES, packet + RTP_HEADER_SIZE) != 0)
		return -1;
	sent = sendto(transport->fd, packet, sizeof(packet), 0,
		(const struct sockaddr *)&transport->peer, sizeof(transport->peer));
	memset(&frame, 0, sizeof(frame));
	memset(packet, 0, sizeof(packet));
	if (sent != (ssize_t)RTP_PACKET_SIZE)
		return -1;
	transport->sequence++;
	transport->timestamp += QMODEM_VOIP_MEDIA_SAMPLES;
	transport->engine->rtp.sent_packets++;
	atomic_fetch_add(&transport->engine->rtp_sent_packets, 1);
	return 1;
}

void qmodem_voip_rtp_release(struct qmodem_voip_rtp_transport *transport)
{
	if (!transport)
		return;
	if (transport->active && transport->fd >= 0)
		(void)close(transport->fd);
	if (transport->engine)
		qmodem_voip_media_detach(transport->engine);
	memset(transport, 0, sizeof(*transport));
	transport->fd = -1;
}

int qmodem_voip_rtp_attach(struct qmodem_voip_rtp_transport *transport,
	struct qmodem_voip_media_engine *engine, uint32_t peer_address,
	uint16_t peer_port, enum qmodem_voip_media_codec codec,
	uint64_t session_id)
{
	struct sockaddr_in local = { 0 };
	int flags;
	int fd;
	if (!transport || !engine || !peer_address || !peer_port ||
	    (codec != QMODEM_VOIP_MEDIA_PCMA && codec != QMODEM_VOIP_MEDIA_PCMU))
		return -1;
	qmodem_voip_rtp_release(transport);
	fd = socket(AF_INET, SOCK_DGRAM, 0);
	if (fd < 0)
		return -1;
	flags = fcntl(fd, F_GETFL, 0);
	local.sin_family = AF_INET;
	local.sin_addr.s_addr = htonl(INADDR_ANY);
	local.sin_port = htons(QMODEM_VOIP_RTP_PORT);
	if (flags < 0 || fcntl(fd, F_SETFL, flags | O_NONBLOCK) != 0 ||
	    bind(fd, (struct sockaddr *)&local, sizeof(local)) != 0 ||
	    qmodem_voip_media_attach(engine, QMODEM_VOIP_MEDIA_ATTACH_LAN_SIP,
		    session_id) != 0) {
		(void)close(fd);
		return -1;
	}
	transport->fd = fd;
	transport->active = 1;
	transport->engine = engine;
	transport->codec = codec;
	transport->peer.sin_family = AF_INET;
	transport->peer.sin_addr.s_addr = peer_address;
	transport->peer.sin_port = htons(peer_port);
	transport->sequence = (uint16_t)session_id;
	transport->timestamp = (uint32_t)(session_id * QMODEM_VOIP_MEDIA_SAMPLES);
	transport->ssrc = (uint32_t)(session_id ^ peer_address ^ peer_port);
	engine->rtp.address = peer_address;
	engine->rtp.port = peer_port;
	engine->rtp.codec = codec;
	return 0;
}

int qmodem_voip_rtp_service(struct qmodem_voip_rtp_transport *transport,
	uint64_t timestamp_ms)
{
	uint8_t packet[2048];
	struct sockaddr_in source;
	socklen_t source_length = sizeof(source);
	ssize_t received;
	int transferred = 0;
	int result;
	if (!transport || !transport->active || transport->fd < 0 ||
	    !transport->engine || !transport->engine->ready)
		return -1;
	received = recvfrom(transport->fd, packet, sizeof(packet), 0,
		(struct sockaddr *)&source, &source_length);
	if (received >= 0) {
		if (source.sin_family == AF_INET &&
		    source.sin_addr.s_addr == transport->peer.sin_addr.s_addr) {
			transport->peer.sin_port = source.sin_port;
			result = receive_audio(transport, packet, (size_t)received,
				timestamp_ms);
			if (result < 0)
				return -1;
			transferred += result;
		}
	} else if (errno != EAGAIN && errno != EWOULDBLOCK && errno != EINTR) {
		return -1;
	}
	result = send_audio(transport);
	if (result < 0)
		return -1;
	return transferred + result;
}
