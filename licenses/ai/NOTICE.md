# Local bot conversation runtime

Bots use local Qwen3-1.7B Q4_K_M through NobodyWho 12.0.0. Bot TTS is disabled and no Kokoro model or voice embeddings are included.

- Qwen3-1.7B, Qwen team, Apache-2.0: https://huggingface.co/Qwen/Qwen3-1.7B . Full license QWEN-APACHE-2.0.txt. Quantization source NobodyWho/Qwen_Qwen3-1.7B-GGUF, revision d7b9d0be1d21f893a1788735530329ae2416b61b.
- NobodyWho Godot 12.0.0, EUPL-1.2: https://github.com/nobodywho-ooo/nobodywho/tree/nobodywho-godot-v12.0.0 . Full license NOBODYWHO-EUPL-1.2.txt and corresponding upstream source packaged.
- llama.cpp, MIT: https://github.com/ggml-org/llama.cpp . Full license LLAMA-CPP-MIT.txt.
- The unmodified shared NobodyWho binary also contains ONNX Runtime (MIT) and espeak-ng Rust 0.2.0 phonemization/data (GPL-3.0-or-later), although this game does not call its TTS functions. Their notices and exact locked crate sources are retained: ONNXRUNTIME-MIT.txt, ESPEAK-NG-GPL-3.0.txt, assets/ai/phonemizer_manifest.json. Source: https://github.com/eugenehp/espeak-ng-rs . Copyright 2026 Eugene Hauptmann.

Retain all relevant redistribution, attribution and source obligations. Models, notices and native libraries ship beside the game; no paid API, Python installation or model download is needed during play.
