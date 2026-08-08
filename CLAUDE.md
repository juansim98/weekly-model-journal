# Weekly Model Journal — project notes

A single-page archive of the Monday–Friday liquidity model, published via GitHub Pages
for Kingdom Crest Capital. Used as a teaching record.

## Files

- `index.html` — the entire site. Data at the top, page machinery below.
- `Charts/` — chart screenshots. Note the capital C.
- `publish.ps1` / `publish.bat` — the weekly publish. See **Publishing** below.

There is no build step. Editing `index.html` and pushing is the whole deploy.

## The only part that changes

Everything I add lives in two blocks near the top of `index.html`:

- `const LABELS = { ... }` — every day wording and its colour
- `const WEEKS = [ ... ]` — the record, newest week first

New weeks go directly beneath the line `/* ===== NEWEST WEEK GOES HERE ===== */`.

**Do not touch anything below the WEEKS array** unless I explicitly ask for a UI change.
The rendering code, CSS, and the base64 logo at the bottom of the file are settled.

## Week block shape

```js
{
  id: "2026-W32",              // ISO week, always YYYY-Wnn
  dates: "3–7 August 2026",
  theme: "",                   // leave empty unless I give you one
  note: "",                    // leave empty unless I give you one
  pairs: [
    {
      pair: "USDJPY", bias: "Bearish", range: "163.85 / 163.35",
      days: [
        ["Mon","Accumulation","..."],
        ["Tue","Early-week breakout","..."],
        ["Wed","Continuation","..."],
        ["Thu","Repricing","..."],
        ["Fri","Macro-assisted liquidity expansion","..."]
      ]
    }
  ]
},
```

Rules:
- All five days present, always, in Mon–Fri order.
- The middle element is the wording as I gave it — see **Day labels** below. Each
  new one needs a `LABELS` entry with a colour.
- Leave the third element `""` unless I actually wrote a description. Don't
  invent prose to fill it.
- `bias` is exactly `Bullish`, `Bearish`, or `Neutral`.
- `range` is Monday's high / low as I state it.

## How the page is laid out

One week on screen at a time. A pager above the record carries `◀ Prev`, the
week id and dates, `Next ▶`, and a jump-to-week box.

`Prev` goes **back** in time and `Next` **forward**, which is the opposite of
their array direction — `WEEKS` is stored newest-first, so `Prev` moves the index
up and `Next` moves it down. The button ids (`olderWeek`, `newerWeek`) name the
direction in time rather than the label, so the code stays readable if the
wording changes again.

The jump box filters as you type, matching a week's id, dates or theme. It is a
custom combobox rather than a `<select>` because a plain dropdown stops being
usable once the record runs to dozens of weeks. Arrow keys move the highlight,
Enter picks, Escape restores the current week.

**Filtering is by pressing a day.** Each square in a Mon–Fri strip is a button.
Pressing one opens the record out to every week holding a day worded exactly the
same, newest-first, and the pager hides. Pressing it again clears it.

This replaced a standing legend of chips plus a **This week | All weeks** switch.
Both had to go for the same reason: the vocabulary grows every week, so a list of
every label was a wall that could only get worse, and a scope switch was a second
control for something a single press already says.

Because labels are never grouped, a press finds other weeks only where the same
phrase recurs. That is the accepted trade for keeping every wording intact.

## The address bar

The hash is a set of `/`-separated tokens, in any order:

    (nothing)         class view, newest week
    #edit             my tools: Present, Add a week, Labels
    #2026-W32         class view, opening on that week
    #edit/2026-W32    both
    #wfm              the six weekly flow models, as its own page

The week is written back on every change (`syncHash`, via `replaceState` so it
doesn't stack a history entry per Prev/Next), so the address bar always names
what is on screen and copying it shares exactly that.

A link naming a week stays on that week for good — that is the point for "here
is this week's review", and it means the **plain** address is the one to give the
class as their standing bookmark, because it always opens on the newest week.
An unknown week id is ignored rather than shown as an error.

Filters are deliberately *not* in the URL. Pressing a day drops the week token,
since an all-weeks view is not a week. Encoding an arbitrary label would make the
link unreadable, which defeats the point of a link you paste to a class.

Search matches only what is on the card — week id, dates, theme, note, pair,
bias, range, and each day's label and description. Keep it that way. Putting
anything hidden into that haystack makes the box look broken, because a common
word comes back matching every card.

There are still two scopes internally (`state.scope`), and both run the same
predicate (`pairMatches`) — only the set of weeks handed to it changes. What
changed is how you get between them. Because the pager hides in all-weeks view,
`#filterbar` has to be the way back, so it shows whenever the scope is open —
naming the family when there is one, otherwise just offering **Back to one week**.
Search, pair and bias narrow whatever is on screen, as before, and the "nothing
here, N matches elsewhere" hand-off still works.

The week heading is drawn only in all-weeks view — on a single week the pager
already names it.

## The six weekly flow models

`const WFM_MODELS` and `const WFM_TREE`, at the top with the other data. This is
the standing reference behind the WFM column in each week's ranking — the six
models, their day-by-day flow, the key recognition for each, and the
Tuesday/Wednesday decision tree.

A **tab high on the page, above the pager**, opens it as **a page of its own at
`#wfm`** — explanations only, nothing of the record. The models are the frame
you read every week through, so they sit above the week you happen to be on.

It is a page, not an expander: `#wfmpage` is a fixed overlay in the same shape
as Present mode, shown by `body.wfmmode`. The record stays put underneath rather
than being torn down and rebuilt on the way back. The tab is a real `<a
href="#wfm">`, so it can be opened in a new tab, and `#wfm` can be handed to
students as its own address — landing directly on it works. Esc and **Back to
the record** both leave, and the browser Back button works because the hash is
the navigation. It is visible in class mode, since students are who it is for.

Because it lives outside `render()`, nothing re-renders underneath it, so it is
built once at load. `state.wfm` exists only so `syncHash` knows the hash names
the page rather than the week beneath it.

A model needs `id` (`WFM-n`), `name`, `colour`, `flow` (array of steps),
`tell`, and optionally `note` and `primary:true`.

**`flow` draws as a vertical `<ol>`, one step per row, with a dot and a rail
as the connector. Don't put the arrows back.** It was first built as a
wrapping row of chips with `→` between them as text, which left arrows
stranded at the end of lines pointing at nothing and rewrapped into a
different shape at every screen width — worst on a phone. Drawn as a list it
reads identically at any width, a long step just wraps inside its own row, and
a screen reader gets the sequence too.

**Each card opens enlarged.** Clicking one (or Enter/Space — cards are
`role="button"`) opens `#wfmzoom` at z-index 85: above the models page and the
label panel, below the chart lightbox, which stays topmost. Previous/Next step
through all six without returning to the grid, which is how you walk a class
through them; Esc, Close, or clicking the surround dismisses. Arrow keys work
while it is open, checked ahead of the models page in the keydown listener
since it is the thing on top.

In a week's ranking, a WFM cell naming models the guide defines becomes a
button: pressing it goes to the models page and gold-rings that model, so a
student reading the table can ask "what is WFM-4?" from where they are. A cell
naming two — `WFM-1 → WFM-6` — rings both. `publish.ps1` warns if a ranking
cites a `WFM-n` the guide doesn't define.

**Deliberately no "examples this week"** in the guide, though the source PDF has
them. They go stale the moment a new week lands, and the ranking already records
which instrument expressed which model, week by week.

Note for `publish.ps1`: the week scan is anchored to `const WEEKS`, because
`WFM_MODELS` also carries `id:` fields and every model would otherwise be read
as a malformed week.

## The three week tabs

Each week can carry three collapsed tabs, in this order, above the pair cards:

1. **Post-market audit** (`audit`) — the Tuesday ranking as it was given,
   reviewed once the week closed. This is the name on the source document.
2. **Result scorecard** (`scorecard`) — how it actually settled, scored.
3. **Weekly asset ranking** (`ranking`) — the finished verdict.

They are chronological on purpose, and the first two are kept as two records
rather than merged into one: the teaching value is in reading the call against
the outcome, which needs both to survive separately.

**On the names.** "Post-market audit" is the heading on the source document,
so it belongs to the first table. `checkpoint` is a *date field* inside that
document ("Forecast checkpoint: Tuesday, 4 August"), not the table's name —
don't promote it back into a title. "Result scorecard" is a name I chose,
because the second table arrived with no heading of its own; if a real title
turns up, use that instead.

All three share `tabBlock()` and the `.wk-tbl` table styling, and all are shut
by default with a summary worth reading shut. Open/closed lives in
`state.tabs[key]`, so every week's copy of a tab moves together as you page
through the record — which is what makes comparing the same tab across weeks
work.

```js
  audit: {
    checkpoint: "Tuesday, 4 August",
    rows: [
      { rank:"#1", instrument:"Bitcoin", bias:"Long", grade:"A+", projection:"64,000 → 64,300–64,350" }
    ]
  },
  scorecard: {
    rows: [
      { instrument:"Gold", tue:84, wed:94, model:"WFM-2", target:"PWH", status:"Delivered", result:"Win" }
    ]
  },
```

- The audit's `rank` is **written in**, not taken from the array order,
  because not every row is a rank — `"Macro"` is a standing row, not fifth
  place.
- `bias` there is free text and is **not** held to Bullish/Bearish/Neutral —
  it is written `"Long"` and `"Bearish"` in the same column. It shows exactly
  as given; only the colour reads the meaning (`viewClass`). Same for `grade`,
  which runs to `"A / strong model"`.
- `tue` and `wed` are numbers, so the Tue→Wed move can be drawn. That delta is
  the most telling thing in the audit and is invisible unless drawn.
- `result` colours by meaning too (`resultClass`): Win green, Moderate grey,
  a Loss red.
- `model` goes through `wfmBadge()`, so audit rows link to the models page
  exactly as ranking rows do.

The audit does **not** fold on a phone — seven short columns, and the point is
reading Tue against Wed on one line, so it scrolls inside its own card while
the page stays put. The audit and the ranking both fold.

Note for `publish.ps1`: all three row types carry `instrument:`, so they are
told apart by a field only that kind has (`projection:` → audit, `result:`
→ scorecard, otherwise ranking) rather than by which array they sit in.

## Weekly asset ranking

Optional per week. A week without a `ranking` array simply doesn't draw one.

```js
  ranking: [
    { instrument:"GOLD",   wfm:"WFM-1",         direction:"Bullish", quality:"Exceptional", grade:"A+" },
    { instrument:"US30",   wfm:"WFM-1 → WFM-6", direction:"Bullish", quality:"Strong",      grade:"A"  }
  ],
```

It sits above the pair cards as a **collapsed bar**, one line high, reading
`▶ WEEKLY ASSET RANKING · 8 instruments · 4 graded A+`. Clicking it opens the
full table. It is reference rather than the week's story, and the pair cards
are what the class is there for, so it stays shut until asked for — but the
bar still carries the count and the A+ tally, so it is worth reading closed.

Open, it is a real `<table>` using my column names — Rank, Instrument,
Primary WFM, Direction, WFM Quality, Grade.

**It must stay a `<table>`.** It was first built as a stack of `div`s each
with its own `display:grid`; every row then sized its own columns, so the
badges and text staggered from row to row and the thing looked broken. One
table shares column widths across all rows, which is the whole point. Quality
carries `width:100%` so it absorbs the slack and the other columns shrink to
their content.

Open/shut is held in `state.rankOpen`, not left to the native `<details>`
toggle, so it survives a re-render and so every week's table in the all-weeks
list opens and shuts together.

- **Rank is the array order**, not a written-in number, so the two can never
  disagree. First row is rank 1.
- `direction` is exactly `Bullish`, `Bearish` or `Neutral` — same rule as
  `bias`, and it reuses the same green/red chips.
- `wfm` and `quality` are free text. Reproduce them exactly as I give them,
  including an arrow like `WFM-1 → WFM-6`. Don't expand "WFM" into words —
  it is my teacher's term and I have not defined it.
- `grade` drives the only other colour: the first letter picks the badge
  (A ink, B muted, C faint, anything else outlined), and exactly `A+` earns
  the gold left edge. **A new grade needs no code and no map.**
- An instrument that also has a `pairs` block that week renders as a button
  through to it, working exactly like the Pair dropdown — press again to
  clear. Instruments with no block that week are plain text, which is normal:
  the ranking covers more instruments than the record has day-by-day cards.

On a phone the six columns fold to three lines rather than scrolling
sideways.

## Day labels — the important rule

The second element of each day is the label, and it is **my wording, or my
teacher's, reproduced exactly**. Never reword, tidy, shorten, expand or
"correct" it. Do not strip a day-name prefix — if it says
`Monday Accumulation`, that is the label.

**Every wording is its own label. Nothing is grouped or merged.**
`Monday Accumulation`, `Accumulation` and `Range` are three separate labels with
three separate colours, even though they describe similar days. Don't propose a
grouping or a family layer — I have turned that down twice. A day filters on its
own exact wording and nothing else.

Every label used by a day **must match a key in `LABELS` exactly**. The colour
coding and the press-a-day filter both depend on it. A label that doesn't match
renders with a red NEW LABEL flag and `publish.ps1` refuses to publish.

So adding a week is two edits: the week block, and a `LABELS` entry with a colour
for every wording that is new. Tell me which colours you chose.

Colours run in related shades by kind of move — Monday openers slate, shifts
teal, deliveries blue, raids orange, pullbacks maroon — so a strip still reads as
a shape from the back of the room. Each label owns its own hex regardless; the
shared family of hue is a visual courtesy, not a grouping.

Never silently rename or delete a label that existing weeks still use.

## Pair names

Free text, but match existing spelling exactly when the pair already appears in the record
(`USDJPY`, not `usdjpy`). New instruments are fine — keep them uppercase.

## Charts

Filenames are `Charts/WEEK_PAIR.png`, e.g. `Charts/2026-W31_USDJPY.png`.
Case-sensitive on GitHub Pages. I upload these myself; don't generate placeholders.

`publish.ps1` normalises these names before every publish — it strips double
extensions (`.png.jpg`), uppercases the pair, and corrects the case. So the name
I save doesn't have to be perfect, but the convention above is still what lands
in the repo. The files are JPEGs regardless of the `.png` extension; browsers
sniff the content, so this is intentional and fine.

Clicking a chart opens it full screen (`#lightbox`). Clicking the image again
toggles between fit-to-screen and full size, which can then be panned; clicking
the surround, pressing Esc, or the Close button dismisses it. Charts are
illegible at phone width otherwise. The Esc handling sits ahead of the class-mode
early return in the keydown listener, because the class uses the plain link.

## Publishing

`.\publish.ps1` — or double-click `publish.bat` — is the whole weekly deploy.
It tidies the chart filenames, checks `index.html`, then commits and pushes.
It refuses to publish if any check fails, so a broken page can't reach the class.

    .\publish.ps1                  tidy, check, commit, push
    .\publish.ps1 -CheckOnly       check only; changes and publishes nothing
    .\publish.ps1 -NoPush          commit locally, don't push
    .\publish.ps1 -Message "..."   override the commit message

Commit messages are generated: `Add 2026-W32` when the newest week is new to the
repo, `Update 2026-W32` when it isn't. For other work pass `-Message`, saying what
changed: `Add label: Midweek Reversal`, `Fix chart path casing`.

## Before pushing

`publish.ps1` runs these checks and **stops** on any of them:

- the data block parses — balanced braces, closed quotes, and specifically a
  missing comma between week blocks, which renders the page blank
- every day label matches a key in `LABELS` exactly
- every ranking row has all five fields, a non-blank instrument, and a
  `direction` of exactly `Bullish`, `Bearish` or `Neutral`
- every pair has exactly five day rows, `Mon`–`Fri`, in order
- `bias` is exactly `Bullish`, `Bearish` or `Neutral`
- week ids are `YYYY-Wnn` and not duplicated
- no chart is present under a name that differs only by case — that works on
  Windows and breaks on GitHub Pages

It warns, without blocking, about a missing chart, an empty Monday `range`, a
lowercase pair name, weeks that are out of newest-first order, **two labels that
differ only by case or punctuation**, and a label with a stray leading or
trailing space.

That last pair matters more than it looks. Every wording is its own label, so
`Expansion` and `EXPANSION` are two entries with two colours and two filters —
the record splits in half and nothing else would say so. The label check is
deliberately **case-sensitive** (an ordinal dictionary, not a plain `@{}`,
which in PowerShell is case-insensitive) so that it matches the browser: the
JavaScript doing the lookup is case-sensitive, so a case-only mismatch renders a
red NEW LABEL flag. Don't "simplify" that back to `@{}`.

If I ask for a UI change, describe what will visibly differ before you make it.
