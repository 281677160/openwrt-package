#ifndef QMODEM_VOIP_HOST_TEST
#include <alsa/asoundlib.h>
#include <libubox/uloop.h>
#include <libubus.h>
#include <libwebsockets.h>
#include <spandsp.h>
#include <soxr.h>
#endif
#include <pjlib.h>
#include <pjlib-util.h>
#include <pjsip.h>
#include <pjsip/sip_transport_tcp.h>
#ifndef QMODEM_VOIP_HOST_TEST
#include <libubox/blobmsg.h>
#include <libubox/uloop.h>
#include <libubus.h>
#endif
#include <signal.h>
#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <syslog.h>
#include <arpa/inet.h>
#include <ifaddrs.h>
#include <unistd.h>

#include "sip_gateway.h"
#include "sip_activation.h"

#define REALM QMODEM_VOIP_SIP_REALM
#define BINDING_SIZE 256
#define MAX_SIP_MESSAGE 4096
#define MAX_SIP_BODY 2048
#define RATE_SLOTS 32
#define UBUS_ACTION_TIMEOUT_MS 5000
#ifndef PIDFILE
#define PIDFILE "/var/run/qmodem_voip_registrar.pid"
#endif

struct registrar {
	pjsip_endpoint *endpoint;
	pjsip_auth_srv auth;
	pj_caching_pool caching_pool;
	pj_pool_t *pool;
	pjsip_module module;
	char username[QMODEM_VOIP_SIP_USERNAME_SIZE];
	char ha1[QMODEM_VOIP_SIP_HA1_SIZE];
	char challenge_nonce[QMODEM_VOIP_SIP_NONCE_SIZE];
	struct qmodem_voip_sip_nonce_store nonces;
	char binding[BINDING_SIZE];
	unsigned expires;
	pj_time_val binding_until;
#ifndef QMODEM_VOIP_HOST_TEST
	struct ubus_context *ubus;
	struct ubus_event_handler call_events;
#endif
	struct qmodem_voip_sip_rate auth_rates[RATE_SLOTS];
	struct qmodem_voip_sip_rate invite_rates[RATE_SLOTS];
	struct qmodem_voip_sip_call call;
	struct qmodem_voip_sip_media pending_media;
	uint64_t pending_media_session;
	uint64_t next_media_session;
	pjsip_tx_data *pending_lan_response;
	pjsip_response_addr pending_lan_response_addr;
	int reload_requested;
	char lan_address[16];
};

static struct registrar app;
static volatile sig_atomic_t running = 1;

#ifndef QMODEM_VOIP_HOST_TEST
static void send_incoming_invite(void);
#endif
static uint32_t source_address(pjsip_rx_data *request);

static void stop_handler(int signo)
{
	(void)signo;
	running = 0;
}

static void reload_handler(int signo)
{
	(void)signo;
	app.reload_requested = 1;
}

static int str_equal(const pj_str_t *value, const char *expected)
{
	size_t length = strlen(expected);
	return value && value->slen == (pj_ssize_t)length &&
	       memcmp(value->ptr, expected, length) == 0;
}

static pj_status_t lookup_credential(pj_pool_t *pool, const pj_str_t *realm,
				     const pj_str_t *account,
				     pjsip_cred_info *credential)
{
	(void)pool;
	if (!str_equal(realm, REALM) || !str_equal(account, app.username))
		return PJSIP_EAUTHACCNOTFOUND;
	pj_bzero(credential, sizeof(*credential));
	credential->realm = pj_str((char *)REALM);
	credential->scheme = pjsip_DIGEST_STR;
	credential->username = pj_str(app.username);
	credential->data_type = PJSIP_CRED_DATA_DIGEST;
	credential->data = pj_str(app.ha1);
	credential->algorithm_type = PJSIP_AUTH_ALGORITHM_MD5;
	return PJ_SUCCESS;
}

static int new_nonce(pjsip_rx_data *request)
{
	pj_time_val now;
	pj_gettimeofday(&now);
	return qmodem_voip_sip_nonce_issue(&app.nonces, source_address(request),
		(uint64_t)now.sec, app.challenge_nonce);
}

static uint32_t source_address(pjsip_rx_data *request)
{
	return request->pkt_info.src_addr.ipv4.sin_addr.s_addr;
}

static int rate_allow(struct qmodem_voip_sip_rate *rates, pjsip_rx_data *request,
			      unsigned limit)
{
	pj_time_val now;
	pj_gettimeofday(&now);
	return qmodem_voip_sip_rate_allow(rates, RATE_SLOTS, source_address(request),
					  (uint64_t)now.sec, limit);
}

static void add_string_header(pjsip_tx_data *response, const char *name,
			      const char *value)
{
	pj_str_t header_name = pj_str((char *)name);
	pj_str_t header_value = pj_str((char *)value);
	pjsip_generic_string_hdr *header = pjsip_generic_string_hdr_create(
		response->pool, &header_name, &header_value);
	pjsip_msg_add_hdr(response->msg, (pjsip_hdr *)header);
}

static void send_response(pjsip_rx_data *request, int status,
			  pj_bool_t challenge, pj_bool_t stale)
{
	pjsip_tx_data *response;
	pj_status_t rc = pjsip_endpt_create_response(app.endpoint, request, status,
						NULL, &response);
	if (rc != PJ_SUCCESS)
		return;
	if (challenge) {
		pj_str_t qop = pj_str((char *)"auth");
		pj_str_t nonce = pj_str(app.challenge_nonce);
		(void)pjsip_auth_srv_challenge(&app.auth, &qop, &nonce, NULL,
					       stale, response);
	}
	(void)pjsip_endpt_send_response2(app.endpoint, request, response, NULL, NULL);
}

static pjsip_authorization_hdr *authorization(pjsip_rx_data *request)
{
	return (pjsip_authorization_hdr *)pjsip_msg_find_hdr(
		request->msg_info.msg, PJSIP_H_AUTHORIZATION, NULL);
}

static int nonce_check(pjsip_rx_data *request, pjsip_authorization_hdr *header,
		       unsigned long *nc, struct qmodem_voip_sip_nonce **accepted)
{
	pj_time_val now;
	char nc_text[9];
	char *end;
	char nonce[QMODEM_VOIP_SIP_NONCE_SIZE];
	if (!header || !str_equal(&header->credential.digest.qop, "auth") ||
	    header->credential.digest.nonce.slen != 32 ||
	    header->credential.digest.nc.slen != 8)
		return 0;
	memcpy(nonce, header->credential.digest.nonce.ptr, 32);
	nonce[32] = '\0';
	pj_gettimeofday(&now);
	memcpy(nc_text, header->credential.digest.nc.ptr, 8);
	nc_text[8] = '\0';
	errno = 0;
	*nc = strtoul(nc_text, &end, 16);
	return errno == 0 && *end == '\0' &&
		qmodem_voip_sip_nonce_check(&app.nonces, source_address(request),
			nonce, (uint64_t)now.sec, *nc, accepted) ==
		QMODEM_VOIP_SIP_NONCE_OK;
}

static int authenticate(pjsip_rx_data *request)
{
	pjsip_authorization_hdr *header = authorization(request);
	struct qmodem_voip_sip_nonce *accepted = NULL;
	unsigned long nc = 0;
	int status = PJSIP_SC_FORBIDDEN;
	if (!header) {
		if (!rate_allow(app.auth_rates, request, 10)) {
			send_response(request, PJSIP_SC_FORBIDDEN, PJ_FALSE, PJ_FALSE);
			return 0;
		}
		if (new_nonce(request) != 0) {
			send_response(request, PJSIP_SC_SERVICE_UNAVAILABLE, PJ_FALSE, PJ_FALSE);
			return 0;
		}
		send_response(request, PJSIP_SC_UNAUTHORIZED, PJ_TRUE, PJ_FALSE);
		return 0;
	}
	if (!nonce_check(request, header, &nc, &accepted)) {
		if (!rate_allow(app.auth_rates, request, 10)) {
			send_response(request, PJSIP_SC_FORBIDDEN, PJ_FALSE, PJ_FALSE);
			return 0;
		}
		if (new_nonce(request) != 0) {
			send_response(request, PJSIP_SC_SERVICE_UNAVAILABLE, PJ_FALSE, PJ_FALSE);
			return 0;
		}
		send_response(request, PJSIP_SC_UNAUTHORIZED, PJ_TRUE, PJ_TRUE);
		return 0;
	}
	if (pjsip_auth_srv_verify(&app.auth, request, &status) != PJ_SUCCESS) {
		if (!rate_allow(app.auth_rates, request, 10)) {
			send_response(request, PJSIP_SC_FORBIDDEN, PJ_FALSE, PJ_FALSE);
			return 0;
		}
		send_response(request, status, PJ_FALSE, PJ_FALSE);
		return 0;
	}
	qmodem_voip_sip_nonce_commit(accepted, nc);
	return 1;
}

static unsigned request_expiry(pjsip_msg *message, pjsip_contact_hdr *contact)
{
	pjsip_expires_hdr *expires;
	long value = contact->expires;
	if (value == PJSIP_EXPIRES_NOT_SPECIFIED) {
		expires = (pjsip_expires_hdr *)pjsip_msg_find_hdr(
			message, PJSIP_H_EXPIRES, NULL);
		value = expires ? expires->ivalue : 3600;
	}
	if (value == 0)
		return 0;
	if (value < 60)
		return 60;
	if (value > 3600)
		return 3600;
	return (unsigned)value;
}

static void register_contact(pjsip_rx_data *request)
{
	pjsip_msg *message = request->msg_info.msg;
	pjsip_contact_hdr *contact;
	pjsip_tx_data *response;
	char expiry[16];
	unsigned requested;
	if (!authenticate(request))
		return;
	contact = (pjsip_contact_hdr *)pjsip_msg_find_hdr(message,
							 PJSIP_H_CONTACT, NULL);
	if (!contact || contact->star) {
		send_response(request, PJSIP_SC_BAD_REQUEST, PJ_FALSE, PJ_FALSE);
		return;
	}
	requested = request_expiry(message, contact);
	if (requested == 0) {
		app.binding[0] = '\0';
		app.expires = 0;
		app.binding_until.sec = 0;
	} else {
		int length = pjsip_uri_print(PJSIP_URI_IN_CONTACT_HDR, contact->uri,
					     app.binding, sizeof(app.binding) - 1);
		if (length < 0) {
			send_response(request, PJSIP_SC_BAD_REQUEST, PJ_FALSE, PJ_FALSE);
			return;
		}
		app.binding[length] = '\0';
		app.expires = requested;
		pj_gettimeofday(&app.binding_until);
		app.binding_until.sec += (long)requested;
	}
	if (pjsip_endpt_create_response(app.endpoint, request, PJSIP_SC_OK, NULL,
					&response) != PJ_SUCCESS)
		return;
	(void)snprintf(expiry, sizeof(expiry), "%u", app.expires);
	add_string_header(response, "X-QModem-Expires", expiry);
	add_string_header(response, "X-QModem-Binding",
			  app.binding[0] ? app.binding : "none");
	(void)pjsip_endpt_send_response2(app.endpoint, request, response, NULL, NULL);
}

static int binding_active(void)
{
	pj_time_val now;
	pj_gettimeofday(&now);
	return app.binding[0] && now.sec < app.binding_until.sec;
}

static int sip_number(pjsip_rx_data *request, char number[64])
{
	pjsip_sip_uri *uri = (pjsip_sip_uri *)pjsip_uri_get_uri(
		request->msg_info.msg->line.req.uri);
	pj_ssize_t length;
	if (!uri || !uri->user.ptr || uri->user.slen <= 0 || uri->user.slen >= 64)
		return -1;
	length = uri->user.slen;
	memcpy(number, uri->user.ptr, (size_t)length);
	number[length] = '\0';
	return strspn(number, "0123456789+*#,p") == (size_t)length ? 0 : -1;
}

static int ubus_action(const char *action, const char *number)
{
#ifdef QMODEM_VOIP_HOST_TEST
	const char *journal = getenv("QMODEM_VOIP_ACTION_JOURNAL");
	FILE *file;
	(void)number;
	if (!journal)
		return -1;
	file = fopen(journal, "a");
	if (!file)
		return -1;
	if (fprintf(file, "%s\n", action) < 0) {
		(void)fclose(file);
		return -1;
	}
	if (fclose(file) != 0)
		return -1;
	return 0;
#else
	struct blob_buf buffer = { 0 };
	uint32_t object;
	int result;
	if (!app.ubus || ubus_lookup_id(app.ubus, "qmodem_voip", &object) != 0)
		return -1;
	blob_buf_init(&buffer, 0);
	blobmsg_add_string(&buffer, "endpoint", "lan_sip");
	if (number)
		blobmsg_add_string(&buffer, "number", number);
	result = ubus_invoke(app.ubus, object, action, buffer.head, NULL, NULL,
			     UBUS_ACTION_TIMEOUT_MS);
	blob_buf_free(&buffer);
	return result == 0 ? 0 : -1;
#endif
}

static int ubus_media_action(const char *action,
			     const struct qmodem_voip_sip_media *media,
			     uint64_t session_id)
{
#ifdef QMODEM_VOIP_HOST_TEST
	return ubus_action(action, NULL);
#else
	struct blob_buf buffer = { 0 };
	uint32_t object;
	int result;
	if (!app.ubus || ubus_lookup_id(app.ubus, "qmodem_voip", &object) != 0)
		return -1;
	blob_buf_init(&buffer, 0);
	if (media) {
		blobmsg_add_string(&buffer, "address", media->address);
		blobmsg_add_u32(&buffer, "port", media->port);
		blobmsg_add_u32(&buffer, "payload_type", media->payload_type);
		blobmsg_add_u64(&buffer, "session_id", session_id);
	}
	result = ubus_invoke(app.ubus, object, action, buffer.head, NULL, NULL,
		UBUS_ACTION_TIMEOUT_MS);
	blob_buf_free(&buffer);
	return result == 0 ? 0 : -1;
#endif
}

#ifndef QMODEM_VOIP_HOST_TEST
static void media_status(struct ubus_request *request, int type, struct blob_attr *message)
{
	static const struct blobmsg_policy policy[] = {
		{ .name = "media_engine", .type = BLOBMSG_TYPE_STRING }
	};
	struct blob_attr *values[ARRAY_SIZE(policy)] = { 0 };
	int *ready = request ? request->priv : NULL;
	(void)type;
	blobmsg_parse(policy, ARRAY_SIZE(policy), values, blob_data(message), blob_len(message));
	if (values[0] && strcmp(blobmsg_get_string(values[0]), "ready") == 0)
		*ready = 1;
}

static int media_ready(void)
{
	struct blob_buf buffer = { 0 };
	uint32_t object;
	int ready = 0;
	if (!app.ubus || ubus_lookup_id(app.ubus, "qmodem_voip", &object) != 0)
		return 0;
	blob_buf_init(&buffer, 0);
	if (ubus_invoke(app.ubus, object, "status", buffer.head, media_status, &ready, 1000) != 0)
		ready = 0;
	blob_buf_free(&buffer);
	return ready;
}
#else
static int media_ready(void)
{
	return 1;
}
#endif

static int supported_sdp(pjsip_rx_data *request,
			 struct qmodem_voip_sip_media *media)
{
	pjsip_msg_body *body = request->msg_info.msg->body;
	if (!body)
		return -1;
	if (body->len > MAX_SIP_BODY)
		return -1;
	return qmodem_voip_sip_parse_media((const char *)body->data, body->len,
		media);
}

static int copy_pj_string(char *output, size_t size, const pj_str_t *value)
{
	if (!output || !size || !value || value->slen <= 0 ||
	    value->slen >= (pj_ssize_t)size)
		return -1;
	memcpy(output, value->ptr, (size_t)value->slen);
	output[value->slen] = '\0';
	return 0;
}

static int request_identity(pjsip_rx_data *request, char *call_id,
			    size_t call_id_size, char *remote_tag,
			    size_t remote_tag_size, char *branch,
			    size_t branch_size, unsigned *cseq)
{
	if (!request->msg_info.cid || !request->msg_info.from ||
	    !request->msg_info.cseq || !request->msg_info.via ||
	    request->msg_info.cseq->cseq < 0 ||
	    copy_pj_string(call_id, call_id_size, &request->msg_info.cid->id) != 0 ||
	    copy_pj_string(remote_tag, remote_tag_size,
		&request->msg_info.from->tag) != 0 ||
	    copy_pj_string(branch, branch_size,
		&request->msg_info.via->branch_param) != 0)
		return -1;
	*cseq = (unsigned)request->msg_info.cseq->cseq;
	return 0;
}

static int set_lan_answer(pjsip_rx_data *request, pjsip_tx_data *response,
			  unsigned payload_type)
{
	pjsip_sip_uri *uri;
	pj_str_t type = pj_str((char *)"application");
	pj_str_t subtype = pj_str((char *)"sdp");
	pj_str_t text;
	pjsip_to_hdr *to;
	pjsip_contact_hdr *contact;
	pjsip_uri *parsed_contact;
	char address[INET_ADDRSTRLEN];
	char body[512];
	char contact_value[64];
	struct in_addr parsed;
	const char *payloads;
	const char *rtpmap;
	int length;
	if (payload_type == 8U) {
		payloads = "8 101";
		rtpmap = "a=rtpmap:8 PCMA/8000\r\n";
	} else if (payload_type == 0U) {
		payloads = "0 101";
		rtpmap = "a=rtpmap:0 PCMU/8000\r\n";
	} else {
		return -1;
	}
	uri = (pjsip_sip_uri *)pjsip_uri_get_uri(request->msg_info.msg->line.req.uri);
	if (!uri || uri->host.slen <= 0 || uri->host.slen >= (pj_ssize_t)sizeof(address))
		return -1;
	memcpy(address, uri->host.ptr, (size_t)uri->host.slen);
	address[uri->host.slen] = '\0';
	if (inet_pton(AF_INET, address, &parsed) != 1)
		return -1;
	length = snprintf(body, sizeof(body),
		"v=0\r\no=qmodem_voip 1 1 IN IP4 %s\r\ns=QModem VoIP\r\n"
		"c=IN IP4 %s\r\nt=0 0\r\nm=audio 40000 RTP/AVP %s\r\n%s"
		"a=rtpmap:101 telephone-event/8000\r\na=sendrecv\r\n",
		address, address, payloads, rtpmap);
	if (length < 0 || length >= (int)sizeof(body))
		return -1;
	to = (pjsip_to_hdr *)pjsip_msg_find_hdr(response->msg, PJSIP_H_TO, NULL);
	if (!to)
		return -1;
	pj_create_unique_string(response->pool, &to->tag);
	length = snprintf(contact_value, sizeof(contact_value), "sip:qmodem_voip@%s:5060", address);
	if (length < 0 || length >= (int)sizeof(contact_value))
		return -1;
	contact = pjsip_contact_hdr_create(response->pool);
	parsed_contact = pjsip_parse_uri(response->pool, contact_value, length, 0);
	if (!parsed_contact)
		return -1;
	contact->uri = (pjsip_uri *)pjsip_uri_clone(response->pool, parsed_contact);
	if (!contact->uri)
		return -1;
	pjsip_msg_add_hdr(response->msg, (pjsip_hdr *)contact);
	text = pj_str(body);
	response->msg->body = pjsip_msg_body_create(response->pool, &type, &subtype, &text);
	return response->msg->body ? 0 : -1;
}

static void invite_call(pjsip_rx_data *request)
{
	char number[64];
	char call_id[QMODEM_VOIP_SIP_CALL_ID_SIZE];
	char remote_tag[QMODEM_VOIP_SIP_TAG_SIZE];
	char branch[QMODEM_VOIP_SIP_BRANCH_SIZE];
	struct qmodem_voip_sip_media media;
	unsigned cseq;
	pjsip_tx_data *response = NULL;
	if (!rate_allow(app.invite_rates, request, 5)) {
		syslog(LOG_WARNING, "qmodem_voip sip: invite rate limit");
		send_response(request, PJSIP_SC_SERVICE_UNAVAILABLE, PJ_FALSE, PJ_FALSE);
		return;
	}
	if (!authenticate(request))
		return;
	if (supported_sdp(request, &media) != 0) {
		send_response(request, PJSIP_SC_NOT_ACCEPTABLE_HERE, PJ_FALSE, PJ_FALSE);
		return;
	}
	if (!binding_active() || app.call.active) {
		send_response(request, PJSIP_SC_BUSY_HERE, PJ_FALSE, PJ_FALSE);
		return;
	}
	if (!media_ready()) {
		syslog(LOG_WARNING, "qmodem_voip sip: media unavailable");
		send_response(request, PJSIP_SC_SERVICE_UNAVAILABLE, PJ_FALSE, PJ_FALSE);
		return;
	}
	if (sip_number(request, number) != 0 ||
	    request_identity(request, call_id, sizeof(call_id), remote_tag,
		    sizeof(remote_tag), branch, sizeof(branch), &cseq) != 0) {
		send_response(request, PJSIP_SC_NOT_ACCEPTABLE_HERE, PJ_FALSE, PJ_FALSE);
		return;
	}
	if (ubus_action("originate", number) != 0) {
		syslog(LOG_WARNING, "qmodem_voip sip: cellular originate rejected");
		send_response(request, PJSIP_SC_SERVICE_UNAVAILABLE, PJ_FALSE, PJ_FALSE);
		return;
	}
	if (qmodem_voip_sip_call_begin(&app.call, QMODEM_VOIP_SIP_CALL_LAN,
			call_id, remote_tag, branch, cseq) != 0) {
		(void)ubus_action("hangup", NULL);
		syslog(LOG_WARNING, "qmodem_voip sip: call record rejected");
		send_response(request, PJSIP_SC_SERVICE_UNAVAILABLE, PJ_FALSE, PJ_FALSE);
		return;
	}
	app.next_media_session++;
	if (!app.next_media_session)
		app.next_media_session++;
	app.pending_media = media;
	app.pending_media_session = app.next_media_session;
	if (ubus_media_action("attach_rtp", &app.pending_media,
		app.pending_media_session) != 0 ||
	    pjsip_endpt_create_response(app.endpoint, request, PJSIP_SC_OK, NULL,
				       &response) != PJ_SUCCESS ||
	    set_lan_answer(request, response, media.payload_type) != 0 ||
	    pjsip_get_response_addr(app.pool, request, &app.pending_lan_response_addr) != PJ_SUCCESS) {
		if (response)
			pjsip_tx_data_dec_ref(response);
		(void)ubus_action("hangup", NULL);
		(void)ubus_media_action("release_rtp", NULL, 0);
		qmodem_voip_sip_call_clear(&app.call);
		memset(&app.pending_media, 0, sizeof(app.pending_media));
		app.pending_media_session = 0;
		send_response(request, PJSIP_SC_SERVICE_UNAVAILABLE, PJ_FALSE, PJ_FALSE);
		return;
	}
	if (app.pending_lan_response_addr.transport)
		pjsip_transport_add_ref(app.pending_lan_response_addr.transport);
	app.pending_lan_response = response;
	send_response(request, PJSIP_SC_TRYING, PJ_FALSE, PJ_FALSE);
	send_response(request, PJSIP_SC_RINGING, PJ_FALSE, PJ_FALSE);
}

#ifndef QMODEM_VOIP_HOST_TEST
static int set_incoming_offer(pjsip_tx_data *request)
{
	pj_str_t type = pj_str((char *)"application");
	pj_str_t subtype = pj_str((char *)"sdp");
	pj_str_t text;
	char body[512];
	int length = snprintf(body, sizeof(body),
		"v=0\r\no=qmodem_voip 1 1 IN IP4 %s\r\n"
		"s=QModem VoIP\r\nc=IN IP4 %s\r\nt=0 0\r\n"
		"m=audio 40000 RTP/AVP 8 0 101\r\n"
		"a=rtpmap:8 PCMA/8000\r\na=rtpmap:0 PCMU/8000\r\n"
		"a=rtpmap:101 telephone-event/8000\r\na=sendrecv\r\n",
		app.lan_address, app.lan_address);
	if (length < 0 || length >= (int)sizeof(body))
		return -1;
	text = pj_str(body);
	request->msg->body = pjsip_msg_body_create(request->pool, &type, &subtype, &text);
	return request->msg->body ? 0 : -1;
}

static void send_incoming_invite(void)
{
	pjsip_method method;
	pjsip_tx_data *request;
	char address[64];
	pj_str_t target = pj_str(app.binding);
	pj_str_t from;
	pj_str_t to = pj_str(app.binding);
	pj_str_t contact;
	char call_id[QMODEM_VOIP_SIP_CALL_ID_SIZE];
	char pending_tag[] = "pending";
	char pending_branch[] = "pending";
	pjsip_cid_hdr *cid;
	if (!binding_active() || app.call.active)
		return;
	(void)snprintf(address, sizeof(address), "sip:cellular@%s:5060", app.lan_address);
	from = pj_str(address);
	contact = pj_str(address);
	pjsip_method_set(&method, PJSIP_INVITE_METHOD);
	if (pjsip_endpt_create_request(app.endpoint, &method, &target, &from, &to,
				      &contact, NULL, 1, NULL, &request) != PJ_SUCCESS ||
		set_incoming_offer(request) != 0)
		return;
	cid = (pjsip_cid_hdr *)pjsip_msg_find_hdr(request->msg, PJSIP_H_CALL_ID, NULL);
	if (!cid || copy_pj_string(call_id, sizeof(call_id), &cid->id) != 0 ||
	    qmodem_voip_sip_call_begin(&app.call, QMODEM_VOIP_SIP_CALL_CELLULAR,
		call_id, pending_tag, pending_branch, 1) != 0)
		return;
	if (pjsip_endpt_send_request(app.endpoint, request, 30000, NULL, NULL) != PJ_SUCCESS)
		qmodem_voip_sip_call_release(&app.call);
}
#endif

static pj_bool_t on_response(pjsip_rx_data *response)
{
	int status = response->msg_info.msg->line.status.code;
	char call_id[QMODEM_VOIP_SIP_CALL_ID_SIZE];
	if (!app.call.active || app.call.origin != QMODEM_VOIP_SIP_CALL_CELLULAR ||
	    !response->msg_info.cid ||
	    copy_pj_string(call_id, sizeof(call_id), &response->msg_info.cid->id) != 0 ||
	    strcmp(call_id, app.call.call_id) != 0)
		return PJ_FALSE;
	if (status >= 200 && status < 300) {
		char remote_tag[QMODEM_VOIP_SIP_TAG_SIZE];
		struct qmodem_voip_sip_media media;
		pjsip_msg_body *body = response->msg_info.msg->body;
		int media_attached = body && qmodem_voip_sip_parse_media(
			(const char *)body->data, body->len, &media) == 0 &&
			ubus_media_action("attach_rtp", &media, ++app.next_media_session) == 0;
		if (media_attached && ubus_action("answer", NULL) == 0 && response->msg_info.to &&
		    copy_pj_string(remote_tag, sizeof(remote_tag),
			&response->msg_info.to->tag) == 0)
			(void)qmodem_voip_sip_call_establish(&app.call, remote_tag);
		else {
			if (media_attached)
				(void)ubus_media_action("release_rtp", NULL, 0);
			(void)ubus_action("hangup", NULL);
			qmodem_voip_sip_call_release(&app.call);
		}
	} else if (status >= 300) {
		(void)ubus_action("reject", NULL);
		(void)ubus_media_action("release_rtp", NULL, 0);
		qmodem_voip_sip_call_release(&app.call);
	}
	return PJ_FALSE;
}

static int invoke_action(void *opaque)
{
	return ubus_action((const char *)opaque, NULL);
}

static void end_call(pjsip_rx_data *request, int cancel)
{
	char call_id[QMODEM_VOIP_SIP_CALL_ID_SIZE];
	char remote_tag[QMODEM_VOIP_SIP_TAG_SIZE];
	char branch[QMODEM_VOIP_SIP_BRANCH_SIZE];
	unsigned cseq;
	int status;
	if (!authenticate(request))
		return;
	if (request_identity(request, call_id, sizeof(call_id), remote_tag,
		    sizeof(remote_tag), branch, sizeof(branch), &cseq) != 0) {
		send_response(request, PJSIP_SC_BAD_REQUEST, PJ_FALSE, PJ_FALSE);
		return;
	}
	status = cancel ? qmodem_voip_sip_call_cancel(&app.call, 1, call_id,
		remote_tag, branch, cseq, invoke_action, "hangup") :
			qmodem_voip_sip_call_bye(&app.call, 1, call_id, remote_tag,
				invoke_action, "hangup");
	if (status == PJSIP_SC_OK)
		(void)ubus_media_action("release_rtp", NULL, 0);
	send_response(request, status, PJ_FALSE, PJ_FALSE);
}

static pj_bool_t on_request(pjsip_rx_data *request)
{
	pjsip_method *method = &request->msg_info.msg->line.req.method;
	if (request->msg_info.len > MAX_SIP_MESSAGE) {
		send_response(request, PJSIP_SC_REQUEST_ENTITY_TOO_LARGE, PJ_FALSE, PJ_FALSE);
		return PJ_TRUE;
	}
	if (method->id == PJSIP_REGISTER_METHOD) {
		register_contact(request);
		return PJ_TRUE;
	}
	if (method->id == PJSIP_INVITE_METHOD) {
		invite_call(request);
		return PJ_TRUE;
	}
	if (method->id == PJSIP_ACK_METHOD) {
		return PJ_TRUE;
	}
	if (method->id == PJSIP_CANCEL_METHOD) {
		end_call(request, 1);
		return PJ_TRUE;
	}
	if (method->id == PJSIP_BYE_METHOD) {
		end_call(request, 0);
		return PJ_TRUE;
	}
	send_response(request, PJSIP_SC_METHOD_NOT_ALLOWED, PJ_FALSE, PJ_FALSE);
	return PJ_TRUE;
}

static void dependency_probe(void)
{
#ifndef QMODEM_VOIP_HOST_TEST
	int ubus_status = UBUS_STATUS_OK;
	if (uloop_init() == 0)
		uloop_done();
	fprintf(stdout, "DEPENDENCIES pj=%s spandsp_crc=%u soxr=%s alsa=%s ubus=%s lws=%s\n",
		pj_get_version(), crc_itu16_calc((const uint8_t *)"qmodem", 6, 0), soxr_version(),
		snd_asoundlib_version(), ubus_strerror(ubus_status),
		lws_get_library_version());
#else
	fprintf(stdout, "DEPENDENCIES pj=%s host-test\n", pj_get_version());
#endif
}

static int load_credentials(void)
{
	struct qmodem_voip_sip_credentials credentials;
	if (qmodem_voip_sip_read_credentials(QMODEM_VOIP_SIP_CONFIG, &credentials) != 0)
		return -1;
	memcpy(app.username, credentials.username, sizeof(app.username));
	memcpy(app.ha1, credentials.ha1, sizeof(app.ha1));
	memset(&credentials, 0, sizeof(credentials));
	return 0;
}

#ifndef QMODEM_VOIP_HOST_TEST
static void registrar_event(struct ubus_context *context,
			    struct ubus_event_handler *handler, const char *type,
			    struct blob_attr *message)
{
	static const struct blobmsg_policy policy[] = {
		{ .name = "event", .type = BLOBMSG_TYPE_STRING },
		{ .name = "state", .type = BLOBMSG_TYPE_STRING }
	};
	struct blob_attr *values[ARRAY_SIZE(policy)] = { 0 };
	(void)context;
	(void)handler;
	(void)type;
	blobmsg_parse(policy, ARRAY_SIZE(policy), values, blob_data(message),
		      blob_len(message));
	if (values[0] && values[1]) {
		const char *event = blobmsg_get_string(values[0]);
		const char *state = blobmsg_get_string(values[1]);
		if (strcmp(event, "call_state") == 0 && strcmp(state, "active") == 0 &&
		    app.call.active && app.call.origin == QMODEM_VOIP_SIP_CALL_LAN &&
		    app.pending_lan_response) {
			pjsip_tx_data *response = app.pending_lan_response;
			pj_status_t send_status;
			app.pending_lan_response = NULL;
			send_status = pjsip_endpt_send_response(app.endpoint,
				&app.pending_lan_response_addr, response, NULL, NULL);
			if (send_status != PJ_SUCCESS) {
				syslog(LOG_WARNING,
					"qmodem_voip sip: active response failed");
				if (send_status != PJ_SUCCESS)
					pjsip_tx_data_dec_ref(response);
				(void)ubus_media_action("release_rtp", NULL, 0);
				(void)ubus_action("hangup", NULL);
				qmodem_voip_sip_call_clear(&app.call);
			} else {
				char remote_tag[QMODEM_VOIP_SIP_TAG_SIZE];
				memcpy(remote_tag, app.call.remote_tag, sizeof(remote_tag));
				(void)qmodem_voip_sip_call_establish(&app.call, remote_tag);
				syslog(LOG_INFO, "qmodem_voip sip: active response sent");
			}
			memset(&app.pending_media, 0, sizeof(app.pending_media));
			app.pending_media_session = 0;
			if (app.pending_lan_response_addr.transport)
				pjsip_transport_dec_ref(app.pending_lan_response_addr.transport);
			memset(&app.pending_lan_response_addr, 0,
			       sizeof(app.pending_lan_response_addr));
		} else if (strcmp(event, "call_state") == 0 && strcmp(state, "active") == 0 &&
			   app.call.origin == QMODEM_VOIP_SIP_CALL_LAN) {
			syslog(LOG_WARNING, "qmodem_voip sip: active without pending response");
		} else if (strcmp(event, "release") == 0) {
			(void)ubus_media_action("release_rtp", NULL, 0);
			if (app.pending_lan_response) {
				app.pending_lan_response->msg->line.status.code = PJSIP_SC_TEMPORARILY_UNAVAILABLE;
				app.pending_lan_response->msg->line.status.reason =
					*pjsip_get_status_text(PJSIP_SC_TEMPORARILY_UNAVAILABLE);
				if (pjsip_endpt_send_response(app.endpoint, &app.pending_lan_response_addr,
						     app.pending_lan_response, NULL, NULL) != PJ_SUCCESS)
					pjsip_tx_data_dec_ref(app.pending_lan_response);
				if (app.pending_lan_response_addr.transport)
					pjsip_transport_dec_ref(app.pending_lan_response_addr.transport);
				app.pending_lan_response = NULL;
				memset(&app.pending_lan_response_addr, 0, sizeof(app.pending_lan_response_addr));
			}
			qmodem_voip_sip_call_release(&app.call);
			memset(&app.pending_media, 0, sizeof(app.pending_media));
			app.pending_media_session = 0;
		} else if (strcmp(event, "ring") == 0)
			send_incoming_invite();
	}
}
#endif

static int advertise_address_is_local_voice(const char *address)
{
#ifdef QMODEM_VOIP_HOST_TEST
	return strcmp(address, "127.0.0.1") == 0;
#else
	struct ifaddrs *interfaces;
	struct ifaddrs *entry;
	int found = 0;
	if (getifaddrs(&interfaces) != 0)
		return 0;
	for (entry = interfaces; entry; entry = entry->ifa_next) {
		char actual[INET_ADDRSTRLEN];
		if (!entry->ifa_name || !entry->ifa_addr ||
		    strcmp(entry->ifa_name, "lo") == 0 ||
		    entry->ifa_addr->sa_family != AF_INET)
			continue;
		if (inet_ntop(AF_INET,
		    &((struct sockaddr_in *)entry->ifa_addr)->sin_addr,
		    actual, sizeof(actual)) && strcmp(actual, address) == 0) {
			found = 1;
			break;
		}
	}
	freeifaddrs(interfaces);
	return found;
#endif
}

int main(int argc, char **argv)
{
	pj_sockaddr_in address;
	pj_status_t rc;
	pj_time_val delay = {0, 100};
	if (argc != 5 || strcmp(argv[1], "--listen-address") != 0 ||
	    strcmp(argv[3], "--advertise-address") != 0 ||
	    strcmp(argv[2], "0.0.0.0") != 0 ||
	    !qmodem_voip_sip_valid_lan_address(argv[4]) ||
	    !advertise_address_is_local_voice(argv[4])) {
		fprintf(stderr, "usage: %s --listen-address 0.0.0.0 --advertise-address IPV4\n", argv[0]);
		return 2;
	}
	if (load_credentials() != 0)
		return 2;
	(void)strcpy(app.lan_address, argv[4]);
	dependency_probe();
	if (pj_init() != PJ_SUCCESS || pjlib_util_init() != PJ_SUCCESS)
		return 1;
	pj_caching_pool_init(&app.caching_pool, NULL, 0);
	app.pool = pj_pool_create(&app.caching_pool.factory, "registrar", 4096, 4096, NULL);
	if (!app.pool)
		return 1;
	rc = pjsip_endpt_create(&app.caching_pool.factory, "qmodem_voip", &app.endpoint);
	if (rc != PJ_SUCCESS)
		return 1;
	app.module = (pjsip_module){
		.name = {"mod-qmodem-voip", 16},
		.id = -1,
		.priority = PJSIP_MOD_PRIORITY_APPLICATION,
		.on_rx_request = on_request,
		.on_rx_response = on_response,
	};
	if (pjsip_endpt_register_module(app.endpoint, &app.module) != PJ_SUCCESS)
		return 1;
	{
		pj_str_t realm = pj_str((char *)REALM);
		if (pjsip_auth_srv_init(app.pool, &app.auth, &realm,
					lookup_credential, 0) != PJ_SUCCESS)
			return 1;
	}
	pj_bzero(&address, sizeof(address));
	address.sin_family = pj_AF_INET();
	address.sin_port = pj_htons(5060);
	address.sin_addr = pj_inet_addr(&((pj_str_t){argv[2],
		(pj_ssize_t)strlen(argv[2])}));
	if (pjsip_udp_transport_start(app.endpoint, &address, NULL, 1, NULL) != PJ_SUCCESS)
		return 1;
	if (pjsip_tcp_transport_start(app.endpoint, &address, 1, NULL) != PJ_SUCCESS)
		return 1;
#ifndef QMODEM_VOIP_HOST_TEST
	app.ubus = ubus_connect(NULL);
	if (!app.ubus)
		return 1;
	if (uloop_init() != 0)
		return 1;
	ubus_add_uloop(app.ubus);
	app.call_events.cb = registrar_event;
	if (ubus_register_event_handler(app.ubus, &app.call_events,
				"qmodem_voip.call") != 0)
		return 1;
#endif
	signal(SIGINT, stop_handler);
	signal(SIGTERM, stop_handler);
	signal(SIGHUP, reload_handler);
	{
		FILE *pidfile = fopen(PIDFILE, "w");
		unsigned long long start;
		if (!pidfile)
			return 1;
		if (qmodem_voip_sip_process_start(getpid(), &start) != 0) {
			(void)fclose(pidfile);
			return 1;
		}
		(void)fprintf(pidfile, "%ld %llu\n", (long)getpid(), start);
		(void)fclose(pidfile);
	}
	fprintf(stdout, "READY udp,tcp=%s:5060 advertise=%s realm=%s rtp=40000-40031 media=not_ready\n",
		argv[2], app.lan_address, REALM);
	fflush(stdout);
	while (running) {
		if (app.reload_requested) {
			app.reload_requested = 0;
			(void)load_credentials();
			app.binding[0] = '\0';
			app.expires = 0;
			qmodem_voip_sip_call_release(&app.call);
		}
#ifndef QMODEM_VOIP_HOST_TEST
		(void)uloop_run_timeout(0);
#endif
		(void)pjsip_endpt_handle_events(app.endpoint, &delay);
	}
	(void)unlink(PIDFILE);
#ifndef QMODEM_VOIP_HOST_TEST
	uloop_done();
	ubus_free(app.ubus);
#endif
	pjsip_endpt_destroy(app.endpoint);
	pj_pool_release(app.pool);
	pj_caching_pool_destroy(&app.caching_pool);
	pj_shutdown();
	memset(app.ha1, 0, sizeof(app.ha1));
	return 0;
}
