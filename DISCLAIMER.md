# Disclaimer

DevNotch is an **independent, unofficial** tool. It is not affiliated with,
endorsed by, sponsored by, or approved by Anthropic PBC or any of its
affiliates. "Claude" and "Anthropic" are trademarks of Anthropic PBC, used here
nominatively only to identify the service this tool integrates with.

## Use at your own risk

This software is provided "as is", **without warranty of any kind**. See the
`LICENSE` file. The author accepts no responsibility for:

- Changes Anthropic makes to claude.ai that break this tool.
- Any action Anthropic may take with respect to third-party integrations.
- Any loss, damage, or liability arising from use of this tool.
- Any consequence of storing your session cookie on your machine.

## How it works (honest summary)

DevNotch reads:
- your local Claude Code logs under `~/.claude/projects/` (always);
- your claude.ai plan-meter data via an **undocumented internal endpoint** on
  `https://claude.ai/`, **only** after you explicitly sign in through the
  app's embedded browser window.

It uses your own authenticated session in the same way your browser does. No
traffic is routed through any third-party server. See `PRIVACY.md` for
specifics.

## Terms of service considerations

Automated access to undocumented API endpoints of claude.ai exists in a grey
area of Anthropic's terms. Anthropic may, at their discretion, change the API,
disable cookie-based access for non-browser clients, or ask for the tool to be
modified or removed. By using DevNotch you accept that the live-data feature
may stop working at any time without notice.

If you represent Anthropic and have concerns, please open an issue on this
repository — we will cooperate promptly.

## No monetization of Anthropic's data

DevNotch is open source and does not resell, proxy, or redistribute any
data returned by claude.ai. It is a local viewer for your own account.
