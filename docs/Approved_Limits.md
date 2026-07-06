# Approved Limits

This document defines the limits for the current Firebase-first rollout.

## Current Approved Scope

Only Phase 1 and Phase 2 work is approved.

### Phase 1

Documentation and planning only.

Approved:

- Repository documentation
- Firebase architecture planning
- Owner-operator and fleet deployment model documentation
- Security planning
- Production checklist creation

Not approved:

- Public production launch
- Production AI automation changes
- Android implementation
- Large code refactors
- Fleet-wide rollout

### Phase 2

Firebase foundation only.

Approved:

- Firebase emulator configuration
- Baseline Firestore rules
- Baseline Storage rules
- Firebase setup documentation
- Security documentation
- Local testing guidance
- Budget alert guidance

Not approved:

- Unrestricted Cloud Functions usage
- Production AI calls from backend functions
- Enforcing App Check before monitoring validation
- Production customer migration
- Fleet-wide production deployment

---

## Budget Guardrails

Before production use:

- Configure Firebase budget alerts.
- Configure AI provider spend limits where available.
- Review billing weekly during any pilot.
- Use dev, staging, and production Firebase projects.
- Keep Cloud Functions disabled or minimal until explicitly approved.

---

## AI Usage Guardrails

During Phase 1 and Phase 2:

- Do not add unlimited AI calls from Firebase Functions.
- Do not store AI provider secrets in client code.
- Do not enable fleet-wide AI usage without tenant-level caps.
- Do not require a single vendor; keep provider selection flexible.

---

## Security Guardrails

- Firestore must deny all unmatched reads and writes.
- Storage must deny all unmatched reads and writes.
- Tenant membership must be required for shared records.
- Admin actions must be restricted to owner/admin roles.
- App Check must start in monitoring mode before enforcement.

---

## Next Required Approval

The next approval should be for a limited **Owner-Operator Pilot**.

Recommended pilot limits:

- 1 Firebase staging project
- 1 tenant
- 1 driver
- 1 vehicle
- 1 AI provider
- Strict AI usage cap
- Weekly billing review
