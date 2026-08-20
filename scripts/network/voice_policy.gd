class_name VoicePolicy
extends RefCounted

const MAX_COMPRESSED_BYTES := 65536
const MAX_DECOMPRESSED_BYTES := 192000

static func accepts_sender(peer_id: int, peers: Dictionary) -> bool:
	return peer_id > 0 and peers.has(peer_id)

static func accepts_compressed_size(byte_count: int) -> bool:
	return byte_count > 0 and byte_count <= MAX_COMPRESSED_BYTES

static func accepts_decompressed_size(byte_count: int) -> bool:
	return byte_count > 0 and byte_count <= MAX_DECOMPRESSED_BYTES
