#include "media.h"

#include <assert.h>
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

int main(void)
{
	struct qmodem_voip_media_engine engine;

	memset(&engine, 0, sizeof(engine));
	engine.profile.adb_unlock = 1;
	engine.profile.voice_server_media_gate = 1;
	engine.profile.voice_server_restart = 1;
	(void)strcpy(engine.profile.voice_server_dependency_service,
		"agm_server.service");
	(void)strcpy(engine.profile.voice_server_service,
		"quectel-voice-server.service");
	qmodem_voip_media_release(&engine);
	assert(engine.profile.adb_unlock == 1);
	assert(engine.profile.voice_server_media_gate == 1);
	assert(engine.profile.voice_server_restart == 1);
	assert(strcmp(engine.profile.voice_server_dependency_service,
		"agm_server.service") == 0);
	assert(strcmp(engine.profile.voice_server_service,
		"quectel-voice-server.service") == 0);
	return 0;
}
