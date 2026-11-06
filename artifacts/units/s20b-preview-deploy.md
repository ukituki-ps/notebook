# s20b preview deploy — E8895

- Target stand: `test2` (https://test2.nexus.ukituki.tech)
- Deploy request: the integrated feature branch commit that contains this
  marker and the s20a integration report.
- Expected path: ORC -> host stand-runner queue -> `deploy/path1/preview-deploy.sh test2 <ref>`.
- Provenance expected at `deploy/stands/.runtime/test2/{build,deploy}-provenance.json`
  on the runner host.
