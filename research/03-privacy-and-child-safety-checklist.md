# Privacy and child-safety checklist

Not legal advice. Have a privacy lawyer review the consent flow and policies before launch.

## Laws to plan for
- India (primary market): Digital Personal Data Protection Act, 2023. Verifiable parental or guardian
  consent before processing a child's personal data. Confirm current rules and deadlines with counsel.
- United States: COPPA for children under 13 (parental consent, notice, data minimization).
- EU and UK, if launched there: GDPR child-consent rules and the UK Age Appropriate Design Code.

## Controls built into the product
1. Verified parent account before any child profile exists; consent stored with a timestamp.
2. No message, photo, contact or browsing content collected in v1.
3. Retention: location 30 days, usage 12 months, everything deleted within 30 days of account deletion.
4. TLS 1.2+ in transit, encryption at rest, secrets in a vault, no child data in logs.
5. Row-level security per family.
6. No ads, no data sale, no analytics SDKs that receive child identifiers.
7. Plain-language child notice; in-app export and delete for parents.
8. Abuse safeguards: guardian-of-minors only terms, persistent child-visible notification, no stealth,
   report and takedown process.

## Misuse risks to monitor
- Use to track another adult (stalkerware). Mitigation: no hidden mode, visible notification,
  terms, takedown process, abuse reporting.
- Teens bypassing limits. Mitigation: server time, Device Admin, tamper alerts, honest messaging.

## Pre-launch tasks
- [ ] Privacy policy and terms drafted and reviewed
- [ ] Parental consent flow reviewed
- [ ] Data Safety form complete
- [ ] Security review and penetration test
- [ ] Data export and deletion tested end to end
- [ ] Incident response plan written
