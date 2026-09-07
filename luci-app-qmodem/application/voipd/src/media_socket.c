#define _POSIX_C_SOURCE 200809L

#include "media_socket.h"
#include "daemon_core.h"

#include <errno.h>
#include <fcntl.h>
#include <libgen.h>
#include <sys/stat.h>
#include <string.h>
#include <sys/socket.h>
#include <sys/un.h>
#include <syslog.h>
#include <unistd.h>

/* A DATAGRAM-LIKE SOCK_SEQPACKET unix socket carries one media or control frame
   per message. This is a host-local channel, so control integers and PCM samples
   both travel in native (little-endian on aarch64) byte order. */

static uint64_t session_hash(const char *session)
{
	uint64_t hash = 1469598103934665603ULL;
	unsigned char byte;

	if (!session)
		return 0;
	while ((byte = (unsigned char)*session++)) {
		hash ^= byte;
		hash *= 1099511628211ULL;
	}
	return hash ? hash : 1U;
}

static int random_bytes(uint8_t *output, size_t length)
{
	size_t done = 0;
	ssize_t received;
	int file;

	if (!output || !length)
		return -1;
	file = open("/dev/urandom", O_RDONLY | O_CLOEXEC);
	if (file < 0)
		return -1;
	while (done < length) {
		received = read(file, output + done, length - done);
		if (received < 0 && errno == EINTR)
			continue;
		if (received <= 0) {
			(void)close(file);
			memset(output, 0, length);
			return -1;
		}
		done += (size_t)received;
	}
	(void)close(file);
	return 0;
}

static const char session_alphabet[] =
	"0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ";

static void session_generate_id(char id[QMODEM_VOIP_MEDIA_SOCKET_SESSION_ID_MAX])
{
	uint8_t random[QMODEM_VOIP_MEDIA_SOCKET_SESSION_ID_MAX];
	size_t i;

	if (random_bytes(random, sizeof(random)) == 0) {
		for (i = 0; i < QMODEM_VOIP_MEDIA_SOCKET_SESSION_ID_MAX; i++)
			id[i] = session_alphabet[random[i] %
				(sizeof(session_alphabet) - 1U)];
		id[QMODEM_VOIP_MEDIA_SOCKET_SESSION_ID_MAX - 1U] = '\0';
		memset(random, 0, sizeof(random));
	} else {
		memset(id, 0, QMODEM_VOIP_MEDIA_SOCKET_SESSION_ID_MAX);
	}
}

static void session_expire(struct qmodem_voip_media_socket *socket, uint64_t now)
{
	struct qmodem_voip_media_socket_session *session;
	size_t i;

	for (i = 0; i < QMODEM_VOIP_MEDIA_SOCKET_SESSION_SLOTS; i++) {
		session = &socket->sessions[i];
		if (session->active && now >= session->expires_at) {
			memset(session, 0, sizeof(*session));
			session->active = 0;
		}
	}
}

static int send_message(struct qmodem_voip_media_socket *socket, int peer_fd,
			enum qmodem_voip_media_socket_frame_type type,
			const void *payload, size_t payload_length)
{
	struct qmodem_voip_media_socket_header header;
	uint8_t buffer[QMODEM_VOIP_MEDIA_SOCKET_PATH_MAX +
		       QMODEM_VOIP_MEDIA_SOCKET_FRAME_SAMPLES * 2U];
	size_t used = 0;

	if ((size_t)payload_length > sizeof(buffer) - sizeof(header))
		return -1;
	header.magic = QMODEM_VOIP_MEDIA_SOCKET_MAGIC;
	header.version = QMODEM_VOIP_MEDIA_SOCKET_VERSION;
	header.type = (uint16_t)type;
	header.payload_length = (uint32_t)payload_length;
	memcpy(buffer + used, &header, sizeof(header));
	used += sizeof(header);
	if (payload_length) {
		memcpy(buffer + used, payload, payload_length);
		used += payload_length;
	}
	(void)socket;
	if (send(peer_fd, buffer, used, 0) != (ssize_t)used)
		return -1;
	memset(buffer, 0, used);
	return 0;
}

static int nonblocking(int fd)
{
	int flags = fcntl(fd, F_GETFL);
	return flags < 0 || fcntl(fd, F_SETFL, flags | O_NONBLOCK) < 0 ? -1 : 0;
}

static void channel_peer(struct uloop_fd *fd_event, unsigned events)
{
	struct qmodem_voip_media_socket_peer *peer =
		container_of(fd_event, struct qmodem_voip_media_socket_peer, fd_event);
	struct qmodem_voip_media_socket *socket = peer->owner;
	struct qmodem_voip_context *app = socket->context;
	struct qmodem_voip_media_socket_message message;
	struct qmodem_voip_media_socket_attach attach;
	struct qmodem_voip_media_socket_pcm pcm;

	(void)events;
	for (;;) {
		int received = recv(peer->fd, (uint8_t *)&message, sizeof(message), 0);
		if (received < 0) {
			if (errno == EINTR)
				continue;
			if (errno == EAGAIN || errno == EWOULDBLOCK)
				return;
			break;
		}
		if (received == 0) { /* orderly close */
			if (peer->attached)
				qmodem_voip_media_detach(socket->engine);
			uloop_fd_delete(fd_event);
			(void)close(peer->fd);
			peer->fd = -1;
			peer->attached = 0;
			return;
		}
		if (message.header.magic != QMODEM_VOIP_MEDIA_SOCKET_MAGIC ||
		    message.header.version != QMODEM_VOIP_MEDIA_SOCKET_VERSION ||
		    message.header.payload_length !=
			    (uint32_t)(received - (int)sizeof(message.header))) {
			if (peer->attached)
				qmodem_voip_media_detach(socket->engine);
			uloop_fd_delete(fd_event);
			(void)close(peer->fd);
			peer->fd = -1;
			peer->attached = 0;
			return;
		}
		switch (message.header.type) {
	case QMODEM_VOIP_MEDIA_SOCKET_ATTACH:
		if (peer->attached)
			return;
		memset(&attach, 0, sizeof(attach));
		if (message.header.payload_length != sizeof(attach))
			return;
		memcpy(&attach, &message.body.attach, sizeof(attach));
		attach.session_id[sizeof(attach.session_id) - 1U] = '\0';
		if (attach.call_revision != app->call.revision) {
			syslog(LOG_WARNING,
				"qmodem_voip media socket: stale revision %llu current %llu",
				(unsigned long long)attach.call_revision,
				(unsigned long long)app->call.revision);
			(void)send_message(socket, peer->fd,
				QMODEM_VOIP_MEDIA_SOCKET_ERROR, NULL, 0);
			return;
		}
		if (!qmodem_voip_media_socket_session_valid(socket,
			attach.session_id, attach.call_revision,
			(uint64_t)time(NULL)) &&
		    !qmodem_voip_session_is_authorized(attach.session_id)) {
			syslog(LOG_WARNING,
				"qmodem_voip media socket: session rejected for revision %llu",
				(unsigned long long)attach.call_revision);
			(void)send_message(socket, peer->fd,
				QMODEM_VOIP_MEDIA_SOCKET_ERROR, NULL, 0);
			return;
		}
		if (qmodem_voip_media_attach(socket->engine,
			QMODEM_VOIP_MEDIA_ATTACH_SOCKET,
			session_hash(attach.session_id)) != 0) {
			syslog(LOG_WARNING,
				"qmodem_voip media socket: media owner conflict at revision %llu",
				(unsigned long long)attach.call_revision);
			(void)send_message(socket, peer->fd,
				QMODEM_VOIP_MEDIA_SOCKET_ERROR, NULL, 0);
			return;
		}
		peer->attached = 1;
		peer->call_revision = attach.call_revision;
		peer->outbound_sequence = 0;
		peer->dropped = 0;
		{
			struct { uint32_t state; uint32_t revision; } now;
			now.state = (uint32_t)app->call.state;
			now.revision = (uint32_t)app->call.revision;
			(void)send_message(socket, peer->fd,
				QMODEM_VOIP_MEDIA_SOCKET_STATE_CHANGE,
				&now, sizeof(now));
		}
		return;
	case QMODEM_VOIP_MEDIA_SOCKET_DETACH:
		if (!peer->attached)
			return;
		peer->attached = 0;
		qmodem_voip_media_detach(socket->engine);
		return;
	case QMODEM_VOIP_MEDIA_SOCKET_HEARTBEAT:
		return;
	case QMODEM_VOIP_MEDIA_SOCKET_PCM_PLAYBACK:
		if (!peer->attached ||
		    message.header.payload_length != sizeof(pcm))
			return;
		memcpy(&pcm, &message.body.pcm, sizeof(pcm));
		if (qmodem_voip_media_queue_push(&socket->engine->canonical_to_modem,
			pcm.samples, QMODEM_VOIP_MEDIA_SOCKET_FRAME_SAMPLES,
			pcm.timestamp_ms) != 0)
			(void)send_message(socket, peer->fd,
				QMODEM_VOIP_MEDIA_SOCKET_ERROR, NULL, 0);
		memset(&pcm, 0, sizeof(pcm));
		return;
	default:
		(void)send_message(socket, peer->fd,
			QMODEM_VOIP_MEDIA_SOCKET_ERROR, NULL, 0);
		return;
	}
	}
}

static void channel_accept(struct uloop_fd *listener, unsigned events)
{
	struct qmodem_voip_media_socket *socket =
		container_of(listener, struct qmodem_voip_media_socket, listener);
	struct qmodem_voip_media_socket_peer *peer;
	int i;

	(void)events;
	if (!socket)
		return;
	peer = NULL;
	for (i = 0; i < (int)QMODEM_VOIP_MEDIA_SOCKET_PEERS; i++) {
		if (socket->peers[i].fd < 0) {
			peer = &socket->peers[i];
			break;
		}
	}
	if (!peer)
		return;
	peer->fd = accept(socket->listener.fd, NULL, NULL);
	if (peer->fd < 0 || nonblocking(peer->fd) != 0)
		return;
	peer->owner = socket;
	peer->attached = 0;
	peer->fd_event.cb = channel_peer;
	peer->fd_event.fd = peer->fd;
	uloop_fd_add(&peer->fd_event, ULOOP_READ);
}

int qmodem_voip_media_socket_service(struct qmodem_voip_media_socket *socket,
				     uint64_t timestamp_ms)
{
	struct qmodem_voip_media_socket_peer *peer;
	struct qmodem_voip_media_socket_pcm pcm;
	struct qmodem_voip_media_frame frame;
	int i;

	if (!socket || !socket->running || !socket->engine)
		return 0;
	/* Only the single most recently attached peer receives the modem stream. */
	for (i = 0; i < (int)QMODEM_VOIP_MEDIA_SOCKET_PEERS; i++) {
		peer = &socket->peers[i];
		if (!peer->attached || peer->fd < 0)
			continue;
		if (!socket->engine->modem_to_canonical.count)
			break;
		if (qmodem_voip_media_queue_pop(&socket->engine->modem_to_canonical,
			&frame) != 0)
			return -1;
		memset(&pcm, 0, sizeof(pcm));
		pcm.sequence = peer->outbound_sequence++;
		pcm.timestamp_ms = (uint32_t)frame.timestamp_ms;
		memcpy(pcm.samples, frame.samples, sizeof(pcm.samples));
		if (send_message(socket, peer->fd,
			QMODEM_VOIP_MEDIA_SOCKET_PCM_CAPTURE, &pcm, sizeof(pcm)) != 0)
			peer->dropped++;
		memset(&frame, 0, sizeof(frame));
		memset(&pcm, 0, sizeof(pcm));
		break;
	}
	(void)timestamp_ms;
	return 0;
}

int qmodem_voip_media_socket_session_valid(struct qmodem_voip_media_socket *socket,
					   const char *id, uint64_t call_revision,
					   uint64_t now)
{
	struct qmodem_voip_media_socket_session *session;
	size_t i;

	if (!socket || !id || !id[0])
		return 0;
	session_expire(socket, now);
	for (i = 0; i < QMODEM_VOIP_MEDIA_SOCKET_SESSION_SLOTS; i++) {
		session = &socket->sessions[i];
		if (session->active && session->call_revision == call_revision &&
		    strncmp(session->id, id, sizeof(session->id)) == 0)
			return 1;
	}
	return 0;
}

int qmodem_voip_media_socket_session_issue(struct qmodem_voip_media_socket *socket,
					   uint64_t call_revision, uint64_t now,
					   char id[QMODEM_VOIP_MEDIA_SOCKET_SESSION_ID_MAX])
{
	struct qmodem_voip_media_socket_session *session = NULL;
	char candidate[QMODEM_VOIP_MEDIA_SOCKET_SESSION_ID_MAX];
	size_t i;

	if (!socket || !id || !call_revision)
		return -1;
	session_expire(socket, now);
	session_generate_id(candidate);
	if (!candidate[0])
		return -1;
	for (i = 0; i < QMODEM_VOIP_MEDIA_SOCKET_SESSION_SLOTS; i++) {
		if (!socket->sessions[i].active) {
			session = &socket->sessions[i];
			break;
		}
	}
	if (!session) {
		session = &socket->sessions[0];
		for (i = 1; i < QMODEM_VOIP_MEDIA_SOCKET_SESSION_SLOTS; i++)
			if (socket->sessions[i].expires_at < session->expires_at)
				session = &socket->sessions[i];
		memset(session, 0, sizeof(*session));
	}
	memcpy(session->id, candidate, sizeof(session->id));
	session->call_revision = call_revision;
	session->expires_at = now + QMODEM_VOIP_MEDIA_SOCKET_SESSION_TTL;
	session->active = 1;
	memset(id, 0, QMODEM_VOIP_MEDIA_SOCKET_SESSION_ID_MAX);
	memcpy(id, session->id, sizeof(session->id));
	memset(candidate, 0, sizeof(candidate));
	return 0;
}

int qmodem_voip_media_socket_start(struct qmodem_voip_media_socket *server,
				   struct qmodem_voip_media_engine *engine,
				   void *context, const char *path)
{
	struct sockaddr_un address = { 0 };
	char directory[QMODEM_VOIP_MEDIA_SOCKET_PATH_MAX];
	int fd;
	int i;

	if (!server || !engine || !context || !path || !path[0] ||
	    strlen(path) >= sizeof(address.sun_path))
		return -1;
	/* The socket directory may not survive as a packaged directory (var/run
	   is a tmp symlink on the target), so create it at bind time. */
	(void)snprintf(directory, sizeof(directory), "%s", path);
	(void)dirname(directory);
	if (directory[0] && mkdir(directory, 0700) != 0 && errno != EEXIST)
		return -1;
	memset(server, 0, sizeof(*server));
	server->engine = engine;
	server->context = context;
	for (i = 0; i < (int)QMODEM_VOIP_MEDIA_SOCKET_PEERS; i++)
		server->peers[i].fd = -1;
	server->listener.fd = -1;
	if (strlen(path) < sizeof(server->path))
		memcpy(server->path, path, strlen(path) + 1U);
	fd = socket(AF_UNIX, SOCK_SEQPACKET, 0);
	if (fd < 0)
		return -1;
	address.sun_family = AF_UNIX;
	memcpy(address.sun_path, path, strlen(path) + 1U);
	(void)unlink(path);
	if (nonblocking(fd) ||
	    bind(fd, (struct sockaddr *)&address, sizeof(address)) != 0 ||
	    listen(fd, (int)QMODEM_VOIP_MEDIA_SOCKET_PEERS) != 0) {
		(void)close(fd);
		return -1;
	}
	server->listener.fd = fd;
	server->listener.cb = channel_accept;
	uloop_fd_add(&server->listener, ULOOP_READ);
	server->running = 1;
	server->ready = 1;
	return 0;
}

void qmodem_voip_media_socket_stop(struct qmodem_voip_media_socket *socket)
{
	struct qmodem_voip_media_socket_peer *peer;
	int i;

	if (!socket)
		return;
	socket->running = 0;
	socket->ready = 0;
	if (socket->listener.cb) {
		uloop_fd_delete(&socket->listener);
		socket->listener.cb = NULL;
	}
	for (i = 0; i < (int)QMODEM_VOIP_MEDIA_SOCKET_PEERS; i++) {
		peer = &socket->peers[i];
		if (peer->fd >= 0) {
			if (peer->attached)
				qmodem_voip_media_detach(socket->engine);
			uloop_fd_delete(&peer->fd_event);
			(void)close(peer->fd);
			peer->fd = -1;
			peer->attached = 0;
		}
	}
	if (socket->listener.fd >= 0)
		(void)close(socket->listener.fd);
	if (socket->path[0])
		(void)unlink(socket->path);
	socket->listener.fd = -1;
	memset(socket->path, 0, sizeof(socket->path));
}

void qmodem_voip_media_socket_release(struct qmodem_voip_media_socket *socket)
{
	int attached = 0;
	int i;

	if (!socket)
		return;
	for (i = 0; i < (int)QMODEM_VOIP_MEDIA_SOCKET_PEERS; i++) {
		if (socket->peers[i].attached)
			attached = 1;
		socket->peers[i].attached = 0;
		socket->peers[i].call_revision = 0;
	}
	if (attached)
		qmodem_voip_media_detach(socket->engine);
	memset(socket->sessions, 0, sizeof(socket->sessions));
}

int qmodem_voip_media_socket_attached(
	const struct qmodem_voip_media_socket *socket)
{
	int i;

	if (!socket)
		return 0;
	for (i = 0; i < (int)QMODEM_VOIP_MEDIA_SOCKET_PEERS; i++) {
		if (socket->peers[i].attached)
			return 1;
	}
	return 0;
}
