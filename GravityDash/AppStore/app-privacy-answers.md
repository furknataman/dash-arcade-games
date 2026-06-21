# App Privacy answers (App Store Connect → App Privacy)

The App Privacy "nutrition label" can't be set via API — fill it once in the
ASC web UI. These answers match what Google AdMob collects (with ATT), plus our
on-device-only storage. Verify against AdMob's current guidance if unsure.

## Do you or your third-party partners collect data? → **Yes**

Declare these data types (AdMob):

### 1. Identifiers → Device ID
- Used for: **Third-Party Advertising**, Developer's Advertising or Marketing, Analytics
- Linked to the user's identity: **No**
- Used for tracking: **Yes**

### 2. Usage Data → Product Interaction
- Used for: **Analytics**, Third-Party Advertising
- Linked to identity: **No**
- Used for tracking: **Yes**

### 3. Usage Data → Advertising Data
- Used for: **Third-Party Advertising**
- Linked to identity: **No**
- Used for tracking: **Yes**

### 4. Diagnostics → Crash Data
- Used for: **App Functionality**
- Linked to identity: **No**
- Used for tracking: **No**

> Our own code stores only on-device data (best score, coins, settings via
> UserDefaults) — that is NOT "collected" in Apple's sense, so don't declare it.

## After filling
1. Click **Publish** on the App Privacy section.
2. Go to the version → answer **Advertising Identifier (IDFA): Yes** (we use
   AdMob; tick "Serve advertisements within the app"). Export compliance is
   already handled (ITSAppUsesNonExemptEncryption=false).
3. Click **Add for Review / Submit**.
