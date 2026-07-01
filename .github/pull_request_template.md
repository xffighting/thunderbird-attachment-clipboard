# Pull Request

Thank you for contributing to AttachClip. Please complete the
checklist below. **CI will not block on this template**, but a
reviewer will block until every relevant box is checked.

## Summary

<!-- One or two sentences. What does this PR do? -->

## Linked issues

<!-- Use "Closes #123" or "Refs #456". -->

## Type of change

- [ ] Bug fix (non-breaking change that fixes an issue)
- [ ] New feature (non-breaking change that adds functionality)
- [ ] Breaking change (existing functionality changes behaviour)
- [ ] Documentation / docs-only
- [ ] Chore / maintenance (renames, refactors, deps)

## Hard privacy & safety checks (all required)

- [ ] I confirm this PR does **not** add any new permission to
      `extension/manifest.json`.
- [ ] I confirm this PR does **not** modify, delete, mark-read or
      otherwise mutate any IMAP / POP message (`messages.update`,
      `messages.delete`, `mailTabs.*`).
- [ ] I confirm this PR does **not** upload attachment bytes
      anywhere (no `fetch`, no `XMLHttpRequest`, no `WebSocket`).
- [ ] I confirm this PR does **not** add telemetry, crash reporting,
      or third-party SDKs.

If any box above cannot be checked, **stop and explain in the
"Privacy notes" section below**.

## Testing

- [ ] I have re-run the relevant rows in
      [docs/testing-matrix.md](../docs/testing-matrix.md).
- [ ] I have updated [docs/testing-matrix.md](../docs/testing-matrix.md)
      if a new paste-target was confirmed.
- [ ] I have added an entry to [CHANGELOG.md](../CHANGELOG.md) under
      the "Unreleased" section.
- [ ] I have run `swift build -c release` (if any Swift file was
      touched).

## Code quality

- [ ] `eslint extension/src` is clean (or warnings justified in the
      PR description).
- [ ] `markdownlint '**/*.md' --ignore node_modules` is clean for
      any modified doc.
- [ ] I have NOT introduced new linter disable comments
      (`eslint-disable-next-line`, etc.) without justification.
- [ ] I have updated the wire protocol in **both** the JS side and
      the Swift side if I touched the protocol.
- [ ] I have bumped the wire `v` field if I added a new message
      type.

## Docs

- [ ] I have updated [docs/architecture.md](../docs/architecture.md) if
      any component boundary changed.
- [ ] I have updated [docs/threat-model.md](../docs/threat-model.md)
      if the trust boundary changed (new permission, new external
      side effect).

## Privacy notes

<!-- Leave empty if the privacy checks above all passed. -->

## Screenshots / recordings

<!-- If you changed UX. -->

## Checklist for the reviewer

- [ ] At least one maintainer pasted the latest commit hash into
      a clean macOS install, installed via `install.sh`, and
      manually re-ran the relevant testing matrix rows.
- [ ] No reviewer noted a console-error regression in the browser
      console for the happy path.
