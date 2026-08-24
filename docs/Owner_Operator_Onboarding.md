# Owner-Operator Onboarding

This guide is for independent drivers or small trucking businesses deploying iTruckers Co-Driver for their own use.

## Phase 1 and Phase 2 Scope

This guide supports planning and Firebase foundation setup only. Do not proceed to production usage until Firebase rules, billing alerts, and pilot limits are approved.

---

## Required Accounts

The owner-operator should create or control:

- Apple ID or Apple Developer account, if distributing independently
- Firebase project
- Google Cloud billing account
- Preferred AI provider account

---

## Firebase Setup

1. Create a Firebase project.
2. Enable billing.
3. Configure budget alerts.
4. Register the Apple app.
5. Download the Firebase Apple configuration file.
6. Enable Firebase Authentication.
7. Create the Firestore database.
8. Deploy Firestore rules.
9. Configure Firebase Storage.
10. Deploy Storage rules.
11. Configure App Check in monitoring mode.

See [Firebase Setup](Firebase_Setup.md).

---

## Recommended Tenant Structure

Even for one driver, create a tenant.

```text
tenants/{tenantId}
tenants/{tenantId}/members/{userId}
tenants/{tenantId}/drivers/{driverId}
tenants/{tenantId}/vehicles/{vehicleId}
```

The owner-operator should have the `owner` role.

---

## AI Provider Setup

The owner-operator may choose a preferred AI provider.

During Phase 2:

- Create provider account.
- Configure usage limits.
- Do not enable unrestricted backend AI calls.
- Do not commit API keys.
- Keep AI usage capped during pilot.

See [AI Provider Setup](AI_Provider_Setup.md).

---

## Phase 2 Validation

Before moving to pilot:

- Confirm sign-in works.
- Confirm tenant membership exists.
- Confirm user cannot read another tenant.
- Confirm Storage paths are tenant-scoped.
- Confirm App Check monitoring is collecting data.
- Confirm Firebase budget alerts are active.
- Confirm no provider keys are exposed in source code.

---

## Next Step

After validation, request approval for a limited owner-operator pilot.
