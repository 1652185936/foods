# Android release evidence

Captured on 2026-07-20 from `emulator-5554`, an Android 14 emulator at
1080 x 2400 pixels. The client used the local Compose backend through
`adb reverse tcp:8000 tcp:8000`.

## Screens

- `00-splash-immediate.png`, `01-splash-120ms.png`: native launch branding.
- `02-login.png`: signed-out OTP entry.
- `03-today.png`: meal decision home.
- `04-meals.png`: daily meal record and recognition/manual entry controls.
- `05-fasting.png`: fasting plan selection and start state.
- `06-profile-top.png`, `07-profile-account.png`: profile, preferences, sync,
  export, account deletion, and logout controls.
- `08-launcher-icon.png`: adaptive launcher icon and the final `好好吃饭`
  display name.

Every PNG is an unscaled emulator screenshot and was visually checked for
mojibake, overflow, incoherent overlap, missing assets, and inaccessible primary
controls.

## Executed device checks

```powershell
flutter test integration_test/release_smoke_test.dart -d emulator-5554 `
  --dart-define=ORDIN_API_BASE_URL=http://127.0.0.1:8000

flutter test integration_test/sqlcipher_platform_test.dart -d emulator-5554
```

Both tests passed. The release smoke covered OTP login, a 520 kcal manual meal,
outbox push/pull, visible `数据已同步`, permanent account deletion, and the final
signed-out state. The SQLCipher test verified an encrypted file header,
successful reopen, and typed rejection of a wrong key.

This evidence is an emulator engineering check. It does not replace physical
Android device testing for camera vendors, permission revocation, background
process termination, battery policies, or store-signed upgrades.
