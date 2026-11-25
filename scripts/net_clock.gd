class_name NetClock
extends RefCounted
## A clock every peer agrees on (to within about a frame): the host's clock. Level objects that
## move on their own (MovingPlatform) work out where they are from now(), so they're in the same
## place everywhere without sending anything.
##
## Game keeps offset up to date on clients: it pings the host now and then, and each pong gives
## the host's time plus half the round trip. The fastest round trips are the most accurate, so a
## sample only replaces the estimate when its round trip is close to the best seen lately. The
## host and offline play use offset 0.

## Seconds to add to this machine's clock to get the host's.
static var offset: float = 0.0

static var _best_round_trip: float = INF
## Trailer renders only (tools/promo/trailer/): the game's own time, used instead of the wall
## clock. Movie Maker records a frame per step however long each takes to draw, so on the wall clock
## platforms and rides would race past or crawl in the video (and ignore slow motion).
static var time_source: Callable = Callable()


## Seconds on the host's clock.
static func now() -> float:
	return local_now() + offset


static func local_now() -> float:
	if time_source.is_valid():
		return time_source.call()
	return Time.get_ticks_usec() / 1000000.0


## Client only: a pong from the host, for a ping sent at [param sent_at] (local_now()), answered
## when the host's clock read [param host_time].
static func add_sample(sent_at: float, host_time: float) -> void:
	var received: float = local_now()
	var round_trip: float = received - sent_at
	# Let the best round trip drift up slowly, so a lasting change in latency is picked up.
	_best_round_trip *= 1.05
	if round_trip <= _best_round_trip * 1.25:
		_best_round_trip = minf(_best_round_trip, round_trip)
		offset = host_time + round_trip / 2.0 - received


## Back to this machine's own clock (leaving a lobby).
static func reset() -> void:
	offset = 0.0
	_best_round_trip = INF
