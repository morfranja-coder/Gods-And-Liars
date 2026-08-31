"""Build the repository-ready alpha scenario from the untouched source GLB.

Run with Blender in background mode. The source path and output path are explicit
arguments so the original artist file is never modified.
"""

import argparse
import sys

import bpy


MAX_TEXTURE_SIZE = 2048


def parse_args() -> argparse.Namespace:
	parser = argparse.ArgumentParser()
	parser.add_argument("source")
	parser.add_argument("output")
	separator = sys.argv.index("--") if "--" in sys.argv else 0
	return parser.parse_args(sys.argv[separator + 1 :])


def resize_large_images() -> None:
	for image in bpy.data.images:
		width, height = image.size
		largest_side = max(width, height)
		if largest_side <= MAX_TEXTURE_SIZE:
			continue
		scale = MAX_TEXTURE_SIZE / float(largest_side)
		image.scale(max(1, round(width * scale)), max(1, round(height * scale)))


def main() -> None:
	args = parse_args()
	bpy.ops.wm.read_factory_settings(use_empty=True)
	bpy.ops.import_scene.gltf(filepath=args.source)
	resize_large_images()
	bpy.ops.export_scene.gltf(
		filepath=args.output,
		export_format="GLB",
		export_image_format="AUTO",
		export_image_quality=80,
		export_lights=False,
		export_cameras=False,
	)


if __name__ == "__main__":
	main()
