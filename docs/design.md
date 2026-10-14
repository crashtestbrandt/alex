# Design

What the app is for, in the order that decides every trade-off, and the few mechanisms it is built on.

## Intent

Teaching is harder for a learner like this, and so is learning. This app is not a clinical solution and not a
substitute for one. In order of priority, it is:

1. **Approachable, low-friction and low-risk** for caregivers and learners both. A caregiver configures it
   once, in minutes, without knowing any framework. A learner cannot break anything by touching it.
2. **Discoverable on its own.** After that minimal configuration, the learner picks it up and finds what it
   does by touching things. Nothing is explained, and nothing has to be.
3. **Interesting enough to sustain interest.** It responds, it surprises a little, and it carries the
   learner's own words, voices and interests.
4. **Useful.** For the learner, a place where their language comes back to them in voices they love,
   attached to things they can act on. For the caregiver, a bank of what the learner says and what to say
   back.
5. **Harmless.** Stated as rules below.

When two of these pull against each other, the earlier one wins.

## Who it is for

Children who acquire language in **gestalts**: whole chunks heard and stored before their internal structure
is known. Many autistic children and many children with developmental delays start this way, and their first
speech is **echolalia**. The app is not tied to one child. Everything that distinguishes one from another is a
profile (docs/profiles.md).

## What the app must never do

Echolalia is communicative, and questions and demands draw more echoing and less original speech than
comments do (README "Research", items 1 to 3). The intent above adds the rest. These are rules:

- **No testing.** No questions put to the learner, no right answers, no scores, no streaks, no timers, no
  rewards. A screen that adds one of these is wrong however well it is built.
- **No correction.** The learner's gestalt is communication. The app plays it back as given.
- **Nothing the learner can reach deletes, buys, or leaves the device.** No network, no analytics, no
  account.
- **No modals, no confirmations, no error text on the learner's screen.** A problem is logged for the
  caregiver, never shown to the learner.
- **Nothing built to extend a session.** No notifications, no feed, no autoplay chain, no "one more".
- **Repetition is unlimited.** Tapping the same thing forty times may be regulation. The app never gets
  bored before the learner does, and never interrupts.
- **Motion and sound are per-profile settings**, so overstimulation is a setting and never a surprise.
- **A synthetic voice is never the goal.** OS text to speech voices a gestalt until a recording exists; a
  familiar voice is always the intended experience.
- **Adult screens sit behind a held button**, and the recording overlay writes nothing until Keep is
  pressed and closes itself when left alone.
- **Nothing cartoon-babyish by default.** The learner may be four or fourteen. Style presets carry the look.

## What the app does

- **Rooms.** An explorable 3D room of a handful of objects. Touch the door and it swings open as "Let's go
  outside" plays. Touch it again and it closes with "Let's go inside". Objects are built from primitives and
  described in data, so a caregiver can add a room without art or code (docs/geometry.md).
- **Views.** Front, Side and Top buttons move the camera between three angles, and a caregiver can allow a
  Turn button and a drag that orbits. Every view is reversible, every view returns to Front after a short
  idle, and a room can be set to no view buttons at all. Views are the first step in scene complexity a
  caregiver can grow.
- **Boards.** The plainer alternative: large tiles that say a phrase. Useful for phrases with no object.
- **A gestalt bank.** Every phrase, with its chunks, where it came from, what it does for the learner, and
  the recording that voices it.
- **One caregiver gesture.** Hold any object or tile to record its phrase in your own voice. Hold the big
  button, say it, let go, hear it back, keep it. The previous take is kept beside the new one.
- **Starter packs and style presets.** Seed content and a look, chosen once at profile creation.

Planned, in rough order: more rooms and more reactions; the learner's own songs and clips, since so much
echolalia comes from them; a remix board that offers chunk beginnings beside chunk endings; video
self-modeling; a bank view for caregivers. Assessment features stay off the list unless a caregiver asks,
and never reach the learner's screen.

## Making chunks visible

A gestalt is authored with `|` chunk marks: `Let's go | to the park`. `Gestalt.from_text` keeps the spoken
text and the chunk list. When an object is touched, its chunks float above it and light up in order while the
phrase plays; on a tile, the chunks pull apart. The learner sees where the seams are without being told. A
gestalt with no bar stays whole, which is right for a phrase that should not be broken yet.

The same chunk list feeds the remix board later. Authoring the seam once, in the text, keeps every feature
agreeing on where the seams are.

## Reference: the Natural Language Acquisition stages

The NLA framework (Blanc, after Peters and Prizant) describes how echolalia becomes self-generated language.
Its clinical claims are debated and its protocol has no empirical evaluation (README "Research", items 8 to
10); the app uses its chunking idea as a design heuristic and depends on nothing else in it. A profile may
record a stage for the caregiver's reference. Nothing on the learner's screen shows it, and it gates nothing.

| Stage | What the learner does | What the adults model |
| --- | --- | --- |
| 1 | Uses whole gestalts as heard, often from media or songs. | Short, mitigable gestalts in a natural voice. |
| 2 | Mixes and matches chunks of gestalts. | Recombinations of chunks the learner already has. |
| 3 | Isolates single words and makes two-word combinations. | Single words in context. |
| 4 | Builds first original sentences, grammar still rough. | Natural sentences without correction. |
| 5 | Uses more complex grammar. | |
| 6 | Uses full, flexible sentences. | |

## Sources

The reading list, with both sides of the framework debate, is the README's "Research" section. One list,
so it cannot drift.
