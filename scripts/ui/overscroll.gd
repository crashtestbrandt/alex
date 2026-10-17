class_name Overscroll
## Rubber-band overscroll for a scroll view, as pure math. [SdfScroll] drives it.
##
## A pull is the finger's travel past an end of the content, in pixels. Positive is content pulled down past its
## top; negative is content pulled up past its bottom. The content shows a banded distance: it follows the
## finger at first, and less the further the pull goes.

## The share of the first pixels of a pull that the content follows.
const RESISTANCE: float = 0.55
## How far a fling that hits an end carries on, in seconds of its speed, before the band stops it.
const FLING_SECONDS: float = 0.06

## The distance the content shows for a pull, in a view `extent` pixels tall. It never reaches `extent`.
static func band(pull: float, extent: float) -> float:
	if extent <= 0.0 or pull == 0.0:
		return 0.0
	var shown: float = (1.0 - 1.0 / (absf(pull) * RESISTANCE / extent + 1.0)) * extent
	return signf(pull) * shown

## The pull that shows `shown` pixels, the inverse of [method band]. A spring caught mid-return by a new touch
## resumes from it.
static func unband(shown: float, extent: float) -> float:
	if extent <= 0.0 or shown == 0.0:
		return 0.0
	var magnitude: float = minf(absf(shown), extent * 0.999)
	return signf(shown) * magnitude * extent / (RESISTANCE * (extent - magnitude))

## The pull after one drag step of `delta` pixels, down positive. An end collects pull only while the content
## sits at it, and a step back the other way gives the pull back before the content scrolls.
static func drag(pull: float, delta: float, at_top: bool, at_bottom: bool) -> float:
	if pull > 0.0:
		return maxf(pull + delta, 0.0)
	if pull < 0.0:
		return minf(pull + delta, 0.0)
	if at_top and delta > 0.0:
		return delta
	if at_bottom and delta < 0.0:
		return delta
	return 0.0

## The most a fling carries past an end, as a share of the view's height. A fast fling still only nudges.
const FLING_MAX_SHARE: float = 1.0 / 6.0

## How far a fling carries past an end, for content moving at `speed` pixels a second, down positive.
static func fling(speed: float, extent: float) -> float:
	var limit: float = extent * FLING_MAX_SHARE
	return clampf(band(speed * FLING_SECONDS, extent), -limit, limit)
