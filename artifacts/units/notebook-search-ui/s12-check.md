# s12 check — notebook-search-ui

- Unit: `notebook-search-ui`
- Execution: `E8363-s20.sde_5fexecution-u02`
- Branch: `orc-exec-E8363-s20.sde_5fexecution-u02`
- HEAD: `9ceafdbd1bede428097d784539093092d0c9156f`
- Worktree: `/workspace/projects/notebook-e8363-u02`
- Code changed: **no**
- Result: **PASS**

## Required commands (run from the worktree root)

```
$ go test -count=1 -run TestUISemantics ./...
ok  	github.com/ukituki-ps/notebook	0.001s
exit=0

$ go test -count=1 ./...
ok  	github.com/ukituki-ps/notebook	2.745s
exit=0
```

## Supporting commands

```
$ node --check web/app.js
(no output)
exit=0

$ go build ./...
exit=0

$ go vet ./...
exit=0

$ go test -count=1 -run 'TestUISemantics|TestNotesSearch' -v ./...
=== RUN   TestNotesSearchFinds
--- PASS: TestNotesSearchFinds (0.05s)
=== RUN   TestNotesSearchNotFound
--- PASS: TestNotesSearchNotFound (0.05s)
=== RUN   TestNotesSearchCaseInsensitive
--- PASS: TestNotesSearchCaseInsensitive (0.05s)
=== RUN   TestNotesSearchIsolation
--- PASS: TestNotesSearchIsolation (0.09s)
=== RUN   TestNotesSearchAuthRequired
--- PASS: TestNotesSearchAuthRequired (0.00s)
=== RUN   TestNotesSearchEmptyQuery
--- PASS: TestNotesSearchEmptyQuery (0.05s)
=== RUN   TestNotesSearchWhitespaceQuery
--- PASS: TestNotesSearchWhitespaceQuery (0.05s)
=== RUN   TestNotesSearchEncoding
--- PASS: TestNotesSearchEncoding (0.05s)
=== RUN   TestUISemantics
--- PASS: TestUISemantics (0.00s)
PASS
ok  	github.com/ukituki-ps/notebook	0.377s
```

## Evidence hashes (sha256)

```
4976f733804d030089d6c3e136e456338f139d10fba0349205cce2e6fb50dc1c  web/index.html
438a5ba0bd2674c41a0fbe0fcac1107d9ecdbea64b1192705da50194d29a76bf  web/app.js
0f7fe03cfa2b76d54c2a75d860f0e812f912aa2c9b3eb6d0bc11b9d308483b4a  web/app.css
16d670c6fb871f857ba74346309bf40a515910c2255b16e21cb739acf1d71dbb  web_ui_test.go
419dae4b7993761da12207e7354544f9d718ec4be0ed6f74f7ad9cf06cb4afed  main.go
```

`git status --porcelain` is empty: the checked-out files are exactly HEAD, so
the passing results describe the committed UI, not a local patch.

## Testids verified

`notes-search`, `notes-search-clear`, `notes-search-empty`, plus preserved
`notes-list`, `notes-empty`, `notes-loading`, `notes-error`, and the auth/notes
testids asserted by the same `TestUISemantics` oracle.
