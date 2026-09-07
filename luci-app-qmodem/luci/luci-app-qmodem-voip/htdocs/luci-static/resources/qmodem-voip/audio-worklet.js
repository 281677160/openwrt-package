'use strict';

class QModemVoipAudioProcessor extends AudioWorkletProcessor {
	constructor() {
		super();
		this.sequence = 0;
		this.samples = [];
		this.playback = [];
		this.muted = false;
		this.warnedRate = false;
		this.port.onmessage = (event) => {
			if (event.data?.type === 'mute') {
				this.muted = event.data.muted === true;
				return;
			}
			if (event.data?.type === 'pcm' && event.data.frame instanceof ArrayBuffer)
				this.queuePlayback(event.data.frame);
		};
	}

	queuePlayback(frame) {
		const view = new DataView(frame);
		if (view.byteLength < 24 || view.getUint32(0, true) !== 0x514d5650 || view.getUint32(8, true) !== 48000)
			return;
		for (let offset = 24; offset + 1 < view.byteLength; offset += 2)
			this.playback.push(view.getInt16(offset, true) / 32768);
	}

	frame(samples) {
		const frame = new ArrayBuffer(24 + samples.length * 2);
		const view = new DataView(frame);
		view.setUint32(0, 0x514d5650, true);
		view.setUint8(4, 1);
		view.setUint8(5, 1);
		view.setUint8(6, 1);
		view.setUint32(8, 48000, true);
		view.setUint32(12, this.sequence++, true);
		view.setUint32(16, Math.floor(currentTime * 1000) >>> 0, true);
		view.setUint32(20, samples.length, true);
		for (let index = 0; index < samples.length; index++)
			view.setInt16(24 + index * 2, Math.max(-32768, Math.min(32767, Math.round(samples[index] * 32767))), true);
		return frame;
	}

	process(inputs, outputs) {
		if (sampleRate !== 48000 && !this.warnedRate) {
			this.port.postMessage({ type: 'unsupported', reason: 'sample_rate' });
			this.warnedRate = true;
		}
		const input = inputs[0]?.[0] || [];
		for (const sample of input)
			this.samples.push(sample);
		while (this.samples.length >= 480) {
			const samples = this.samples.splice(0, 480);
			if (!this.muted) {
				const frame = this.frame(samples);
				this.port.postMessage({ type: 'pcm', frame }, [ frame ]);
			}
		}
		const output = outputs[0]?.[0] || [];
		for (let index = 0; index < output.length; index++)
			output[index] = this.playback.shift() || 0;
		return true;
	}
}

registerProcessor('qmodem-voip-audio', QModemVoipAudioProcessor);
