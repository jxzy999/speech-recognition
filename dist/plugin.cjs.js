'use strict';

var core = require('@capacitor/core');

const SpeechRecognition = core.registerPlugin('SpeechRecognition', {
    web: () => Promise.resolve().then(function () { return web; }).then((m) => new m.SpeechRecognitionWeb()),
});

class SpeechRecognitionWeb extends core.WebPlugin {
    available() {
        throw this.unimplemented('Method not implemented on web.');
    }
    start(_options) {
        throw this.unimplemented('Method not implemented on web.');
    }
    stop() {
        throw this.unimplemented('Method not implemented on web.');
    }
    getSupportedLanguages() {
        throw this.unimplemented('Method not implemented on web.');
    }
    hasPermission() {
        throw this.unimplemented('Method not implemented on web.');
    }
    isListening() {
        throw this.unimplemented('Method not implemented on web.');
    }
    requestPermission() {
        throw this.unimplemented('Method not implemented on web.');
    }
    checkPermissions() {
        throw this.unimplemented('Method not implemented on web.');
    }
    requestPermissions() {
        throw this.unimplemented('Method not implemented on web.');
    }
}
new SpeechRecognitionWeb();

var web = /*#__PURE__*/Object.freeze({
    __proto__: null,
    SpeechRecognitionWeb: SpeechRecognitionWeb
});

exports.SpeechRecognition = SpeechRecognition;
//# sourceMappingURL=plugin.cjs.js.map
