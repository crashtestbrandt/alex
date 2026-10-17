extends RefCounted
class_name ChunkColors
## The color a chunk carries wherever it appears: a hash of its lowercased, trimmed text into the style
## preset's `chunk_palette`. "Let's go" is the same color on every tile, caption and pack. Two chunks can share
## a color, and in a large bank some will. The color says which chunk this is and nothing else: no function,
## no stage, no judgment.

## FNV-1a over UTF-8, 32 bits, then the murmur3 finalizer so short chunks spread over a small palette. Written
## out here rather than taken from `String.hash`, so an engine upgrade never recolors a family's chunks.
const _FNV_OFFSET: int = 0x811C9DC5
const _FNV_PRIME: int = 0x01000193
const _MIX_1: int = 0x85EBCA6B
const _MIX_2: int = 0xC2B2AE35
const _MASK_16: int = 0xFFFF
const _MASK_32: int = 0xFFFFFFFF
## How a spoken chunk brightens at motion NONE, in HSV: more saturation, more value, the same hue.
const SPOKEN_SATURATION: float = 0.15
const SPOKEN_VALUE: float = 0.10

## What the color is keyed by: the chunk lowercased and trimmed.
static func key(chunk: String) -> String:
	return chunk.strip_edges().to_lower()

## The 32-bit hash of `text`'s UTF-8 bytes: FNV-1a, then the murmur3 finalizer.
static func hash_text(text: String) -> int:
	var h: int = _FNV_OFFSET
	for byte: int in text.to_utf8_buffer():
		h = _mul32(h ^ byte, _FNV_PRIME)
	h ^= h >> 16
	h = _mul32(h, _MIX_1)
	h ^= h >> 13
	h = _mul32(h, _MIX_2)
	h ^= h >> 16
	return h

## `a * b` modulo 2^32, for 32-bit `a` and `b`. GDScript integers are signed 64-bit, so the product is taken
## in two 16-bit halves of `b` to stay clear of overflow.
static func _mul32(a: int, b: int) -> int:
	var low: int = a * (b & _MASK_16)
	var high: int = ((a * (b >> 16)) & _MASK_16) << 16
	return (low + high) & _MASK_32

## The palette slot for `chunk` in a palette of `count` colors, or -1 for an empty palette.
static func index_for(chunk: String, count: int) -> int:
	if count <= 0:
		return -1
	return hash_text(key(chunk)) % count

## The color for `chunk`. An empty palette gives a transparent color, so the chunk shows no pill.
static func color_for(chunk: String, palette: PackedColorArray) -> Color:
	var slot: int = index_for(chunk, palette.size())
	if slot < 0:
		return Color(0.0, 0.0, 0.0, 0.0)
	return palette[slot]

## The color a chunk's pill takes while it is spoken at motion NONE. The hue is kept, so the identity stays.
static func spoken(c: Color) -> Color:
	return Color.from_hsv(c.h, minf(c.s + SPOKEN_SATURATION, 1.0), minf(c.v + SPOKEN_VALUE, 1.0), c.a)
