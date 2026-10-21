# PRD: Kids Safety & Screen-Time App (Working Title: KidGuard)

Draft v0.1 · 21 October 2026. Text snapshot of the online master doc; diagrams are described in words.

## 1. Overview

KidGuard is a two-app family safety product: a parent app and a child app that together manage screen time, block apps, share location, and alert parents to risk. v1 ships on Android for the child device and on Android and iOS for the parent, with a 3-day free trial and a monthly or yearly subscription.

**Working title:** KidGuard (placeholder; run a trademark and Play Store name check before launch).
**One-line pitch:** A transparent, kid-aware parental control app that helps families set healthy screen-time rules and know where their kids are, without spying.
**Benchmark:** AirDroid Parental Control (Android, 10M+ downloads, 4.5 stars from 159K reviews). It bundles screen time limits, app blocking, location with geofences, live screen mirroring, and remote camera and audio.

**What v1 delivers:**
- Parent and child device pairing in under 2 minutes
- Daily screen-time limits, per-app limits, downtime schedules, and app blocking
- Live location, 30-day route history, and geofence alerts
- Activity reports and real-time alerts
- A visible child-side app with a request-more-time flow
- Subscription billing with a 3-day trial

| Item | Value |
| --- | --- |
| Document status | Draft v0.1 for founder review |
| Platforms (v1) | Child: Android 10+. Parent: Android and iOS |
| Primary market (launch) | India, then global English-speaking markets |
| Currency assumption | INR for India pricing, USD for global; change if needed |

## 2. Problem, goals and non-goals

Parents want to limit phone use and know where their child is, but most tools are either too basic (location only), too invasive (hidden surveillance), or so loose that teens bypass them. KidGuard targets parents of children aged 6 to 17 who want clear rules the child can see and understand.

**Problem statement:** Parents lack a simple, trustworthy way to set and enforce screen-time rules and keep track of a child's safety, and children push back when monitoring feels secret or unfair.

**Goals**
1. Let a parent pair a child's phone and set a first screen-time rule in under 5 minutes.
2. Enforce limits reliably: blocked apps stay blocked for at least 99% of attempts on supported devices.
3. Deliver location updates within 60 seconds of a request and geofence alerts within 2 minutes of crossing.
4. Make monitoring visible to the child so the product passes Google Play review and builds family trust.
5. Reach a free-to-paid trial conversion of at least 8% within 6 months of launch.

**Non-goals for v1**
- No hidden or stealth mode, and no hiding the app icon
- No reading private messages, no keylogging, no social media content scraping
- No remote camera, remote microphone, or live screen mirroring (see roadmap)
- No child-side iOS app (Apple restricts this to its Screen Time APIs)
- No web filtering by AI classification (basic site blocklist moves to v1.1)

**Success looks like:** 10,000 installs and 1,000 paying families within 6 months of public launch, with a Play Store rating of 4.3 or higher (targets to validate against the market).

## 3. Users and personas

| Persona | Who | Main need | Biggest worry | Design response |
| --- | --- | --- | --- | --- |
| Priya, the working parent | Age 30 to 45, 1 to 3 kids, Android or iPhone | Know the child reached home; cut homework-time gaming | Setup is too technical; child will uninstall | Guided pairing, sensible defaults, uninstall alerts |
| Aarav, the child | Age 6 to 12, shared or own Android phone | Fair rules he can see | Feels watched in secret | Child app shows rules, time left, and who set them; request-more-time button |
| Meera, the teen | Age 13 to 17, own phone | Privacy and some freedom | Parent sees everything | No message reading; location sharing visible; negotiated limits |

**Jobs to be done (parent):**
- When my child comes home from school, tell me they arrived so I can stop worrying.
- When it is homework time, pause games and social apps so I do not have to argue.
- When my child asks for more time, let me approve in one tap from anywhere.

**Age bands and defaults** (starting suggestions; validate with pediatric guidance and parent interviews)

| Age band | Default screen-time cap | Default blocked categories | Location sharing |
| --- | --- | --- | --- |
| 6 to 9 | 1.5 hours per day | Social, dating, adult | Always on, parent controlled |
| 10 to 12 | 2 hours per day | Social, dating, adult | Always on, parent controlled |
| 13 to 17 | 3 hours per day | Dating, adult | Always on, visible to teen with a clear indicator |

## 4. Product principles

1. **Transparent by design.** The child app is visible, shows active rules, and shows when location is shared. There is no stealth mode. AirDroid itself advises parents to talk openly with their child before installing; KidGuard builds that conversation into onboarding.
2. **Collect the minimum.** Store only what a feature needs (usage minutes, location points, device state). No message contents, no browsing content, no contacts, no photos.
3. **Rules a child can understand.** Every block screen explains which rule applied and offers a one-tap request to the parent.
4. **Parent in control, child informed.** Parents change rules; children see changes immediately and can ask for exceptions.
5. **Safe by default.** Conservative defaults, deletion on request, encryption in transit and at rest, and no advertising or data sale, ever.
6. **Honest about limits.** If a permission is revoked or the app is force-stopped, tell both sides plainly instead of failing silently.

## 5. MVP functional requirements

Priority key: P0 = must ship in v1, P1 = ship in v1 if time allows, P2 = defer.

### 5.1 Accounts and pairing
| ID | Requirement | Priority | Acceptance criteria |
| --- | --- | --- | --- |
| ACC-1 | Parent signs up with email or phone OTP, plus Google or Apple sign-in | P0 | Account created in under 60 seconds; email verified |
| ACC-2 | Parent adds a child profile (name, age band, avatar) | P0 | Up to 5 children per family on the paid plan |
| ACC-3 | Pair the child device by 6-digit code or QR | P0 | Pairing completes in under 2 minutes; code expires after 10 minutes |
| ACC-4 | Child app shows a plain-language consent screen | P0 | Lists exactly what is monitored; child or parent must tap Accept |
| ACC-5 | Second parent or guardian can be invited | P1 | Invite by link; both parents see the same rules |
| ACC-6 | Unpair and delete child data | P0 | Data deleted within 30 days; confirmation email sent |

### 5.2 Screen time and app control
| ID | Requirement | Priority | Acceptance criteria |
| --- | --- | --- | --- |
| SCR-1 | Daily total screen-time limit per child, with weekday and weekend values | P0 | Device locks to the KidGuard screen when the limit is hit, within 30 seconds |
| SCR-2 | Per-app time limits | P0 | Limit applies across the day; usage counted by foreground time |
| SCR-3 | Block or allow specific apps | P0 | Blocked app cannot be opened; block screen shown within 2 seconds |
| SCR-4 | Downtime schedule (for example 9 pm to 7 am, school hours) | P0 | Only allowed apps (phone, messages, parent-approved) work during downtime |
| SCR-5 | Always-allowed list (phone, maps, emergency) | P0 | Emergency calling is never blocked |
| SCR-6 | Request-more-time flow | P0 | Child taps request; parent gets a push; approve or deny in one tap; result under 10 seconds |
| SCR-7 | Instant pause or lock from parent app | P0 | Lock takes effect in under 10 seconds on a connected device |
| SCR-8 | Category block (social, games, adult, video) | P1 | Based on Play Store category metadata plus a manual override |
| SCR-9 | Reward time (parent grants bonus minutes) | P1 | Bonus applies to the current day only |

### 5.3 Location
| ID | Requirement | Priority | Acceptance criteria |
| --- | --- | --- | --- |
| LOC-1 | Live location on a map with last-updated time | P0 | Refresh on demand returns a fix within 60 seconds when the device is online |
| LOC-2 | 30-day route history | P0 | Timeline with stops and trips; older data auto-deleted |
| LOC-3 | Geofences (home, school, custom) with enter and exit alerts | P0 | Up to 10 per family; alert within 2 minutes of crossing |
| LOC-4 | Low-battery and device-offline alerts | P0 | Parent notified at 15% battery and when offline for more than 30 minutes |
| LOC-5 | SOS button on the child app | P1 | One tap sends location and an alert to all guardians |
| LOC-6 | Arrived-home and left-school auto messages | P1 | Built on geofence events |

### 5.4 Reports and alerts
| ID | Requirement | Priority | Acceptance criteria |
| --- | --- | --- | --- |
| RPT-1 | Daily and weekly screen-time report by app and category | P0 | Data matches device usage within 5% |
| RPT-2 | Push alerts: limit reached, new app installed, permission revoked, uninstall attempt | P0 | Delivered within 1 minute |
| RPT-3 | Weekly email digest | P1 | Sent Sunday evening, local time |
| RPT-4 | App install approval (child asks before installing) | P2 | Deferred to v1.1 |

### 5.5 Child app
| ID | Requirement | Priority | Acceptance criteria |
| --- | --- | --- | --- |
| KID-1 | Home screen shows time left today, active rules, and what is shared | P0 | Updates in real time |
| KID-2 | Persistent notification while monitoring is active | P0 | Required by Android for foreground services; cannot be hidden by the app |
| KID-3 | Tamper protection: alert parent if permissions are revoked or the app is uninstalled | P0 | Device Admin or equivalent; parent alerted within 1 minute of next connection |
| KID-4 | Works offline for already-synced rules | P0 | Limits enforced locally; usage syncs when back online |

### 5.6 Billing
| ID | Requirement | Priority | Acceptance criteria |
| --- | --- | --- | --- |
| BIL-1 | 3-day free trial with no card required | P0 | Full features during trial |
| BIL-2 | Monthly and yearly subscription through Google Play Billing | P0 | Entitlement syncs to the family account within 1 minute |
| BIL-3 | Restore purchases and grace period for failed payments | P0 | 7-day grace before downgrade |
| BIL-4 | Free tier after trial (1 child, basic location only) | P1 | Decide after pricing tests |

## 6. Post-MVP roadmap

| Release | Target window | Scope | Gate to start |
| --- | --- | --- | --- |
| v1.0 | Month 6 after kickoff | Everything marked P0 in section 5 | Beta with 50 families, crash-free sessions at least 99% |
| v1.1 | Months 7 to 9 | Website filtering by blocklist and safe search, app install approval (RPT-4), category rules, weekly digest, reward time | 500 paying families |
| v1.2 | Months 10 to 12 | SOS, arrived-home messages, co-parent chat notes, more languages (Tamil, Bengali, Marathi) | Play rating 4.3 or higher |
| v2.0 | Year 2 | Child iOS app on Apple Screen Time APIs, school-hours mode with school calendar, family-plus tier | 5,000 paying families |
| v2.x (evaluate) | Year 2 and later | Live screen view with a visible child-side indicator and a child-approved request. Remote camera and microphone are not planned | Legal review, Play policy review, and child-trust research all pass |

## 7. Key user flows

**Pairing (target under 5 minutes to the first rule):** parent signs up and adds child, then shows code or QR; child reads consent; child grants permissions; parent sets first rule.

**Request more time (parent decides in one tap):** limit reached; child taps Ask for time; parent gets push alert; parent approves (time added, app unlocks) or denies (stays blocked, child is told). Target: decision reaches the child in under 10 seconds.

| Flow | Trigger | What happens | Requirements |
| --- | --- | --- | --- |
| Geofence alert | Child crosses a saved place boundary | Device detects entry or exit and uploads it; backend pushes an alert to every guardian | LOC-3 |
| Downtime start | Schedule reaches downtime | Local rule engine blocks non-allowed apps; the child sees a block screen with the end time | SCR-4, SCR-5 |
| Tamper alert | Child revokes a permission or removes the app | Parent is alerted within 1 minute of the next connection | KID-3, RPT-2 |
| Trial to paid | Trial ends | Parent sees the paywall, buys through the store, entitlement syncs to the family | BIL-1 to BIL-3 |
| Unpair and delete | Parent removes a child | Device token revoked; data deletion queued within 30 days | ACC-6 |

## 8. System architecture and tech stack

The parent and child apps talk only through the backend, which stores rules, relays alerts, and checks purchases. The child app keeps a local copy of its rules so limits still work offline. Diagram: Parent app (Flutter) <-> Backend (Supabase) <-> Child app (Android, Kotlin); the backend connects to Firebase FCM (push), Play and App Store billing, and Google Maps SDK.

| Layer | Choice | Why |
| --- | --- | --- |
| Child app | Kotlin, Room, WorkManager, Play Services Location | Needs native Android APIs for Usage Access, overlay, and Device Admin |
| Parent app | Flutter (Android and iOS) | One codebase for both parent platforms |
| Backend | Supabase: Postgres, Auth, Realtime, Edge Functions | Row-level security per family and quick to build |
| Push | Firebase Cloud Messaging | Wake the child app on rule changes; deliver parent alerts |
| Billing | Google Play Billing and App Store, RevenueCat optional | Entitlement sync and trial handling |
| Maps | Google Maps SDK | Route history and geofence editing |
| Observability | Crash reporting and backend logs with no child identifiers | Supports the privacy principles in section 4 |

**Key design decisions**
1. Enforce rules on the device, not the server, so limits hold with no network.
2. Use server time for daily limits so changing the phone clock does not help.
3. Batch location points and adapt frequency to movement to protect battery and cost.
4. Children have no login of their own; the child device holds a device token tied to one child profile.

## 9. Data model and Android permissions

The backend is relational (Postgres). Every row carries a family ID so row-level security can isolate families from each other.

| Entity | Key fields | Notes |
| --- | --- | --- |
| family | id, name, plan, trial_ends_at | One subscription per family |
| guardian | id, family_id, auth_uid, role (owner, co-parent), push_token | Parent accounts |
| child | id, family_id, name, age_band, avatar | No email or phone for the child |
| device | id, child_id, platform, model, os_version, app_version, last_seen_at, battery | One child can have several devices |
| pairing_code | code, child_id, expires_at, used_at | 6 digits, 10-minute life |
| rule | id, child_id, type (daily_limit, app_limit, downtime, block), params JSON, active | Versioned; device pulls the latest |
| app_usage | device_id, package, day, foreground_seconds | Aggregated per day, not per tap |
| location_point | device_id, lat, lng, accuracy_m, recorded_at | Auto-deleted after 30 days |
| geofence | id, family_id, name, lat, lng, radius_m | Up to 10 per family |
| alert | id, family_id, child_id, type, payload, created_at, read_at | Drives push and in-app inbox |
| time_request | id, child_id, app, minutes, status, decided_by | Request-more-time flow |
| subscription | family_id, store, product_id, status, expires_at | Synced from Google Play and App Store |
| audit_log | actor, action, target, at | Who changed which rule, visible to both parents |

### Android permissions on the child device

| Permission or API | Used for | Sensitivity |
| --- | --- | --- |
| Usage Access (PACKAGE_USAGE_STATS) | Foreground app time and per-app limits | Special access, user grants in Settings |
| Display over other apps (SYSTEM_ALERT_WINDOW) | Block screen when a limit is reached | Special access |
| Accessibility Service | Detect the foreground app fast and block it; only if Usage Access is too slow | Highest scrutiny; needs Play declaration and prominent disclosure |
| Fine and background location | Live location, history, geofences | Prominent in-app disclosure required |
| Foreground service (location, special use) | Keep tracking alive with a visible notification | Required by Android |
| Device Admin or Device Policy APIs | Uninstall protection and lock screen | User must activate; clearly explained |
| Post notifications | Show rule changes and reminders | Runtime permission on Android 13+ |
| Battery optimization exemption | Keep the service running on aggressive OEM skins | Optional; guided setup per brand |

Design choice: start with Usage Access plus overlay for blocking, and add the Accessibility Service only if testing shows blocking is too slow.

## 10. Privacy, child safety and compliance

Compliance is a launch gate, not a later task. This section is a product checklist, not legal advice; have a lawyer review it before launch.

### 10.1 Google Play requirements
| Area | What Google requires | Our response |
| --- | --- | --- |
| Parental control and Accessibility | Parental control apps may temporarily declare themselves accessibility tools, but must still meet prominent disclosure and consent rules and complete the Play Console declaration | Avoid the Accessibility Service in v1; if added later, complete the declaration and disclosure |
| Prominent disclosure | Disclosure must be in the app, not only in the privacy policy or terms | Full-screen consent in the child app before any permission request |
| Families Policy | Applies when children are a target audience: no sensitive child data such as device IDs for ads, no unapproved SDKs, a message about the importance of parental supervision | No ad SDKs; only Families-approved SDKs; add the parental-supervision message |
| Android 17 target | Play Console lists 28 October 2026 as the date policy compliance becomes mandatory for apps targeting Android 17 or later (API 37+) | Target the latest API at launch and re-check the policy page before submission |

### 10.2 Privacy laws to plan for
- **India (primary market):** the Digital Personal Data Protection Act, 2023 requires verifiable consent from a parent or guardian before processing a child's personal data. Confirm current rules and deadlines with counsel.
- **United States:** COPPA covers children under 13: parental consent, notice, and data minimization.
- **European Union and United Kingdom:** GDPR child-consent rules and the UK Age Appropriate Design Code, if you launch there.

### 10.3 Controls we build in
1. Verified parent account before any child profile exists; the parent gives consent in-app and the consent record is stored with a timestamp.
2. Data minimization: no message, photo, contact, or browsing content is collected in v1.
3. Retention: location history 30 days; usage data 12 months; all deleted within 30 days of account deletion.
4. Encryption in transit (TLS 1.2+) and at rest; secrets in a managed vault; no child data in logs.
5. Row-level security per family; parents see only their own family.
6. No advertising, no data sale, no third-party analytics that receive child identifiers.
7. A child-facing privacy notice in plain language, plus an in-app Data and privacy page for parents (export and delete).
8. Abuse safeguards: the app is for guardians of minors only. Terms prohibit use to monitor another adult, and the paired device must show the persistent child-visible notification.

### 10.4 Launch compliance checklist
- [ ] Privacy policy and terms published and linked in the store listing
- [ ] Play Console Data Safety form completed to match real data flows
- [ ] Permission declarations (location, usage access, overlay, foreground service) submitted with demo video
- [ ] Families Policy self-review done
- [ ] Parental consent flow reviewed by counsel
- [ ] Security review and a basic penetration test passed
- [ ] Data deletion and export tested end to end

## 11. Monetization and pricing

KidGuard earns from one family subscription with a 3-day free trial, priced below AirDroid and sold without ads. Every price below is a starting hypothesis to test, not a fact.

**Reference points:** AirDroid's own comparison pages list $9.99 per month, $59.99 per year, and about $4.99 per month billed yearly, with a 3-day full-feature trial.

| Plan | Global (USD) | India (INR) | Includes |
| --- | --- | --- | --- |
| Free after trial | $0 | Rs 0 | 1 child, live location only, no limits |
| Monthly | $6.99 | Rs 199 | All v1 features, up to 5 children |
| Yearly | $39.99 (about $3.33 per month) | Rs 1,499 (about Rs 125 per month) | Same as monthly, best value |

**Rules**
- Trial starts at pairing, not at install, so the family sees value first.
- Day 2 of the trial: reminder push with what they have set up so far.
- Paywall appears at trial end; free tier stays usable so the child is never left unprotected by a billing lapse.
- Regional pricing through Google Play price templates; test two India price points in the first 8 weeks.
- No ads, no data sale. Revenue only from subscriptions (and, later, a family-plus tier).

| Assumption | Value |
| --- | --- |
| Store fee on subscriptions | 15% (Google Play reduced rate; verify eligibility) |
| Backend cost per active family | Under $0.30 per month (target) |
| Target trial-to-paid conversion | 8% |
| Target 12-month retention of paying families | 55% |

## 12. UX and design requirements

The parent app is calm and fast: three taps from the home screen to any rule. The child app is friendly and clear, never alarming.

**Design rules**
- Parent home shows, per child: current location, time used versus limit, and any pending request.
- Plain language only: "Games are paused until 4 pm", not "Policy enforced".
- Child block screen always shows the reason, the time it ends, and an Ask for more time button.
- Accessible: minimum 4.5:1 text contrast, text scales to 200%, 48 dp touch targets, TalkBack labels.
- Languages at launch: English and Hindi; the string system supports adding Tamil, Bengali, and others.
- Light and dark themes; low-data mode for slow networks.

### Screen inventory (v1)
| App | Screen | Purpose |
| --- | --- | --- |
| Parent | Welcome and sign-in | Account creation |
| Parent | Add child and age band | Starts the child profile |
| Parent | Pair device (code and QR) | Links the child phone |
| Parent | Home dashboard | Per-child snapshot and alerts |
| Parent | Screen time | Daily limit, per-app limits, downtime |
| Parent | Apps | Block, allow, category rules |
| Parent | Location map | Live location, history timeline |
| Parent | Geofences | Create and edit places |
| Parent | Requests inbox | Approve or deny more time |
| Parent | Reports | Daily and weekly usage |
| Parent | Alerts | Notification history |
| Parent | Family and billing | Co-parent invite, plan, trial |
| Parent | Settings and privacy | Export, delete, notifications |
| Child | Welcome and consent | Plain-language disclosure and accept |
| Child | Permission wizard | Usage access, overlay, location, battery, admin |
| Child | Home | Time left, rules, what is shared |
| Child | Block screen | Reason, end time, request more time |
| Child | SOS | One-tap alert to guardians (P1) |
| Child | About | What the parent can and cannot see |

**Design deliverables:** a design system (colors, type, spacing, components), low-fidelity flows for pairing and blocking first, then high-fidelity mockups of the core parent and child screens. Place source files in `design/`.

## 13. Non-functional requirements

| Area | Requirement | Target |
| --- | --- | --- |
| Battery | Child app background drain | Under 4% of battery per day with location on; adaptive location frequency (every 5 minutes moving, every 30 minutes still) |
| Enforcement latency | Time from limit reached to block screen | Under 30 seconds (limits), under 2 seconds (blocked app open) |
| Sync latency | Parent change reaches the child device | Under 10 seconds online, via push plus realtime channel |
| Reliability | Backend availability | 99.9% monthly |
| Offline | Rules already synced keep working with no network | 100% of local rules enforced |
| Device coverage | Android versions | Android 10 to latest; test on Samsung, Xiaomi, Oppo, Vivo, Realme, OnePlus, Pixel |
| OEM battery killers | Service survives aggressive task killers | Guided per-brand setup; alert parent if the child app stops reporting for 30+ minutes |
| Performance | Cold start | Parent app under 2.5 seconds; child app under 2 seconds on a mid-range device |
| Size | App size | Under 30 MB download for each app |
| Security | Auth and data | OAuth or OTP login, short-lived tokens, TLS, encrypted storage, certificate pinning on the child app |
| Tamper resistance | Detect uninstall, permission removal, date and time change | Alert the parent; do not rely on local clock for limits |
| Scalability | First year | 50,000 families; location writes batched to keep cost low |
| Accessibility | Both apps | WCAG 2.1 AA for text and contrast; screen reader support |
| Localization | Strings and formats | English and Hindi at launch; RTL-ready layout |

**Observability:** crash reporting and performance traces on both apps without child identifiers; a backend dashboard for sync latency, push delivery, and enforcement failures; an on-call alert when enforcement failure rate passes 1%.

## 14. Analytics and success metrics

The north star is **weekly active protected children**: children whose device reported usage in the last 7 days under at least one active rule. Analytics use parent-side events only and never carry child identifiers.

| Stage | Metric | Launch target |
| --- | --- | --- |
| Acquire | Install to parent sign-up | 60% |
| Activate | Sign-up to paired child device | 50% |
| Activate | Time from sign-up to first rule | Under 5 minutes (median) |
| Engage | Parents opening the app 3+ times per week | 45% |
| Engage | Time-request decisions made within 5 minutes | 70% |
| Convert | Trial to paid | 8% |
| Retain | Paying families still active after 90 days | 70% |
| Quality | Play Store rating | 4.3 or higher |
| Quality | Crash-free sessions | 99.5% |
| Trust | Child-app uninstall within 7 days of pairing | Under 15% |
| Support | Tickets per 100 paying families per month | Under 8 |

**Events to instrument (parent app):** sign_up, child_added, pairing_started, pairing_completed, first_rule_set, limit_changed, request_decided, geofence_created, trial_started, subscription_started, subscription_cancelled.

**Experiments planned:** two India price points, trial start at pairing versus at sign-up, and default screen-time caps by age band.

## 15. Release plan, milestones and team

Public v1.0 is targeted six months after kickoff (month numbers count from a kickoff date still to be set).

| Phase | Months | Focus | Gate to exit |
| --- | --- | --- | --- |
| Design and setup | 1 to 2 | Flows, design system, schema, Play account | Gate 1: design and consent flows approved |
| Build the core | 2 to 4 | Pairing, rules, location, billing | Gate 2: all P0 features built and tested |
| Beta and hardening | 4 to 5 | OEM device tests, pen test, fixes | Gate 3: 50-family beta at 99% crash-free sessions |
| Launch v1.0 | 6 | Play review, staged rollout | Public release |

No phase starts until the gate before it is met.

| Role | FTE | Owns |
| --- | --- | --- |
| Product owner (founder) | 1 | Scope, store listing, support, partnerships |
| Android engineer | 1 | Child app: enforcement, location, OEM compatibility |
| Mobile engineer | 1 | Parent app in Flutter, billing UI |
| Backend engineer | 0.5 to 1 | Supabase schema, security, push, billing webhooks |
| Designer | 0.5 | Design system, flows, store assets |
| QA | 0.5 | Device matrix, regression, beta feedback |
| Legal and privacy counsel | As needed | Consent flow, privacy policy, DPDP and COPPA review |

**Launch plan**
1. Closed beta with 50 families recruited through school parent groups.
2. Play Store staged rollout: 5%, 20%, 50%, then 100%, pausing if crash-free sessions drop below 99%.
3. Help center with a per-brand battery setup guide, plus email and chat support.
4. Launch week offer: extended 7-day trial for the first 1,000 sign-ups (to test against the 3-day default).

## 16. Risks and open questions

| # | Risk | Likelihood | Impact | Mitigation |
| --- | --- | --- | --- | --- |
| R1 | Play review rejects the app over Accessibility, location, or overlay permissions | Medium | High | No stealth; prominent disclosure; declarations with demo video; start with Usage Access plus overlay; budget two review rounds |
| R2 | OEM battery managers kill the child service | High | High | Per-brand guided setup; offline enforcement; stale-device alerts; test matrix on the top 7 brands |
| R3 | Teens bypass limits (safe mode, factory reset, date change, second profile) | High | Medium | Server time for limits; Device Admin; alert on tamper; tell parents the limits of the tool honestly |
| R4 | Privacy incident involving children's location data | Low | Severe | Row-level security, minimal data, short retention, pen test before launch, incident response plan |
| R5 | Misuse for stalking an adult partner | Low | Severe | Guardian-of-minor terms; persistent child-visible notification; no stealth; report and takedown process |
| R6 | Large competitors (AirDroid, Google Family Link, Life360) out-market a new entrant | High | Medium | Differentiate on transparency, child request flow, and price in India; one language at a time |
| R7 | Low trial-to-paid conversion | Medium | High | Value moments in the first 48 hours; test pricing early; keep a useful free tier |
| R8 | Policy or law changes (Android 17 policy date, India DPDP rules) | Medium | Medium | Quarterly compliance review; counsel on retainer |
| R9 | Small team cannot cover Android, iOS, and backend | Medium | High | Use cross-platform parent app and Supabase to cut scope; contract design and QA |

**Open questions for the founder**
- [ ] Is the primary audience India-first, or global from day one?
- [ ] Will the child ever use an iPhone? If yes, plan an iOS child app on Apple's Screen Time APIs (a separate project).
- [ ] Is a free tier required for growth, or is trial then paywall acceptable?
- [ ] Final product name and domain; trademark check.
- [ ] Team size and budget for the first 6 months.
- [ ] Is a school or institutional (B2B2C) channel part of the plan?

## 17. Appendix

Competitor snapshot, glossary and sources are in `research/` (see `01-competitor-analysis.md` and `04-sources.md`).

Glossary: **Child app** (runs on the child's Android phone), **Parent app** (guardians set rules and see reports), **Geofence** (circular map area that triggers entry and exit alerts), **Downtime** (scheduled period when only allowed apps work), **Usage Access** (Android permission to read per-app foreground time), **Overlay** (permission to draw over other apps), **Device Admin** (Android feature that can lock the screen and resist uninstall once activated), **Prominent disclosure** (Play requirement for clear in-app explanation and consent), **DPDP** (India's Digital Personal Data Protection Act, 2023).

Research as of 21 October 2026. Pricing and policy details can change; re-check before launch.
