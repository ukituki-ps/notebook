# Unit execution report — notebook-search-deploy-e2e (E1546 s20, u03)

- **Unit:** notebook-search-deploy-e2e (sde-infra, plain)
- **Base:** 11b752cd32ba34e15ffd7f1a4d93a6d612614528

Deploy/E2E assets are present at the unit base: `web/e2e/notes-search.spec.js`,
`deploy/path1/e2e-preview.sh`, `path1.project.json`, UI-GRAPH. Unit verification
does not run Chromium (stand E2E runs at s20c per platform split).

## Verification

| Command | Result |
|---|---|
| `go build ./...` | OK |
| `go vet ./...` | OK |
| `go test -count=1 ./...` | ok 2.805s |

fixed_confirmed: true (assets present; stand E2E is s20c).
