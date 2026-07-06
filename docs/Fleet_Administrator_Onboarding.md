# Fleet Administrator Onboarding

This guide is for trucking companies, dispatch teams, and fleet administrators preparing iTruckers Co-Driver for managed fleet use.

## Phase 1 and Phase 2 Scope

This guide supports planning and Firebase foundation only.

Fleet-wide production rollout is not included in Phase 1 or Phase 2.

---

## Fleet Responsibilities

A fleet administrator is responsible for:

- Firebase project ownership
- User and role management
- Driver onboarding
- Vehicle records
- Dispatcher access
- Usage monitoring
- Billing alerts
- AI provider selection
- Security review

---

## Recommended Roles

| Role | Purpose |
|---|---|
| owner | Full tenant control |
| admin | Fleet administration |
| dispatcher | Dispatch and driver operations |
| driver | Driver app access |
| maintenance | Maintenance workflows |
| viewer | Read-only reporting |

---

## Recommended Firebase Structure

```text
tenants/{tenantId}
tenants/{tenantId}/members/{userId}
tenants/{tenantId}/drivers/{driverId}
tenants/{tenantId}/vehicles/{vehicleId}
tenants/{tenantId}/dispatchMessages/{messageId}
tenants/{tenantId}/maintenanceReports/{reportId}
tenants/{tenantId}/trips/{tripId}
tenants/{tenantId}/documents/{documentId}
tenants/{tenantId}/settings/{settingId}
```

All fleet records should be tenant-scoped.

---

## Phase 2 Setup

1. Create a Firebase staging project.
2. Enable billing and budget alerts.
3. Enable Firebase Authentication.
4. Create initial owner/admin user.
5. Create fleet tenant document.
6. Add admin membership record.
7. Deploy Firestore rules.
8. Deploy Storage rules.
9. Configure App Check in monitoring mode.
10. Validate access using test users.

---

## Phase 2 Validation

Create these test accounts:

- Fleet owner
- Fleet admin
- Dispatcher
- Driver
- Unrelated user

Validate:

- Owner can manage tenant settings.
- Admin can manage fleet records.
- Dispatcher can read fleet records and update operational messages.
- Driver can access assigned driver data.
- Unrelated user cannot read or write tenant data.

---

## AI Provider Use

During Phase 2, keep AI provider work limited to planning.

Do not enable unrestricted fleet AI calls until:

- Tenant security is validated.
- Billing alerts are active.
- Provider usage caps are approved.
- Pilot scope is approved.

---

## Next Step

After Phase 2 validation, request approval for a limited fleet pilot.
