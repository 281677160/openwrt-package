#include "browser_media.h"

#include <assert.h>
#include <stdint.h>
#include <string.h>

void qmodem_voip_serial_close(struct qmodem_voip_media_engine *engine)
{
	(void)engine;
}

void qmodem_voip_serial_set_attached(struct qmodem_voip_media_engine *engine,
				     int attached)
{
	(void)engine;
	(void)attached;
}

static int all_zero(const uint8_t *data, size_t length)
{
	while (length--)
		if (*data++)
			return 0;
	return 1;
}

static void write_le32(uint8_t *value, uint32_t number)
{
	value[0] = (uint8_t)number;
	value[1] = (uint8_t)(number >> 8);
	value[2] = (uint8_t)(number >> 16);
	value[3] = (uint8_t)(number >> 24);
}

int main(int argc, char **argv)
{
	struct qmodem_voip_browser_media browser;
	struct qmodem_voip_media_engine engine;
	uint8_t frame[QMODEM_VOIP_BROWSER_FRAME_SIZE] = { 0 };
	size_t certificate_length;
	size_t key_length;

	assert(argc == 1);
	(void)argv;
	memset(&browser, 0, sizeof(browser));
	memset(&engine, 0, sizeof(engine));
	assert(qmodem_voip_browser_configure(&browser, &engine, "192.0.2.1",
		NULL, NULL) == 0);
	certificate_length = browser.certificate_length;
	key_length = browser.key_length;
	assert(certificate_length == 0);
	assert(key_length == 0);
	write_le32(frame, QMODEM_VOIP_BROWSER_MAGIC);
	frame[4] = QMODEM_VOIP_BROWSER_VERSION;
	frame[5] = QMODEM_VOIP_BROWSER_FORMAT_S16LE;
	frame[6] = 1;
	write_le32(frame + 8, QMODEM_VOIP_BROWSER_RATE);
	write_le32(frame + 12, 1);
	write_le32(frame + 16, 10);
	write_le32(frame + 20, QMODEM_VOIP_BROWSER_FRAME_SAMPLES);
	frame[24] = 0xe8;
	frame[25] = 0x03;
	browser.ready = 1;
	browser.attached = 1;
	assert(qmodem_voip_browser_media_receive(&browser, frame, sizeof(frame)) == 0);
	assert(browser.uplink_frames == 1);
	assert(browser.uplink_non_silent_frames == 1);
	assert(browser.uplink_peak == 1000);

	qmodem_voip_browser_media_stop(&browser);
	assert(browser.certificate_length == certificate_length);
	assert(browser.key_length == key_length);
	assert(all_zero(browser.certificate_data, sizeof(browser.certificate_data)));
	assert(all_zero(browser.key_data, sizeof(browser.key_data)));

	qmodem_voip_browser_media_release(&browser);
	assert(browser.certificate_length == 0);
	assert(browser.key_length == 0);
	assert(all_zero(browser.certificate_data, sizeof(browser.certificate_data)));
	assert(all_zero(browser.key_data, sizeof(browser.key_data)));
	return 0;
}
