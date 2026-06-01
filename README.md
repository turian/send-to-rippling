# Send to Rippling

A tiny macOS app that adds a **"Send to Rippling"** entry to the **PDF**
dropdown in every print dialog, so you can email a receipt to your Rippling
expenses inbox in one step instead of two.

## How it works

macOS lets any app drop a bundle into `~/Library/PDF Services/` to appear
under the **PDF ▾** button next to "Save as PDF" and "Mail PDF" in the
standard print dialog. When you pick it, the OS hands the generated PDF to
the app. This app shows a confirmation window with the PDF preview, lets you
label the receipt, and emails it via SMTP to `receipts@rippling.com` (or
another address you configure).

> **The From-header constraint.** Rippling matches incoming receipts to your
> account by the email's `From:` header. The sender address must be the one
> Rippling has on file for you, *and* your mail must pass that domain's
> SPF/DKIM/DMARC checks. In practice this means sending through your work
> account's own SMTP server (the path this app takes). Sending from a generic
> relay with a spoofed From: address will be rejected by Rippling, by Google,
> or by both.

## Status

Early — works for the author, no notarization or signing, no tests yet, SMTP
auth only (no OAuth). Pull requests welcome.

## Build

Prerequisites:

- macOS 13 (Ventura) or later
- Xcode 15+
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)

```
git clone https://github.com/rjwalters/send-to-rippling.git
cd send-to-rippling
xcodegen generate
open SendToRippling.xcodeproj
```

In Xcode, select the **Send to Rippling** scheme and ⌘B to build, or
⌘R to run. The build product is `Send to Rippling.app`.

## Install

Drop the built `.app` into `~/Library/PDF Services/`:

```
cp -R "/path/to/Send to Rippling.app" ~/Library/PDF\ Services/
```

The next print dialog you open will list **Send to Rippling** under PDF ▾.

> Because the app is unsigned, first launch may show a Gatekeeper warning.
> Right-click → Open in Finder once to authorize, or:
> `xattr -dr com.apple.quarantine "$HOME/Library/PDF Services/Send to Rippling.app"`

## Configuration

The first launch opens **Preferences**. All fields:

| Field | Description | Example |
|---|---|---|
| Host | SMTP server | `smtp.gmail.com` |
| Port | SMTP port | `587` |
| Security | TLS mode | STARTTLS |
| Username | SMTP auth user (usually full email) | `you@yourcompany.com` |
| Password | SMTP password or app password | (see below) |
| Your name | Display name in the From: header | `Jane Doe` |
| Sender email | The From: address Rippling matches you by | `you@yourcompany.com` |
| Default recipient | Where receipts get mailed | `receipts@rippling.com` |

Passwords are stored in the macOS Keychain. Everything else lives in
`UserDefaults`.

---

### Setting up Gmail / Google Workspace

Three paths below depending on your role. Most users will follow path 1.

#### Path 1: User — my admin already has Workspace set up correctly

You need an **app password** (a 16-character secondary credential that
bypasses 2-Step Verification for a specific app). With a Workspace SKU and
correct admin config, you can generate one yourself:

1. Visit **https://myaccount.google.com/security**. Confirm **2-Step
   Verification** is shown as **On**. If not, turn it on — pick any second
   factor (phone, authenticator, security key).
2. Visit **https://myaccount.google.com/apppasswords**.
3. Type a label like `Send to Rippling`. Click **Create**.
4. Google shows 16 lowercase characters in 4 groups of 4. Copy them; **strip
   the spaces** before pasting into our Preferences password field.
5. In Preferences, use:
   - **Host**: `smtp.gmail.com`
   - **Port**: `587`
   - **Security**: STARTTLS
   - **Username**: your full work email
   - **Password**: the app password (no spaces)
   - **Sender email**: same as Username
6. Click **Save Password**.

If `https://myaccount.google.com/apppasswords` shows
**"The setting that you are looking for is not available for your account"**,
your Workspace admin (possibly you, see path 2) needs to enable some
prerequisites first.

#### Path 2: Workspace admin — enabling app passwords for the org

Google has been progressively tightening what Workspace tiers can use app
passwords. The toggles are sometimes hidden behind other toggles. The order
that worked for us:

1. **Enable passwordless login first.** This is the non-obvious prerequisite
   that unlocks neighbouring 2SV/app-password controls on many Workspace
   tiers. In **admin.google.com**:
   - Go to **Security → Authentication → Passwordless** (or **Passkeys**)
   - Turn it **On** for the relevant org units
2. **Allow 2-Step Verification.**
   - **Security → Authentication → 2-Step Verification**
   - **Allow users to turn on 2-Step Verification**: ✓
3. **Check there's no "Less secure apps" block** if your console still shows
   that section: set it to **"Allow users to manage their access to less
   secure apps"**.
4. **Verify Advanced Protection isn't enforced** for the target users — APP
   forcibly disables app passwords. **Security → Authentication → Advanced
   Protection Program**.
5. Wait a few minutes for changes to propagate, sign out and back in.

Once those are in place, individual users can follow path 1 to generate an
app password.

If you've done all of the above and the app passwords page still says "not
available", your Workspace SKU has the feature permanently disabled. The
remaining options are **OAuth** (not yet implemented in this app — PRs
welcome) or a third-party email API (Resend, Postmark, etc.) with DNS
verification of your domain.

#### Path 3: Workspace admin — (optional) centralized SMTP relay

You can route the app's mail through a **Workspace SMTP relay** at
`smtp-relay.gmail.com` instead of direct `smtp.gmail.com`. This is useful if
you want:

- A single point of policy / logging for outbound mail from your org
- The ability to authenticate from a fixed office IP without per-user auth
- A consistent endpoint for tools you distribute to colleagues

To set it up:

1. **admin.google.com → Apps → Google Workspace → Gmail → Routing**
2. Scroll to **SMTP relay service** → **Configure**
3. Settings:
   - **Description**: e.g. `Send to Rippling relay`
   - **Allowed senders**: *Only addresses in my domains*
   - **Authentication**: ✓ *Require SMTP Authentication* (leave the IP
     whitelist unchecked unless every sender has a fixed IP)
   - **Encryption**: ✓ *Require TLS encryption*
4. Save.

Users then configure the app with **Host**: `smtp-relay.gmail.com` instead of
`smtp.gmail.com` — everything else is identical, and they still need their
own app password. The relay endpoint accepts the same credentials as direct
SMTP; it does **not** bypass the 2SV / app-password requirement.

#### Path 4: Personal Gmail (just `@gmail.com`, no Workspace)

Simpler than Workspace:

1. **https://myaccount.google.com/security** → turn on 2-Step Verification
2. **https://myaccount.google.com/apppasswords** → generate one
3. Configure the app per path 1

---

### Other SMTP providers

Anything that speaks SMTP+AUTH with TLS will work.

| Provider | Host | Port | Security | Notes |
|---|---|---|---|---|
| Microsoft 365 / Outlook | `smtp.office365.com` | `587` | STARTTLS | Modern Auth required for many tenants — may need an app password generated in Microsoft Authenticator |
| iCloud Mail | `smtp.mail.me.com` | `587` | STARTTLS | Use an **app-specific password** from appleid.apple.com |
| Fastmail | `smtp.fastmail.com` | `465` | SSL/TLS | Generate an app password in Settings → Privacy & Security |
| Custom MTA | your host | your port | STARTTLS or SSL | Username/password auth required |

For any provider, the **Sender email** field must be the address your
Rippling account is registered under, and your mail must pass SPF/DKIM/DMARC
for that domain.

---

### Troubleshooting

| What you see | Likely cause | Fix |
|---|---|---|
| App passwords page: "The setting you are looking for is not available for your account" | 2SV not on, or Workspace policy hasn't enabled the prerequisite toggles | See path 2 above — try enabling passwordless login first |
| `curl (67) Login denied`, server response `535-5.7.8 Username and Password not accepted` | You're sending your regular Google password with 2SV enabled | Use an app password instead |
| `curl (67) Login denied`, server response `5.7.0 Authentication Required` | Authentication didn't happen (empty Username/Password) | Check Preferences |
| Mail sends successfully but doesn't appear in Rippling | The `From:` header doesn't match what Rippling has on file, **or** the mail failed SPF/DKIM and was silently dropped | Send a manual test from your mail client to `receipts@rippling.com` — if that lands, double-check the Sender email field matches your Rippling profile exactly. If it doesn't land, your domain auth is the problem (SPF/DKIM/DMARC). |
| App doesn't appear in print dialog's PDF dropdown | Not installed in the right location, or Launch Services hasn't refreshed | Confirm the .app is at `~/Library/PDF Services/Send to Rippling.app` (with the space in "Send to Rippling.app"), then sign out and back in or reboot |
| Gatekeeper blocks first launch | App isn't signed/notarized | Right-click → Open, or `xattr -dr com.apple.quarantine ...` |

## Use

1. ⌘P in any app → the system print dialog appears
2. **PDF ▾** in the lower left → **Send to Rippling**
3. The Review window opens with the PDF preview. Optionally edit the subject
   or add a memo. Click **Send**.
4. The PDF lands in your Rippling expenses inbox within a minute.

To change settings later, double-click `Send to Rippling.app` directly (no
PDF argument), or relaunch via the print dialog and click the "Preferences…"
link in the Review window's From row.

## Architecture

```
SendToRipplingApp.swift   App entry, AppDelegate, window management.
                          Receives PDFs via application(_:open:) and opens
                          the Review window. If unconfigured, opens
                          Preferences alongside.
ReviewWindow.swift        Post-print UI: PDFKit preview, recipient,
                          subject, memo, Send/Cancel, opens Preferences.
PreferencesWindow.swift   SMTP config form. Reachable via ⌘, (SwiftUI
                          Settings scene) or directly from AppDelegate.
AppSettings.swift         UserDefaults wrapper for non-secret config.
Keychain.swift            Generic-password Keychain wrapper for the SMTP
                          password.
SMTPSender.swift          Composes RFC 5322 multipart/mixed message and
                          pipes it to /usr/bin/curl — the simplest
                          battle-tested STARTTLS/AUTH/MIME client already
                          present on every Mac.
```

## Known limitations

- **No notarization / code signing** — Gatekeeper will warn on first launch.
- **SMTP only** — no Gmail OAuth, Microsoft Graph, or Mail.app handoff yet.
  Users at Workspace tiers without app passwords are blocked until OAuth
  lands.
- **No tests yet.**
- **PDF Services is per-user** — install in each user's
  `~/Library/PDF Services/`, or `/Library/PDF Services/` for all users on a
  Mac.

## Contributing

Open issues and pull requests welcome — especially:

- Gmail OAuth (XOAUTH2) support to remove the app-password dependency
- Microsoft Graph send for Outlook/365 users without SMTP AUTH enabled
- Code signing + a notarized DMG for easy install
- An app icon

## License

MIT — see [LICENSE](./LICENSE).
