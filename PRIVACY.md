# Privacy Policy

*Last updated: 2026-04-16*

ClaudeNotch is a **local, client-only** macOS app. This document explains, in plain
terms, exactly what data the app touches and where it goes.

## Short version

- We read **your own** Claude Code logs from `~/.claude/projects/` — they stay on your Mac.
- If you sign in to claude.ai through the in-app window, the resulting session cookie is
  stored **in your macOS Keychain** and used *only* to request your own plan-meter data
  directly from claude.ai.
- **We do not have a server.** The app never sends any of your data to us or to any
  third party. All network traffic is between your Mac and claude.ai (if you connect).
- **No analytics, no telemetry, no crash reporting, no tracking.**

## What the app reads locally

1. **`~/.claude/projects/**/*.jsonl`** — written by Claude Code. The app parses these
   to compute session/weekly token estimates and to list your recent sessions. Nothing
   leaves your machine from this path.
2. **Git `.git/HEAD`** of the working directory of each Claude Code session, to display
   the branch name. Read-only.
3. **macOS system audio volume**, to drive the volume HUD. Never recorded or stored.

## What the app sends over the network (only if you connect claude.ai)

When you use *Connect to claude.ai…*, the app opens Anthropic's real login page inside
a `WKWebView`. When you finish signing in, the app captures the `sessionKey` cookie
that claude.ai itself set in that webview and stores it in the macOS Keychain under
service identifier `com.alejandrovallejo.ClaudeNotch`.

After that, the app periodically (every 45 s by default) sends a single HTTPS `GET`
request to:

- `https://claude.ai/api/organizations/{your-org-uuid}/usage`

with your session cookie attached. The response (your own plan-meter data) is used
to draw the progress bars and then discarded. We do **not** log, store, or forward
that response to anyone.

## Third parties

- **Anthropic (claude.ai)** is the only remote destination the app ever talks to, and
  only when you have explicitly signed in through the app.
- We do not use Google Analytics, Firebase, Sentry, Mixpanel, PostHog, Amplitude, or
  any other analytics/error service.

## Your data, your control

- **Sign out** at any time from Preferences → Claude account → Sign out. This deletes
  the session cookie from your Keychain.
- **Uninstall** the app by dragging it to the Trash and, if you want to wipe state,
  delete `~/Library/Preferences/com.alejandrovallejo.ClaudeNotch.plist`.
- The Keychain item is protected by macOS at rest and unlocked only while your user
  session is unlocked (`kSecAttrAccessibleAfterFirstUnlock`).

## Security model, honestly

- The `sessionKey` cookie is a bearer credential for your claude.ai account. Anyone
  with read access to your Keychain (or your unlocked Mac) can use it to impersonate
  you on claude.ai until you sign out or rotate it. This is the same threat model as
  having claude.ai open in Safari.
- The claude.ai usage endpoint is an **undocumented internal API**. Anthropic can
  change or block it at any time; when that happens, live data stops working until
  we ship an update. The local estimate (from Claude Code JSONL) keeps working in
  the meantime.

## Changes

If this policy ever changes, the change will be committed to this repository with a
new `Last updated` date. There is no separate "we will email you" mechanism because
we do not have your email.

## Contact

Open a GitHub issue in this repo for any privacy-related question.
