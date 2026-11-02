# Tracing analytics in TelemetryDeck

The same events cover the alphabet, numbers, and Japanese hiragana. They are
emitted by `Services/TracingAnalytics.swift` through the existing `Analytics`
wrapper. New production data starts with a released build containing this change.

## Filters shared by every event

| Parameter | Values / meaning |
| --- | --- |
| `collection` | `letter_tracing`, `number_tracing`, or `hiragana_tracing` |
| `app_locale` | Selected app language: `en`, `de`, `es`, `ja`, or `zh-Hans` |

Character events also include `character` and the zero-based `character_index`.
Alphabet events identify the page by its uppercase character and also include
`lowercase_character`: e.g. `A` and `a` share one tracing page. Usage is measured
per page, rather than attempting to infer which case a child traced.

## Events

| Event | Trigger | Additional fields / numeric metric |
| --- | --- | --- |
| `Tracing.collectionOpened` | Enter a collection's character grid; once per grid visit | `character_count` |
| `Tracing.sessionStarted` | Open a tracing screen from the grid; once per session | Initial character fields |
| `Tracing.characterViewed` | Show the initial character or navigate to another | Character fields; `entry` = `grid`, `next`, or `previous` |
| `Tracing.drawingStarted` | First drawing contact on a character visit | Character fields |
| `Tracing.reset` | Tap Restart | Character fields; `cleared_stroke_count` |
| `Tracing.engagement` | Leave a character, background the app, or close tracing | Character fields, counters, `reason`, optional `next_character`; **`floatValue` = foreground seconds for this segment** |
| `Tracing.drawingDuration` | Same checkpoint, when drawing contact time is positive | Same fields as engagement; **`floatValue` = drawing contact seconds for this segment** |
| `Tracing.sessionEnded` | Close or otherwise dismiss the tracing screen; once | Session counters, `reason`, `characters_viewed`, `unique_characters_viewed`, `characters_practiced`; **`floatValue` = total foreground session seconds** |

The existing `Bookshelf.packTapped` event is preserved, with `pack` set to the
same collection ID. Returning from a tracing screen to its grid does not emit
another `collectionOpened` event. Selecting another character starts a new
tracing session; the Next/Previous controls remain inside the current session.

## Counters and time

`Tracing.engagement`, `Tracing.drawingDuration`, and `Tracing.sessionEnded`
include these string parameters for inspection:

| Parameter | Meaning |
| --- | --- |
| `active_seconds` | Time visible in the foreground, including reading or looking at the examples |
| `drawing_seconds` | Time the finger/Pencil is in a drawing gesture |
| `stroke_count` | Drawing contacts started, including taps and attempts later erased |
| `reset_count` | Explicit Restart taps |

Time formatting always uses a decimal point. Numeric duration charts should use
`floatValue`, which supports sums and means in
[TelemetryDeck's numeric aggregations](https://telemetrydeck.com/docs/recipes/averagaging-numbers/).

Engagement and drawing-duration events contain **deltas since the previous
checkpoint**, so their numeric values can be summed without counting an earlier
background checkpoint again. `reason` is `next`, `previous`, `background`,
`close`, or `dismissed`. A background checkpoint preserves the preceding usage
even when the app is subsequently terminated without closing the screen.
Background and inactive time are excluded. Session-end events contain cumulative
totals and are available for sessions that are closed or dismissed normally.

Count and sum one event type at a time. Adding `engagement`, `drawingDuration`,
and `sessionEnded` durations together would mix different measurements and
double count the session totals.

`drawingStarted` is emitted once per character visit, not once per drag sample.
Restarting does not emit another drawing-start event on that visit. Revisiting a
character with Next/Previous creates a new visit and can emit another one.
Navigation clears the drawing without being counted as a Restart. Session
summaries count unique practiced characters across all visits and resets.

No drawing coordinates or stroke point arrays are sent. There is no tracing
completion or accuracy event because tracing remains free drawing without grading.

## Useful comparisons

| Question | Event and aggregation | Group / filter |
| --- | --- | --- |
| Which collection attracts interest? | Count `Tracing.collectionOpened` | `collection` |
| Which collections are actually traced? | Count `Tracing.drawingStarted` | `collection` |
| Which characters are chosen directly? | Count `Tracing.characterViewed` | `collection`, `character`; filter `entry = grid` |
| Which characters are practiced most? | Count `Tracing.drawingStarted` | `collection`, `character` |
| Where is actual drawing time spent? | Sum `floatValue` on `Tracing.drawingDuration` | `collection`, optionally `character` |
| Where is foreground time spent? | Sum `floatValue` on `Tracing.engagement` | `collection`, optionally `character` |
| How long are closed sessions? | Mean `floatValue` on `Tracing.sessionEnded` | `collection` |
| Which pages get frequent restarts? | Count `Tracing.reset` | `collection`, `character` |

Filter by `app_locale` to compare language audiences. In particular, compare
hiragana against the alphabet and numbers within `app_locale = ja`, since only
Japanese users see the hiragana collection.

## Validation

`TracingAnalyticsTests` uses an injected monotonic clock and an in-memory event
sender to verify counts, numeric metrics, repeat visits, resets, dismissal,
background checkpoints, and locale-independent timing. It does not send events
to TelemetryDeck. UI tests launch with `-uiTestDisableAnalytics`, which disables
SDK initialization and analytics sending for those test runs. Run UI checks on
the dedicated tracing simulators to preserve installed app preferences and progress.
