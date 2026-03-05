# Release Build & Google Play Store

## 1. Juz corrections (done in app)

- **Juz 11** starts at At-Tawbah **9:94**
- **Juz 14** starts at Al-Hijr **15:2**
- **Juz 20** starts at An-Naml **27:60**
- **Juz 21** starts at Al-Ankabut **29:45**

## 2. Font (TTF) for the app

The app uses the **IndoPak** font:

- **Path:** `assets/fonts/font.ttf`
- It is already declared in `pubspec.yaml` and is included in the build. No extra step needed for the font when publishing.
- For Play Store, you do **not** upload the TTF separately; it is bundled inside the APK/App Bundle.

## 3. Create a signing keystore (first time only)

From the project root:

```bash
cd android
keytool -genkey -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

Answer the prompts and **keep the passwords and `.jks` file safe**. You need them for every future release.

## 4. Configure signing

1. Copy the example properties file:
   ```bash
   cp android/key.properties.example android/key.properties
   ```

2. Edit `android/key.properties` and set:
   - `storePassword` – keystore password
   - `keyPassword` – key password
   - `keyAlias` – alias you used (e.g. `upload`)
   - `storeFile` – path to the keystore, e.g. `upload-keystore.jks` if it’s in `android/`, or `app/upload-keystore.jks` if it’s in `android/app/`

3. **Do not commit** `key.properties` or your `.jks` file. Add to `.gitignore` if needed:
   - `android/key.properties`
   - `android/*.jks`
   - `android/app/*.jks`

## 5. Build for Google Play (recommended: App Bundle)

App Bundle is what Play Store expects and usually gives smaller downloads:

```bash
flutter build appbundle
```

Output:

- `build/app/outputs/bundle/release/app-release.aab`

Upload this **.aab** file in Google Play Console under your app’s Release → Production (or testing track).

## 6. Build release APK (optional)

If you need a single APK (e.g. for sideloading or other stores):

```bash
flutter build apk --release
```

Output:

- `build/app/outputs/flutter-apk/app-release.apk`

For a split APK per ABI (smaller size):

```bash
flutter build apk --split-per-abi --release
```

## 7. Version for Play Store

In `pubspec.yaml`:

- `version: 1.0.0+2` → **1.0.0** is `versionName`, **2** is `versionCode` (integer).
- For each new upload to Play Store, increase **versionCode** (e.g. `1.0.0+3`).

## 8. Checklist before upload

- [ ] `android/key.properties` is set and **not** committed.
- [ ] Keystore (`.jks`) is backed up securely.
- [ ] `flutter build appbundle` completes without errors.
- [ ] Version in `pubspec.yaml` has a new `versionCode` for the new release.
- [ ] App font (IndoPak / `assets/fonts/font.ttf`) is already in the project and will be inside the bundle.
