# Security Policy

<p>
  <a href="SECURITY.md">English</a> ·
  <a href="SECURITY.ja.md">日本語</a>
</p>

Tokfuel reads the Claude Code transcripts on your Mac and keeps everything local. A security bug
here is therefore a bug in how your own usage data is handled — please report it privately so it can
be fixed before it is public.

## Supported versions

| Version | Supported |
|---|---|
| Latest [release](https://github.com/Tokfuel/Tokfuel/releases) | ✅ |
| Anything older | ❌ — upgrade first |

Fixes ship in the next release. There are no backports.

## Reporting a vulnerability

**Please don't open a public issue.** Use GitHub's private reporting instead:

**[→ Report a vulnerability](https://github.com/Tokfuel/Tokfuel/security/advisories/new)**
(also reachable from the repo's **Security** tab)

Include what you have:

- Tokfuel version and macOS version
- What an attacker gains, and what they need in order to get it
- Steps to reproduce — a crafted transcript file, a network condition, a command
- Any patch or mitigation you already found

This is a small side project, so expect an acknowledgement within about a week rather than within
hours. You'll be credited in the advisory and the release notes unless you'd rather not be.

## What counts as a vulnerability here

The app's whole security story is "nothing leaves the Mac, and reading transcripts can't hurt you".
Anything that breaks that is in scope:

- **Data leaving the machine.** Any network send other than the opt-in USD→JPY exchange-rate
  request, or usage data (project names, session content, costs) appearing in that request.
- **Code execution.** A crafted transcript file or a crafted retok output that leads to code
  execution, or a way for another process to control which `python3` the app spawns for the cost
  analysis.
- **Local state.** Tokfuel's own stored state (settings, the event log under
  `~/Library/Application Support/Tokfuel`) being readable or writable by something that shouldn't
  reach it.
- **Distribution.** A way to get a modified build to users, e.g. by tampering with a release
  artifact or with the release workflow.

## Out of scope

- **Gatekeeper warnings from ad-hoc-signed builds.** Official releases are signed with a Developer ID
  and notarized by Apple, so they open with no Gatekeeper warning (as documented in the README).
  Local builds and release artifacts from environments without the Developer ID secrets fall back to
  ad-hoc signing; the resulting Gatekeeper prompt is expected and is not a vulnerability.
- **Bugs in `python3` or in upstream [retok](https://github.com/d-date/retok).** retok is vendored
  unmodified — please report those upstream. Tell us if the *way Tokfuel invokes it* is the problem.
- **Attacks that require already controlling the user's account.** Everything Tokfuel reads is
  already readable by that user, so this grants an attacker nothing new.
- **Non-security bugs and crashes.** Those go in a normal
  [bug report](https://github.com/Tokfuel/Tokfuel/issues/new?template=bug-report.md).
