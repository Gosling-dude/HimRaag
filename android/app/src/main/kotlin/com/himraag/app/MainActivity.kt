package com.himraag.app

import com.ryanheise.audioservice.AudioServiceActivity

// audio_service needs the activity to share its Flutter engine with the
// background service. With a plain FlutterActivity, AudioService.init() never
// completes, so the media notification and lock-screen controls never appear.
class MainActivity : AudioServiceActivity()
