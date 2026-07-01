# Support

## Self-serve

1. **[docs/troubleshooting.md](docs/troubleshooting.md)** — most
   "it doesn't work" cases are covered; start there.
2. **[docs/testing-matrix.md](docs/testing-matrix.md)** — confirm
   your target paste-app is in the manual test matrix; if not, see
   the "Reporting a new target" section.

## Where to ask

| Kind of question              | Where                              |
| ----------------------------- | ---------------------------------- |
| Bug / regression              | GitHub issue — `bug_report.yml`    |
| "Will it work with X?"        | GitHub issue — `compatibility_report.yml` |
| "How do I / why does Y…"      | GitHub Discussions (preferred)     |
| Security issue                | `security@attachclip.example.com` (see [SECURITY.md](SECURITY.md)) |
| Feature request               | GitHub issue — `feature_request.yml` |

We do not maintain a Discord/Slack/Mastodon at this time.

## Response time

This is an alpha. We try to acknowledge new issues within a week
and to ship fixes in the next pre-release tag. Critical regressions
that affect every macOS user are escalated faster.

## What to include when asking

|                            | Required                                           |
| -------------------------- | -------------------------------------------------- |
| OS                         | macOS 12 / 13 / 14 / 15? Apple Silicon or Intel?   |
| Thunderbird version        | From `About Thunderbird`                           |
| AttachClip version         | `git describe` or installed `.xpi`                  |
| Paste target app + version | e.g. WeChat 3.9.0                                  |
| Attachment type + size     | e.g. 12 MB PDF, scanned image, ZIP, etc.           |
| Reproduction steps         | "Open message X → right-click attachment → …"     |

Please include the **console** errors:

```
Thunderbird → Tools → Developer Tools → Browser Console
  filter: AttachClip
```

…and the helper's `os_log` output:

```
log stream --predicate 'subsystem == "com.attachclip.host"' --info
```

Redact anything sensitive before pasting into a public issue.

## Escalation

If you believe the issue is **urgent and security-relevant** —
for example, the helper is uploading data — write directly to
`security@attachclip.example.com` *before* filing a public ticket.
See [SECURITY.md](SECURITY.md) for the disclosure timeline.
