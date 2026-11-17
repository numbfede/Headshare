# Signing & notarization

Releases are built by GitHub Actions. If the five secrets below exist, the workflow signs the app
with a **Developer ID**, notarizes the DMG with Apple and staples the ticket, so users can open
Headshare without any Gatekeeper warning. Without them, releases are ad-hoc signed as before.

Requires a paid **Apple Developer Program** membership.

## 1. Developer ID certificate → `MACOS_CERTIFICATE_P12`, `MACOS_CERTIFICATE_PASSWORD`

1. Xcode › Settings › Accounts › your team › **Manage Certificates…** › **+** › **Developer ID Application**.
2. Open **Keychain Access** › login › My Certificates, right-click
   *Developer ID Application: …* › **Export…** › save as `.p12` with a password.
3. In Terminal: `base64 -i DeveloperID.p12 | pbcopy`
4. GitHub repo › Settings › Secrets and variables › Actions › **New repository secret**:
   - `MACOS_CERTIFICATE_P12` = the clipboard contents
   - `MACOS_CERTIFICATE_PASSWORD` = the export password

## 2. App Store Connect API key → `NOTARY_KEY_P8`, `NOTARY_KEY_ID`, `NOTARY_ISSUER_ID`

1. [App Store Connect](https://appstoreconnect.apple.com/access/integrations/api) › Users and Access ›
   Integrations › **Team Keys** › **+**, name it "Notary", access **Developer**. Download the `.p8` (only once).
2. In Terminal: `base64 -i AuthKey_XXXXXXXXXX.p8 | pbcopy`
3. Add the secrets:
   - `NOTARY_KEY_P8` = the clipboard contents
   - `NOTARY_KEY_ID` = the Key ID shown next to the key
   - `NOTARY_ISSUER_ID` = the Issuer ID shown above the keys list

## 3. Publish

Bump `CFBundleShortVersionString` in `Resources/Info.plist` and push to `main`.
The workflow log shows `The staple and validate action worked!` and
`source=Notarized Developer ID` when everything is in place.
