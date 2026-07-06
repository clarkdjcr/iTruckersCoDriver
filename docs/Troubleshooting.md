# Troubleshooting

This guide covers common issues during Phase 1 and Phase 2 of the Firebase-first rollout.

## Firebase CLI Cannot Find Project

Confirm that the correct project is selected:

```bash
firebase projects:list
firebase use <project-id>
```

Use separate Firebase projects for development, staging, and production.

---

## Emulator UI Does Not Start

Run:

```bash
firebase emulators:start
```

Then open:

```text
http://localhost:4000
```

Confirm ports 4000, 8080, 9099, and 9199 are available.

---

## Firestore Access Denied

Check:

- User is authenticated.
- User has a tenant membership record.
- Membership record uses the correct Firebase Auth UID.
- Role is one of the approved role strings.
- Data path is under the correct tenant.

Expected membership path:

```text
tenants/{tenantId}/members/{uid}
```

---

## Storage Upload Denied

Check:

- User is authenticated.
- User belongs to the tenant.
- Upload path starts with `tenants/{tenantId}/`.
- File is under the configured size limit.
- Storage rules are deployed.

---

## App Check Blocks Legitimate Clients

During Phase 2, keep App Check in monitoring mode.

Do not enforce until legitimate test clients are consistently accepted.

---

## AI Calls Should Not Run Yet

Phase 1 and Phase 2 do not approve unrestricted production AI calls.

If AI calls are failing during this phase, confirm whether they are intentionally enabled for a limited local or staging test.

---

## Billing Concerns

Before any pilot:

- Confirm budget alerts.
- Review Firebase usage dashboard.
- Review AI provider usage dashboard.
- Keep Cloud Functions usage minimal.
- Use emulator testing when possible.

---

## Rules Deployment Fails

Check syntax using Firebase CLI:

```bash
firebase deploy --only firestore:rules
firebase deploy --only storage
```

If deployment fails, validate parentheses, function names, and path variables.

---

## Unknown Tenant Access Behavior

If unsure whether a user should access a record, deny access first and add a specific rule only after the access need is approved.
