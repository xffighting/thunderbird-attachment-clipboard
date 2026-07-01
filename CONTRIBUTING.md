# Contributing

Thanks for your interest in AttachClip!  We welcome PRs, tests,
documentation fixes, and platform bring-up (Windows, Linux).

## Ground rules

- The PR checklist (`.github/pull_request_template.md`) is the
  contract. **All boxes must be checked.**
- New permissions in `extension/manifest.json` must be justified in
  the PR description.
- Any change to the cache directory structure must update
  `docs/architecture.md`, `docs/native-messaging.md`, and
  `CacheStore.swift`'s header comment in the same commit.
- Any change to the wire protocol must update
  `extension/src/nativeClient.js` and `native-host/macos/Sources/`
  together. Do not ship a one-sided protocol change.

## Local development

```bash
# 1.  Build the helper once
git clone https://github.com/EXAMPLE/thunderbird-attachment-clipboard.git
cd thunderbird-attachment-clipboard
./native-host/macos/install.sh

# 2.  Load the extension in Thunderbird (about:debugging → Load
#     Temporary Add-on → extension/manifest.json).  Edits to any
#     file under extension/src require a "Reload" in
#     about:debugging.

# 3.  Test cycles
./scripts/build_extension.sh        # builds .xpi into scripts/dist/
./scripts/lint_js.sh                # eslint over extension/src
./scripts/lint_md.sh                # markdownlint over docs/, README.md
swift build -c release              # from native-host/macos/
```

## Coding style

- **JavaScript**: ES2020, single-quoted strings, semicolons, 2-space
  indent, no default exports.  Run `eslint` from `scripts/lint_js.sh`.
- **Swift**: Swift 5.7+, 4-space indent, `lowerCamelCase` for
  functions, `UpperCamelCase` for types, no trailing whitespace.
  `swift build -c release` must succeed with no warnings.
- **Markdown**: Sentence-per-line. Hard-wrap at ~100 chars.
  `markdownlint --fix` is safe to run.
- **Commit messages**: Conventional Commits
  (`feat:`, `fix:`, `docs:`, `refactor:`, `test:`, `chore:`).

## Manual test matrix

Before opening a PR, please re-run the entries relevant to your change
in [docs/testing-matrix.md](docs/testing-matrix.md) and tick them off.
We currently accept entries for the following paste targets:

- Finder
- WeChat (Mac)
- Lark (Mac)
- DingTalk (Mac)
- Slack (Mac)
- Thunderbird new-mail

## First time contributors

Look for issues labelled
[`good first issue`](https://github.com/EXAMPLE/thunderbird-attachment-clipboard/issues?q=is%3Aopen+is%3Aissue+label%3A%22good+first+issue%22).
Mentors will pair-review your PR.

## Release process

1. Update `CHANGELOG.md` with the next version.
2. Bump `version` in `extension/manifest.json`.
3. `git tag vX.Y.Z-pre.N && git push origin vX.Y.Z-pre.N`.
4. The `release.yml` workflow publishes the `.xpi` and helper zip
   into a GitHub Release draft.

See [ROADMAP.md](ROADMAP.md) for what's planned.
