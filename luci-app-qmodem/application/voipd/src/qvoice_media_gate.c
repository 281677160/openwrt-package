/* RM520N-GL R03A03M4G starts QAHW reads before slower calls have media. */
typedef unsigned int gate_size_t;
typedef long long gate_int64_t;
typedef unsigned int gate_uint32_t;

typedef void (*qmi_indication_fn)(void *, unsigned int, void *, unsigned int,
				  void *);
typedef int (*qmi_init_fn)(void *, unsigned int, qmi_indication_fn, void *,
			   void *, unsigned int, void **);

struct qahw_buffer {
	void *buffer;
	gate_size_t size;
	gate_size_t offset;
	gate_int64_t *timestamp;
	gate_uint32_t flags;
};

typedef long (*qahw_read_fn)(void *, struct qahw_buffer *);

extern void *dlsym(void *, const char *);
extern int usleep(unsigned int);

#define GATE_RTLD_NEXT ((void *)-1L)
#define GATE_QMI_CALL_STATUS 0x2eU
#define GATE_QMI_ORIGINATING 1U
#define GATE_QMI_INCOMING 2U
#define GATE_QMI_CONVERSATION 3U
#define GATE_QMI_ALERTING 5U
#define GATE_QMI_DISCONNECTING 8U
#define GATE_QMI_END 9U
#define GATE_WAIT_STEP_US 20000U
#define GATE_WAIT_LIMIT 3000U
#define GATE_QMI_SLOTS 8U

struct qmi_slot {
	qmi_indication_fn callback;
	void *data;
};

static struct qmi_slot qmi_slots[GATE_QMI_SLOTS];
static unsigned int qmi_slot_count;
static volatile unsigned int media_ready;
static volatile unsigned int wait_pending;
static volatile unsigned int wait_consumed;

static void gated_qmi_indication(void *handle, unsigned int message_id,
				 void *buffer, unsigned int length, void *opaque)
{
	struct qmi_slot *slot = opaque;

	if (message_id == GATE_QMI_CALL_STATUS && buffer && length >= 7U) {
		const unsigned char *raw = buffer;
		unsigned int state = raw[5];

		if (raw[0] == 1U && raw[3] > 0U) {
			if (state == GATE_QMI_ORIGINATING || state == GATE_QMI_INCOMING) {
				__atomic_store_n(&media_ready, 0U, __ATOMIC_RELEASE);
				__atomic_store_n(&wait_consumed, 0U, __ATOMIC_RELEASE);
				__atomic_store_n(&wait_pending, 1U, __ATOMIC_RELEASE);
			} else if (state == GATE_QMI_CONVERSATION ||
				   state == GATE_QMI_ALERTING ||
				   state == GATE_QMI_DISCONNECTING ||
				   state == GATE_QMI_END) {
				__atomic_store_n(&media_ready, 1U, __ATOMIC_RELEASE);
			}
		}
	}
	if (slot && slot->callback)
		slot->callback(handle, message_id, buffer, length, slot->data);
}

int qmi_client_init_instance(void *service, unsigned int instance,
			     qmi_indication_fn callback, void *callback_data,
			     void *os_params, unsigned int timeout, void **handle)
{
	static qmi_init_fn real_init;
	struct qmi_slot *slot = (void *)0;
	unsigned int index;

	if (!real_init)
		real_init = (qmi_init_fn)dlsym(GATE_RTLD_NEXT,
			"qmi_client_init_instance");
	if (!real_init)
		return -1;
	index = __atomic_fetch_add(&qmi_slot_count, 1U, __ATOMIC_RELAXED);
	if (callback && index < GATE_QMI_SLOTS) {
		slot = &qmi_slots[index];
		slot->callback = callback;
		slot->data = callback_data;
	}
	return real_init(service, instance, slot ? gated_qmi_indication : callback,
			 slot ? slot : callback_data, os_params, timeout, handle);
}

long qahw_stream_read(void *stream, struct qahw_buffer *buffer)
{
	static qahw_read_fn real_read;

	if (!real_read)
		real_read = (qahw_read_fn)dlsym(GATE_RTLD_NEXT, "qahw_stream_read");
	if (!real_read)
		return -1;
	if (__atomic_load_n(&wait_pending, __ATOMIC_ACQUIRE) &&
	    !__atomic_exchange_n(&wait_consumed, 1U, __ATOMIC_ACQ_REL)) {
		unsigned int waits = 0U;

		while (!__atomic_load_n(&media_ready, __ATOMIC_ACQUIRE) &&
		       waits++ < GATE_WAIT_LIMIT)
			(void)usleep(GATE_WAIT_STEP_US);
		__atomic_store_n(&wait_pending, 0U, __ATOMIC_RELEASE);
	}
	return real_read(stream, buffer);
}
