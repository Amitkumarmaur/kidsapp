# KidGuard (working title): Kids Safety and Screen-Time App

A transparent parental control app: a parent app plus an Android child app for screen-time limits,
app blocking, live location, geofences and alerts. Benchmark product: AirDroid Parental Control.

Status: PRD drafted (v0.1), research done, no code yet. Last updated 21 October 2026.

## Folder map
| Folder | Contents |
| --- | --- |
| `docs/` | `PRD.md`: the full product requirements document |
| `research/` | Competitor analysis, Google Play policy notes, privacy law checklist, sources |
| `design/` | Put design system, flows and mockups here |
| `backend/` | Supabase schema and edge functions (to build) |
| `child-app/` | Android child app in Kotlin (to build) |
| `parent-app/` | Flutter parent app (to build) |

## Master copy
The editable master PRD (with diagrams) is the online doc "PRD: Kids Safety & Screen-Time App".
`docs/PRD.md` is a text snapshot of it; the three diagrams are described in words there.

## Next steps
1. Answer the open questions at the end of the PRD (India-first or global, free tier, name, budget).
2. Run a trademark and Play Store name check for the final product name.
3. Design the pairing and block-screen flows, then the core screens (`design/`).
4. Scaffold the Supabase schema (`backend/`) from section 9 of the PRD.
5. Build a child-app spike for Usage Access, overlay blocking and location on 3 to 4 phone brands.
