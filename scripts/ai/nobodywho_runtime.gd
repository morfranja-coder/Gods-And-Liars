extends Node

var chat: RefCounted
var voices: Dictionary = {}

func initialize(model_path: String) -> bool:
	chat = await NobodyWhoChat.create(model_path, {"use_gpu": false, "n_ctx": 2048, "n_threads": 4, "template_variables": {"enable_thinking": false}, "sampler": NobodyWhoSamplerPresets.temperature(0.8)})
	return chat != null

func respond(prompt: String, contribution: String) -> String:
	var stream = chat.complete([
		{"role": "system", "content": "You write one short dialogue line for a social deduction game character. Preserve the proposed contribution and its facts. Adapt its style to the personality. Never invent events, deaths, evidence, locations or actions. Return only the dialogue line, in the requested language."},
		{"role": "user", "content": prompt + "\nRewrite this contribution in your own voice, preserving its meaning: " + contribution + " /no_think"}
	], {})
	if stream == null:
		return ""
	var result = await stream.completed()
	return str(result) if result != null else ""

func cancel() -> void:
	if chat != null:
		chat.stop_generation()

func speak(source: String, voice: String, language: String, speed: float, text: String) -> PackedByteArray:
	var key := language + voice
	if not voices.has(key):
		voices[key] = await NobodyWhoTextToSpeech.create(source, {"architecture": "kokoro", "voice": voice, "language": language, "speed": speed, "device": "cpu"})
	if voices[key] == null:
		return PackedByteArray()
	var bytes = await voices[key].synthesize(text)
	return bytes if bytes != null else PackedByteArray()
