# Phased Rollout Plan

This plan keeps iTruckers Co-Driver within approved limits while moving toward a Firebase-first production architecture.

## Scope of This Phase

This document covers only:

- Phase 1: Documentation and planning
- Phase 2: Firebase foundation

It intentionally does not include AI provider refactoring, fleet-scale rollout, production AI usage automation, Android implementation, or public launch activities.

---

## Phase 1: Documentation and Planning

### Goal

Create a safe, reviewable foundation before changing core application behavior or increasing cloud usage.

### Approved Activities

- Document Firebase-first architecture.
- Document owner-operator and fleet-managed deployment models.
- Define tenant-oriented data structure.
- Define minimum Firebase services required for production.
- Define AI provider setup guidance without enabling unrestricted production usage.
- Define budget and usage controls.
- Define security expectations.
- Define production readiness checklist.

### Not Approved in Phase 1

- No production AI automation changes.
- No app-wide AI abstraction refactor.
- No Android implementation.
- No unrestricted Cloud Functions deployment.
- No public production launch.
- No removal of existing Apple-specific implementation details unless separately approved.

### Exit Criteria

Phase 1 is complete when:

- Repository documentation exists for Firebase setup, security, onboarding, and production readiness.
- Owner-operator and fleet deployment models are documented.
- Approved limits are documented.
- The team has reviewed Firebase budget and access controls.

---

## Phase 2: Firebase Foundation

### Goal

Create a Firebase foundation that can support production deployment without enabling uncontrolled usage.

### Approved Activities

- Configure Firebase project structure.
- Enable Firebase Authentication.
- Define Firestore tenant structure.
- Add baseline Firestore security rules.
- Add baseline Firebase Storage rules.
- Add Firebase configuration guidance.
- Add App Check rollout guidance in monitoring mode first.
- Add budget alert guidance.
- Add emulator-based local testing guidance.

### Not Approved in Phase 2

- No broad production data migration.
- No unrestricted Cloud Functions AI calls.
- No fleet-wide customer rollout.
- No production App Check enforcement until monitoring is validated.
- No production billing increase without review.

### Exit Criteria

Phase 2 is complete when:

- Firebase Auth is configured for the selected deployment.
- Firestore rules deny unauthenticated access.
- Tenant boundary rules are defined.
- Storage rules deny unauthenticated and cross-tenant access.
- App Check is configured in monitoring mode.
- Budget alerts are configured.
- Owner-operator test account can sign in and access only its own tenant data.
- Fleet admin test account can access only its own fleet tenant data.

---

## Recommended Approval Gates

| Gate | Required Before Proceeding |
|---|---|
| Gate 1 | Documentation reviewed |
| Gate 2 | Firebase project and billing alerts created |
| Gate 3 | Auth and security rules tested in emulator |
| Gate 4 | App Check monitoring validated |
| Gate 5 | Owner-operator pilot approved |
| Gate 6 | Fleet pilot approved |

---

## Cost Control Rules

During Phase 1 and Phase 2:

- Keep Cloud Functions usage minimal.
- Do not run production AI calls from backend functions without budget approval.
- Use emulator testing when possible.
- Configure billing alerts before enabling paid usage.
- Use separate dev, staging, and production Firebase projects.
- Review Firebase and AI provider billing weekly during pilots.

---

## Recommended Next Phase

After Phase 1 and Phase 2 are complete, proceed to a limited owner-operator pilot with one tenant, one driver, one vehicle, one AI provider, and strict usage caps.
