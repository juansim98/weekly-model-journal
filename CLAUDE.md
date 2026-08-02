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

- `const LABELS = { ... }` — the day-label vocabulary and its colours
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
        ["Mon","Range Formation","..."],
        ["Tue","Buy-side Liquidity Raid","..."],
        ["Wed","Top Formation","..."],
        ["Thu","MSS + Displacement","..."],
        ["Fri","Expansion / Delivery","..."]
      ]
    }
  ]
},
```

Rules:
- All five days present, always, in Mon–Fri order.
- `bias` is exactly `Bullish`, `Bearish`, or `Neutral`.
- `range` is Monday's high / low as I state it.

## How the page is laid out

One week on screen at a time. A pager above the record carries `◀ Newer`, the
week id and dates, `Older ▶`, and a jump-to-week dropdown. Labelled by direction
in time, not "prev/next", because the record is stored newest-first and "next"
would be ambiguous.

Above the label chips is a scope switch, **Filters apply to: This week | All weeks**:

- **This week** — the pager stays; search, pair, bias and label chips narrow the
  week you are on. If a filter matches nothing here but does match elsewhere, the
  page says so and offers a button through to the all-weeks view.
- **All weeks** — the pager hides and every week containing a match is listed
  newest-first under its own heading. This is how the whole page behaved before.

Both scopes run the same predicate (`pairMatches`); only the set of weeks handed
to it changes. The week heading is drawn only in all-weeks view — on a single
week the pager already names it.

## Day labels — the important rule

The second element of each day is a label, and it **must match a key in `LABELS` exactly**.
The colour coding and the cross-week filter both depend on this. A label that doesn't match
renders with a red NEW LABEL flag.

Current vocabulary:

- Range Formation
- Buy-side Liquidity Raid
- Sell-side Liquidity Raid
- Top Formation
- MSS + Displacement
- Expansion / Delivery
- Completion / Profit-Taking

If my description doesn't fit any of these, **ask me** rather than inventing a label or
forcing a bad fit. If I confirm a new one, add it to `LABELS` with a colour distinct from
the existing set, and tell me which colour you chose.

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
lowercase pair name, and weeks that are out of newest-first order.

If I ask for a UI change, describe what will visibly differ before you make it.
