# Security Policy

## Reporting a vulnerability

If you find a security issue, please **do not open a public GitHub issue**.
Instead, email the maintainer with details: **alexvalleliz84@gmail.com**

I will acknowledge within 72 hours and work with you on a fix. Coordinated
disclosure is appreciated.

## Scope

Security reports are welcome for:

- Keychain / cookie handling
- Any way a third party could read or exfiltrate a user's `sessionKey`
- Any remote code execution, privilege escalation, or sandbox escape
- Any accidental network egress beyond `https://claude.ai/`

Out of scope:

- Issues in Anthropic's claude.ai service itself (report those to Anthropic)
- Social engineering against end users
- Physical-access attacks on an unlocked Mac
