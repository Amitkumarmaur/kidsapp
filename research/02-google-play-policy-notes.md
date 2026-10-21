# Google Play policy notes (researched 21 October 2026)

This is a product checklist built from Google's published policy pages, not legal advice.
Policies change; re-check the linked pages before every submission.

## 1. Accessibility Service and parental control apps
- Parental control apps are temporarily eligible to declare themselves accessibility tools.
- They must still meet prominent disclosure and consent rules and complete the Play Console
  declaration for apps that are not accessibility tools.
- Parental control apps are defined as apps that let parents, guardians or authorized caregivers
  monitor, manage and restrict a child's access to devices, content and online activity
  (app usage tracking and limits, website filtering, screen time, location tracking,
  communication monitoring).
- Decision for v1: do not use the Accessibility Service. Use Usage Access plus overlay for
  blocking. Add Accessibility only if testing proves blocking is too slow, then file the declaration.

## 2. Prominent disclosure and consent
- Disclosure must appear inside the app. A privacy policy or terms of service alone is not enough.
- Show it before requesting sensitive permissions (location, usage access, overlay, device admin).

## 3. Families Policy (applies if children are a target audience)
- No sensitive child data (device IDs for ads, etc.) sent to ad or analytics SDKs.
- Use only SDKs approved for child-directed use.
- Include an appropriate message about the importance of parental supervision.
- Do not request the device phone number from TelephonyManager.
- Use the Companion Device Manager for Bluetooth where applicable.
- Failure can lead to app removal or suspension.

## 4. Dates
- Play Console lists 28 October 2026 as the date policy compliance becomes mandatory for apps that
  target Android 17 or later (API 37+). Re-check the Play Console policy page before launch.

## 5. Permissions plan
| Permission | Purpose | Review risk |
| --- | --- | --- |
| Usage Access | Per-app time and limits | Medium |
| Display over other apps | Block screen | Medium |
| Accessibility Service | Faster blocking (only if needed) | High |
| Fine and background location | Live location, geofences | High: needs disclosure and demo video |
| Foreground service | Keep tracking alive | Medium |
| Device Admin | Uninstall protection, lock | Medium |

## 6. Submission checklist
- [ ] Privacy policy URL live and linked in the listing
- [ ] Data Safety form matches the real data flows
- [ ] Permission declaration forms with a short demo video per sensitive permission
- [ ] Families Policy self-review
- [ ] Target API level meets the current requirement
- [ ] Persistent child-visible notification while monitoring
- [ ] No stealth features, no icon hiding

## Sources
- https://support.google.com/googleplay/android-developer/answer/16935362?hl=en-GB
- https://support.google.com/googleplay/android-developer/answer/9893335
- Google Play guidance on parental control apps and the accessibility declaration
  (support.google.com/googleplay/android-developer/answer/10964491)
