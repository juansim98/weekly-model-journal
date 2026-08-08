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
