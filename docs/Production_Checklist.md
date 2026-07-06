# Production Checklist

Use this checklist before moving beyond Phase 1 and Phase 2.

## Phase 1 Checklist

- [ ] Firebase-first architecture documented.
- [ ] Owner-operator mode documented.
- [ ] Fleet-managed mode documented.
- [ ] Approved limits documented.
- [ ] AI provider strategy documented.
- [ ] Security guide created.
- [ ] Production checklist created.

## Phase 2 Firebase Foundation Checklist

- [ ] Firebase project created.
- [ ] Separate dev, staging, and production projects planned.
- [ ] Billing enabled only where required.
- [ ] Budget alerts configured.
- [ ] Firebase Authentication enabled.
- [ ] Firestore database created.
- [ ] Firestore rules deployed.
- [ ] Firebase Storage configured.
- [ ] Storage rules deployed.
- [ ] App Check configured in monitoring mode.
- [ ] Firebase emulator configuration added.
- [ ] Firestore indexes file added.

## Access Control Checklist

- [ ] Unauthenticated users denied.
- [ ] Unrelated authenticated users denied.
- [ ] Tenant members can access only their tenant.
- [ ] Owner/admin role can manage tenant records.
- [ ] Driver role cannot perform admin-only actions.
- [ ] Dispatcher role cannot delete protected records.
- [ ] Storage access is tenant-scoped.

## AI Safety Checklist

- [ ] AI provider choices documented.
- [ ] Provider keys are not committed to GitHub.
- [ ] Provider keys are not stored in client-readable Firestore documents.
- [ ] Backend secret storage plan is documented.
- [ ] Usage caps are defined before pilot.
- [ ] No unrestricted production AI calls are enabled in Phase 2.

## Pilot Readiness Checklist

Before an owner-operator or fleet pilot:

- [ ] Test tenant created.
- [ ] Test users created.
- [ ] Rule testing completed.
- [ ] App Check monitoring reviewed.
- [ ] Budget alerts tested.
- [ ] Support and rollback plan documented.
- [ ] Pilot scope approved.

## Do Not Launch Until

- [ ] Security rules pass testing.
- [ ] Storage rules pass testing.
- [ ] App Check is validated.
- [ ] Billing alerts are active.
- [ ] AI usage caps are approved.
- [ ] Customer onboarding flow is tested end-to-end.
- [ ] Fleet onboarding flow is tested end-to-end.
