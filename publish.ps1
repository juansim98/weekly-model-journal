<#
  publish.ps1 - Weekly Model Journal

  One command to put a week live:

      .\publish.ps1

  It does three things, in order, and stops at the first real problem:

      1. Tidies the chart filenames in Charts\ (case, double extensions).
      2. Checks index.html - that it parses, that every label is known,
         that every pair has five days, that the charts are really there.
      3. Commits and pushes. GitHub Pages rebuilds in about a minute.

  Useful switches:

      .\publish.ps1 -CheckOnly        check only, change nothing, push nothing
      .\publish.ps1 -NoPush           tidy + check + commit, but do not push
      .\publish.ps1 -Message "..."    write your own commit message
      .\publish.ps1 -Remote <url>     set the GitHub repo (first run only)
#>

[CmdletBinding()]
param(
    [string]$Message,
    [string]$Remote,
    [switch]$CheckOnly,
    [switch]$NoPush
)

$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
$indexPath  = Join-Path $root 'index.html'
$chartsPath = Join-Path $root 'Charts'

$problems = @()   # hard stops
$warnings = @()   # worth knowing, not fatal

function Say      { param($m) Write-Host $m }
function SayHead  { param($m) Write-Host ''; Write-Host $m -ForegroundColor Cyan }
function SayOk    { param($m) Write-Host "  OK    $m" -ForegroundColor Green }
function SayWarn  { param($m) Write-Host "  WARN  $m" -ForegroundColor Yellow }
function SayBad   { param($m) Write-Host "  STOP  $m" -ForegroundColor Red }
function SayInfo  { param($m) Write-Host "        $m" -ForegroundColor DarkGray }


# ---------------------------------------------------------------------------
# Reading the data block
# ---------------------------------------------------------------------------

# Blanks out comments and the insides of strings, keeping the text exactly the
# same length. That way a position in the mask is the same position in the
# original, so brace matching can ignore anything quoted or commented out.
function Get-CodeMask {
    param([string]$Text)

    $mask   = [char[]]$Text.Clone()
    $unterm = @()
    $i = 0
    $n = $Text.Length

    while ($i -lt $n) {
        $c = $Text[$i]

        if ($c -eq '/' -and ($i + 1) -lt $n -and $Text[$i + 1] -eq '/') {
            while ($i -lt $n -and $Text[$i] -ne "`n") { $mask[$i] = ' '; $i++ }
            continue
        }

        if ($c -eq '/' -and ($i + 1) -lt $n -and $Text[$i + 1] -eq '*') {
            $mask[$i] = ' '; $mask[$i + 1] = ' '; $i += 2
            while ($i -lt $n) {
                if ($Text[$i] -eq '*' -and ($i + 1) -lt $n -and $Text[$i + 1] -eq '/') {
                    $mask[$i] = ' '; $mask[$i + 1] = ' '; $i += 2; break
                }
                if ($Text[$i] -ne "`n") { $mask[$i] = ' ' }
                $i++
            }
            continue
        }

        if ($c -eq '"' -or $c -eq "'") {
            $quote = $c
            $start = $i
            $mask[$i] = ' '
            $i++
            $closed = $false
            while ($i -lt $n) {
                if ($Text[$i] -eq '\') {
                    $mask[$i] = ' '
                    if (($i + 1) -lt $n -and $Text[$i + 1] -ne "`n") { $mask[$i + 1] = ' ' }
                    $i += 2
                    continue
                }
                if ($Text[$i] -eq "`n") { break }          # strings must not span lines
                if ($Text[$i] -eq $quote) { $mask[$i] = ' '; $i++; $closed = $true; break }
                $mask[$i] = ' '
                $i++
            }
            if (-not $closed) { $unterm += $start }
            continue
        }

        $i++
    }

    [pscustomobject]@{ Mask = (-join $mask); Unterminated = $unterm }
}

function Get-LineNumber {
    param([string]$Text, [int]$Index, [int]$Offset = 0)
    if ($Index -lt 0) { return 0 }
    $upto = $Text.Substring(0, [Math]::Min($Index, $Text.Length))
    ($upto.Split("`n").Count) + $Offset
}

# Walks forward from an opening bracket to its partner. -1 if never closed.
function Find-Closing {
    param([string]$Mask, [int]$Start, [char]$Open, [char]$Close)
    $depth = 0
    for ($i = $Start; $i -lt $Mask.Length; $i++) {
        if ($Mask[$i] -eq $Open)  { $depth++ }
        if ($Mask[$i] -eq $Close) { $depth--; if ($depth -eq 0) { return $i } }
    }
    -1
}


# ---------------------------------------------------------------------------
# 1. Chart filenames
# ---------------------------------------------------------------------------
# The site asks for Charts/WEEK_PAIR.png with that exact spelling. GitHub Pages
# is case-sensitive, and Windows likes to leave a second extension behind when
# you save a screenshot, so this quietly puts every filename back on convention.

function Repair-ChartNames {
    SayHead '1. Chart filenames'

    if (-not (Test-Path $chartsPath)) {
        New-Item -ItemType Directory -Path $chartsPath | Out-Null
        SayWarn 'No Charts folder - created an empty one.'
        return
    }

    $files   = @(Get-ChildItem -Path $chartsPath -File)
    $renamed = 0
    $pending = 0

    if ($files.Count -eq 0) { SayInfo 'Charts folder is empty.'; return }

    foreach ($f in $files) {
        # Peel off every trailing image extension: "W31_EURUSD.png.jpg" -> "W31_EURUSD"
        $base = $f.Name
        while ($base -match '\.(png|jpg|jpeg|gif|webp)$') {
            $base = [System.IO.Path]::GetFileNameWithoutExtension($base)
        }

        $m = [regex]::Match($base, '^(?<week>\d{4}-[Ww]\d{2})[ _-]+(?<pair>[A-Za-z0-9]+)$')
        if (-not $m.Success) {
            $warnings += "Chart '$($f.Name)' is not named WEEK_PAIR - left alone."
            SayWarn "'$($f.Name)' does not look like WEEK_PAIR.png - left alone."
            continue
        }

        $want = '{0}_{1}.png' -f $m.Groups['week'].Value.ToUpper(), $m.Groups['pair'].Value.ToUpper()

        if ($f.Name -ceq $want) { continue }

        $target = Join-Path $chartsPath $want
        $clash  = @(Get-ChildItem -Path $chartsPath -File | Where-Object { $_.Name -ceq $want })
        if ($clash.Count -gt 0) {
            $warnings += "Wanted to rename '$($f.Name)' to '$want' but that name is taken."
            SayWarn "'$($f.Name)' -> '$want' skipped, that name already exists."
            continue
        }

        if ($CheckOnly) {
            SayInfo "would rename '$($f.Name)' -> '$want'"
            $pending++
            continue
        }

        # A case-only rename needs a bounce through a temporary name on Windows.
        if ($f.Name -ieq $want) {
            $tmp = Join-Path $chartsPath ('_tmp_' + [guid]::NewGuid().ToString('N') + '.png')
            Rename-Item -LiteralPath $f.FullName -NewName (Split-Path $tmp -Leaf)
            Rename-Item -LiteralPath $tmp -NewName $want
        } else {
            Rename-Item -LiteralPath $f.FullName -NewName $want
        }

        SayOk "renamed '$($f.Name)' -> '$want'"
        $renamed++
    }

    if ($renamed -eq 0 -and $pending -eq 0) { SayOk "$($files.Count) chart file(s), all named correctly." }
}


# ---------------------------------------------------------------------------
# 2. index.html
# ---------------------------------------------------------------------------

function Test-Journal {
    SayHead '2. index.html'

    if (-not (Test-Path $indexPath)) {
        $script:problems += 'index.html is missing.'
        SayBad 'index.html is missing.'
        return
    }

    $html = Get-Content -LiteralPath $indexPath -Raw -Encoding UTF8

    $block = [regex]::Match($html, '(?s)<script>(.*?)</script>')
    if (-not $block.Success -or $block.Groups[1].Value -notmatch 'const\s+WEEKS') {
        $script:problems += 'Could not find the data block (const LABELS / const WEEKS).'
        SayBad 'Could not find the data block near the top of the file.'
        return
    }

    $data       = $block.Groups[1].Value
    $lineOffset = (Get-LineNumber -Text $html -Index $block.Groups[1].Index) - 1

    $scan = Get-CodeMask -Text $data
    $mask = $scan.Mask

    # --- unterminated strings ------------------------------------------------
    foreach ($idx in $scan.Unterminated) {
        $ln = Get-LineNumber -Text $data -Index $idx -Offset $lineOffset
        $script:problems += "Line ${ln}: a quote is never closed."
        SayBad "Line ${ln}: a quote is never closed."
    }

    # --- balanced braces and brackets ---------------------------------------
    $stack = New-Object System.Collections.Stack
    $balanceBroken = $false
    for ($i = 0; $i -lt $mask.Length; $i++) {
        $c = $mask[$i]
        if ($c -eq '{' -or $c -eq '[') {
            $stack.Push([pscustomobject]@{ Char = $c; Index = $i })
        }
        elseif ($c -eq '}' -or $c -eq ']') {
            if ($stack.Count -eq 0) {
                $ln = Get-LineNumber -Text $data -Index $i -Offset $lineOffset
                $script:problems += "Line ${ln}: a stray closing '$c'."
                SayBad "Line ${ln}: a stray closing '$c'."
                $balanceBroken = $true
                break
            }
            $open = $stack.Pop()
            $expected = if ($open.Char -eq '{') { '}' } else { ']' }
            if ($c -ne $expected) {
                $ln = Get-LineNumber -Text $data -Index $i -Offset $lineOffset
                $script:problems += "Line ${ln}: found '$c' where '$expected' was expected."
                SayBad "Line ${ln}: found '$c' where '$expected' was expected."
                $balanceBroken = $true
                break
            }
        }
    }
    if (-not $balanceBroken -and $stack.Count -gt 0) {
        $open = $stack.Pop()
        $ln = Get-LineNumber -Text $data -Index $open.Index -Offset $lineOffset
        $script:problems += "Line ${ln}: this '$($open.Char)' is never closed."
        SayBad "Line ${ln}: this '$($open.Char)' is never closed."
        $balanceBroken = $true
    }
    if (-not $balanceBroken) { SayOk 'Brackets and quotes all balance.' }

    # --- the classic: a missing comma between two blocks --------------------
    foreach ($m in [regex]::Matches($mask, '\}\s*\{')) {
        $ln = Get-LineNumber -Text $data -Index $m.Index -Offset $lineOffset
        $script:problems += "Line ${ln}: missing comma between two blocks."
        SayBad "Line ${ln}: missing comma between two blocks - this is what blanks the page."
    }

    if ($script:problems.Count -gt 0) {
        SayInfo 'Fix the syntax first - the rest of the checks need a readable file.'
        return
    }

    # --- the label vocabulary -----------------------------------------------
    $labelsEnd  = Find-Closing -Mask $mask -Start $mask.IndexOf('{', $mask.IndexOf('LABELS')) -Open '{' -Close '}'
    $labelsText = $data.Substring(0, $labelsEnd)
    # Ordinal, not a plain @{} - PowerShell hashtables are case-insensitive, so
    # 'Expansion' and 'EXPANSION' would collapse into one entry here and the
    # check below would pass a page that renders a red NEW LABEL flag, because
    # the JavaScript doing the lookup is case-sensitive. Match the browser.
    $knownLabels = New-Object 'System.Collections.Generic.Dictionary[string,string]' ([StringComparer]::Ordinal)
    foreach ($m in [regex]::Matches($labelsText, '"((?:[^"\\]|\\.)*)"\s*:\s*"(#[0-9A-Fa-f]{3,8})"')) {
        $knownLabels[$m.Groups[1].Value] = $m.Groups[2].Value
    }
    if ($knownLabels.Count -eq 0) {
        $script:problems += 'The LABELS block has no labels in it.'
        SayBad 'The LABELS block has no labels in it.'
        return
    }
    SayOk "$($knownLabels.Count) labels in the vocabulary."

    # --- labels that differ only by case, spacing or punctuation -------------
    # Every wording is its own label, so 'EXPANSION' and 'Expansion' are two
    # entries: two colours, two filters, and a record quietly splitting in half
    # with nothing to say so. Warn, never block - sometimes both are wanted.
    $byShape = @{}
    foreach ($name in $knownLabels.Keys) {
        $shape = ($name.ToLowerInvariant() -replace '[^a-z0-9]', '')
        if ($shape -eq '') { continue }
        if ($byShape.ContainsKey($shape)) { $byShape[$shape] += $name }
        else                              { $byShape[$shape] = @($name) }
    }
    $nearDupes = 0
    foreach ($shape in $byShape.Keys) {
        if ($byShape[$shape].Count -gt 1) {
            $nearDupes++
            $names = (($byShape[$shape] | Sort-Object) | ForEach-Object { "'$_'" }) -join ' and '
            SayWarn "$names differ only by case or punctuation - that is two labels, two colours, two filters."
        }
    }
    foreach ($name in $knownLabels.Keys) {
        if ($name -ne $name.Trim()) {
            $nearDupes++
            SayWarn "'$name' has a space at the start or end - it will never match the same wording typed without one."
        }
    }
    if ($nearDupes -eq 0) { SayOk 'No two labels differ only by case or punctuation.' }

    # --- weeks and pairs ----------------------------------------------------
    $weekMatches = @([regex]::Matches($data, 'id:\s*"((?:[^"\\]|\\.)*)"'))
    $pairMatches = @([regex]::Matches($data, 'pair:\s*"((?:[^"\\]|\\.)*)"'))

    if ($weekMatches.Count -eq 0) {
        $script:problems += 'No weeks found in the WEEKS array.'
        SayBad 'No weeks found in the WEEKS array.'
        return
    }

    $seenIds    = @{}
    $pairCasing = @{}
    $expected   = @('Mon', 'Tue', 'Wed', 'Thu', 'Fri')
    $chartFiles = @()
    if (Test-Path $chartsPath) { $chartFiles = @(Get-ChildItem -Path $chartsPath -File | Select-Object -ExpandProperty Name) }

    $totalPairs = 0

    for ($w = 0; $w -lt $weekMatches.Count; $w++) {
        $weekId    = $weekMatches[$w].Groups[1].Value
        $weekStart = $weekMatches[$w].Index
        $weekEnd   = if ($w + 1 -lt $weekMatches.Count) { $weekMatches[$w + 1].Index } else { $data.Length }
        $ln        = Get-LineNumber -Text $data -Index $weekStart -Offset $lineOffset

        if ($weekId -notmatch '^\d{4}-W\d{2}$') {
            $script:problems += "Line ${ln}: week id '$weekId' is not YYYY-Wnn."
            SayBad "Line ${ln}: week id '$weekId' is not in YYYY-Wnn form."
        }
        if ($seenIds.ContainsKey($weekId)) {
            $script:problems += "Line ${ln}: week '$weekId' appears twice."
            SayBad "Line ${ln}: week '$weekId' appears twice."
        }
        $seenIds[$weekId] = $true

        $weekPairs = @($pairMatches | Where-Object { $_.Index -gt $weekStart -and $_.Index -lt $weekEnd })
        if ($weekPairs.Count -eq 0) {
            $script:warnings += "Week '$weekId' has no pairs."
            SayWarn "Week '$weekId' has no pairs in it."
            continue
        }

        for ($p = 0; $p -lt $weekPairs.Count; $p++) {
            $totalPairs++
            $pairName  = $weekPairs[$p].Groups[1].Value
            $pairStart = $weekPairs[$p].Index
            $pairEnd   = if ($p + 1 -lt $weekPairs.Count) { $weekPairs[$p + 1].Index } else { $weekEnd }
            $region    = $data.Substring($pairStart, $pairEnd - $pairStart)
            $pln       = Get-LineNumber -Text $data -Index $pairStart -Offset $lineOffset
            $where     = "$weekId $pairName"

            # pair name spelling, held steady across the whole record
            $key = $pairName.ToUpper()
            if ($pairName -cne $key) {
                $script:warnings += "Line ${pln}: pair '$pairName' is not uppercase."
                SayWarn "Line ${pln}: pair '$pairName' is not uppercase - convention is '$key'."
            }
            if ($pairCasing.ContainsKey($key)) {
                if ($pairCasing[$key] -cne $pairName) {
                    $script:warnings += "Line ${pln}: '$pairName' is spelled '$($pairCasing[$key])' elsewhere."
                    SayWarn "Line ${pln}: '$pairName' is spelled '$($pairCasing[$key])' elsewhere in the record."
                }
            } else {
                $pairCasing[$key] = $pairName
            }

            # bias
            $bm = [regex]::Match($region, 'bias:\s*"((?:[^"\\]|\\.)*)"')
            if (-not $bm.Success) {
                $script:problems += "Line ${pln}: $where has no bias."
                SayBad "Line ${pln}: $where has no bias."
            } elseif ($bm.Groups[1].Value -cnotin @('Bullish', 'Bearish', 'Neutral')) {
                $script:problems += "Line ${pln}: $where bias is '$($bm.Groups[1].Value)' - must be Bullish, Bearish or Neutral."
                SayBad "Line ${pln}: $where bias is '$($bm.Groups[1].Value)' - must be Bullish, Bearish or Neutral."
            }

            # Monday range
            $rm = [regex]::Match($region, 'range:\s*"((?:[^"\\]|\\.)*)"')
            if (-not $rm.Success) {
                $script:problems += "Line ${pln}: $where has no range field."
                SayBad "Line ${pln}: $where has no range field."
            } elseif ([string]::IsNullOrWhiteSpace($rm.Groups[1].Value)) {
                $script:warnings += "$where has an empty Monday range."
                SayWarn "Line ${pln}: $where has an empty Monday range - the card will read 'Monday range'."
            }

            # the five days
            $days = @([regex]::Matches($region, '\[\s*"((?:[^"\\]|\\.)*)"\s*,\s*"((?:[^"\\]|\\.)*)"\s*,\s*"((?:[^"\\]|\\.)*)"\s*\]'))
            if ($days.Count -ne 5) {
                $script:problems += "Line ${pln}: $where has $($days.Count) readable day rows, expected 5."
                SayBad "Line ${pln}: $where has $($days.Count) readable day rows, expected 5 (Mon-Fri)."
            } else {
                for ($d = 0; $d -lt 5; $d++) {
                    $dayName = $days[$d].Groups[1].Value
                    $label   = $days[$d].Groups[2].Value
                    $dln     = Get-LineNumber -Text $data -Index ($pairStart + $days[$d].Index) -Offset $lineOffset

                    if ($dayName -cne $expected[$d]) {
                        $script:problems += "Line ${dln}: $where day $($d + 1) is '$dayName', expected '$($expected[$d])'."
                        SayBad "Line ${dln}: $where day $($d + 1) is '$dayName', expected '$($expected[$d])'."
                    }
                    if (-not $knownLabels.ContainsKey($label)) {
                        $script:problems += "Line ${dln}: $where $dayName - '$label' is not in LABELS."
                        SayBad "Line ${dln}: $where $dayName - '$label' is not in LABELS (renders as a red NEW LABEL flag). Add it there with a colour."
                    }
                }
            }

            # the chart, matched the way GitHub Pages matches it: exactly
            $wantChart = "$weekId`_$pairName.png"
            $exact = @($chartFiles | Where-Object { $_ -ceq $wantChart })
            if ($exact.Count -eq 0) {
                $loose = @($chartFiles | Where-Object { $_ -ieq $wantChart })
                if ($loose.Count -gt 0) {
                    $script:problems += "Chart case mismatch: file is '$($loose[0])', page asks for '$wantChart'."
                    SayBad "Chart case mismatch: file is '$($loose[0])' but the page asks for '$wantChart'."
                    SayInfo 'Works on Windows, breaks on GitHub Pages.'
                } else {
                    $script:warnings += "No chart for $where (looking for Charts\$wantChart)."
                    SayWarn "No chart for $where - expecting Charts\$wantChart"
                }
            }
        }
    }

    # newest week first
    $ids = @($weekMatches | ForEach-Object { $_.Groups[1].Value })
    $sorted = @($ids | Sort-Object -Descending)
    if (-not ($ids -join ',').Equals(($sorted -join ','))) {
        $script:warnings += 'Weeks are not in newest-first order.'
        SayWarn 'Weeks are not in newest-first order - the newest should sit at the top.'
    }

    if ($script:problems.Count -eq 0) {
        SayOk "$($weekMatches.Count) weeks, $totalPairs pairs, every day row valid."
    }

    $script:newestWeek = $ids[0]
}


# ---------------------------------------------------------------------------
# 3. Publishing
# ---------------------------------------------------------------------------

function Invoke-Git {
    param([string[]]$Arguments)
    # Git writes ordinary progress and warnings to stderr. Under PowerShell 5.1
    # that arrives as an ErrorRecord, which a 'Stop' preference would turn into
    # a crash, so this runs with the preference relaxed and judges the result on
    # the exit code alone.
    $previous = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $out = & git -C $root @Arguments 2>&1
        $code = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $previous
    }
    [pscustomobject]@{ Ok = ($code -eq 0); Output = ($out | Out-String).Trim() }
}

function Publish-Journal {
    SayHead '3. Publishing'

    if (-not (Test-Path (Join-Path $root '.git'))) {
        SayBad 'This folder is not a git repository yet.'
        SayInfo 'Run:  .\publish.ps1 -Remote https://github.com/<you>/<repo>.git'
        return $false
    }

    if ($Remote) {
        $existing = Invoke-Git @('remote')
        if ($existing.Output -match '\borigin\b') { Invoke-Git @('remote', 'set-url', 'origin', $Remote) | Out-Null }
        else { Invoke-Git @('remote', 'add', 'origin', $Remote) | Out-Null }
        SayOk "Remote set to $Remote"
    }

    $status = Invoke-Git @('status', '--porcelain')

    if ([string]::IsNullOrWhiteSpace($status.Output)) {
        # Nothing new to save. There may still be a finished commit from an
        # earlier -NoPush run waiting to go out, so this falls through to the
        # push rather than stopping here.
        SayInfo 'No new edits to commit.'
    }
    else {
        Say ''
        SayInfo 'About to publish:'
        foreach ($line in $status.Output -split "`r?`n") { SayInfo "  $line" }
        Say ''

        Invoke-Git @('add', '-A') | Out-Null

        if (-not $Message) {
            $verb = 'Update'
            $head = Invoke-Git @('log', '-1', '--oneline')
            if (-not $head.Ok) {
                $verb = 'Add'
            } else {
                $committed = Invoke-Git @('show', 'HEAD:index.html')
                if ($committed.Ok -and $script:newestWeek -and $committed.Output -notmatch [regex]::Escape($script:newestWeek)) { $verb = 'Add' }
            }
            $Message = if ($script:newestWeek) { "$verb $($script:newestWeek)" } else { 'Update journal' }
        }

        $commit = Invoke-Git @('commit', '-m', $Message)
        if (-not $commit.Ok) {
            SayBad 'Commit failed.'
            SayInfo $commit.Output
            return $false
        }
        SayOk "Committed: $Message"
    }

    if ($NoPush) {
        SayInfo 'Not pushed (-NoPush). Run .\publish.ps1 again to send it.'
        return $true
    }

    if ((Invoke-Git @('remote')).Output -notmatch '\borigin\b') {
        SayBad 'Committed locally, but no GitHub remote is set - nothing was pushed.'
        SayInfo 'Run once:  .\publish.ps1 -Remote https://github.com/<you>/<repo>.git'
        return $false
    }

    $branch = (Invoke-Git @('rev-parse', '--abbrev-ref', 'HEAD')).Output

    # If the branch already tracks origin and has nothing new on it, there is
    # genuinely nothing to send.
    $ahead = Invoke-Git @('rev-list', '--count', "origin/$branch..HEAD")
    if ($ahead.Ok -and $ahead.Output -eq '0') {
        SayOk 'GitHub is already up to date.'
        return $true
    }

    $push = Invoke-Git @('push', '-u', 'origin', $branch)
    if (-not $push.Ok) {
        SayBad 'Push failed. Your work is committed locally - nothing is lost.'
        SayInfo $push.Output
        if ($push.Output -match 'non-fast-forward|fetch first|rejected') {
            Say ''
            SayInfo 'GitHub has a change this computer does not - usually an edit made'
            SayInfo 'in the browser. Pull it down first, then publish again:'
            SayInfo "    git pull --rebase origin $branch"
            SayInfo '    .\publish.ps1'
            SayInfo 'Do not force-push: that would erase whatever is on GitHub.'
        } else {
            SayInfo 'If this is the first push, a GitHub sign-in window may be waiting behind this one.'
        }
        return $false
    }

    SayOk "Pushed to origin/$branch."
    SayInfo 'GitHub Pages usually rebuilds within a minute.'
    $true
}


# ---------------------------------------------------------------------------

$script:newestWeek = $null

Say ''
Say '  Weekly Model Journal - publish'
Say '  ------------------------------'

Repair-ChartNames
Test-Journal

if ($problems.Count -gt 0) {
    Say ''
    Write-Host "  Stopped. $($problems.Count) problem(s) to fix above." -ForegroundColor Red
    Write-Host '  Nothing was committed or pushed.' -ForegroundColor Red
    Say ''
    exit 1
}

if ($warnings.Count -gt 0) {
    Say ''
    Write-Host "  $($warnings.Count) warning(s) - not blocking." -ForegroundColor Yellow
}

if ($CheckOnly) {
    Say ''
    Write-Host '  Checks passed. Nothing published (-CheckOnly).' -ForegroundColor Green
    Say ''
    exit 0
}

$ok = Publish-Journal

Say ''
if ($ok) { Write-Host '  Done.' -ForegroundColor Green } else { Write-Host '  Not published - see above.' -ForegroundColor Red }
Say ''
if ($ok) { exit 0 } else { exit 1 }
