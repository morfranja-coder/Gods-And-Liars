class_name BotModelAssets
extends RefCounted


static func model_root() -> String:
	var shipped := OS.get_executable_path().get_base_dir().path_join("ai_models")
	if FileAccess.file_exists(shipped.path_join("qwen-debate.gguf")):
		return shipped
	return ProjectSettings.globalize_path("res://.tools/bot-models")
