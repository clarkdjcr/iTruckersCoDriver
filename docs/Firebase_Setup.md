# Firebase Setup

This guide explains how to configure Firebase as the primary production backend for iTruckers Co-Driver.

## Audience

- Owner-operators deploying their own app backend
- Fleet administrators managing company-wide deployments
- Developers preparing production releases

---

## 1. Create the Firebase Project

1. Open the Firebase Console.
2. Select **Add project**.
3. Name the project using a clear production name, such as:

   ```text
   itruckers-production
   ```

4. Enable Google Analytics if the deployment requires analytics or event reporting.
5. Create the project.

Recommended project separation:

```text
itruckers-dev
itruckers-staging
itruckers-production
```

Do not mix development and production data in the same Firebase project.

---

## 2. Enable Billing

Most production Firebase deployments require the Blaze plan.

Enable billing before configuring:

- Cloud Functions
- Firebase Storage
- Higher Firestore limits
- App Check enforcement
- Scheduled jobs
- Production-scale usage

After enabling billing, configure Google Cloud budget alerts.

Recommended alerts:

- 50% of expected monthly spend
- 75% of expected monthly spend
- 90% of expected monthly spend
- 100% of expected monthly spend

---

## 3. Register Apple Apps

Register each Apple client separately.

Recommended app registrations:

```text
iOS Driver App
iPad Driver App
macOS Dispatcher App
```

For each app:

1. Open **Project Settings**.
2. Select **Add app**.
3. Choose Apple.
4. Enter the bundle identifier.
5. Download `GoogleService-Info.plist`.
6. Add it to the appropriate Xcode target.

Use different Firebase projects or configuration files for development, staging, and production.

---

## 4. Configure Firebase Authentication

Enable the sign-in methods required for the deployment.

Recommended options:

- Email/password
- Sign in with Apple
- Google sign-in, if appropriate
- SSO/SAML/OIDC for enterprise fleets, if required

Owner-operator deployments may only need email/password and Apple sign-in.

Fleet deployments should use centrally managed identity where possible.

---

## 5. Configure Firestore

Use Firestore as the primary shared database.

Recommended top-level structure:

```text
tenants/{tenantId}
tenants/{tenantId}/drivers/{driverId}
tenants/{tenantId}/vehicles/{vehicleId}
tenants/{tenantId}/dispatchMessages/{messageId}
tenants/{tenantId}/trips/{tripId}
tenants/{tenantId}/maintenanceReports/{reportId}
tenants/{tenantId}/documents/{documentId}
tenants/{tenantId}/settings/{settingId}
```

Even an owner-operator should use a tenant record.

Example:

```text
tenant = Donald Trucking LLC
driver = owner operator
vehicle = primary truck
```

This keeps the data model compatible with both one-driver and multi-fleet deployments.

---

## 6. Configure Firestore Security Rules

Never leave Firestore in test mode.

Production rules must enforce:

- Signed-in users only
- Tenant boundaries
- Driver-specific access
- Fleet administrator privileges
- Dispatcher privileges
- Read/write validation

See [Security Guide](Security_Guide.md) for production guidance.

---

## 7. Configure Firebase Storage

Use Firebase Storage for files such as:

- Uploaded documents
- Bills of lading
- Compliance documents
- Maintenance photos
- Receipts
- Generated reports

Recommended path format:

```text
tenants/{tenantId}/drivers/{driverId}/documents/{fileName}
tenants/{tenantId}/vehicles/{vehicleId}/maintenance/{fileName}
```

Storage rules must prevent one tenant from accessing another tenant's files.

---

## 8. Configure Cloud Functions

Use Cloud Functions for server-side operations that should not run in the client app.

Recommended backend responsibilities:

- AI provider calls
- Secret handling
- Usage metering
- Fleet-level automation
- Notification fan-out
- Scheduled maintenance reminders
- Report generation
- Administrative actions

Private AI provider keys should live in Firebase Functions secrets or Google Cloud Secret Manager, not in the client app.

---

## 9. Configure Firebase Cloud Messaging

Use FCM for notifications such as:

- New dispatch message
- Driver status update
- Maintenance alert
- HOS warning
- Fleet administrator notification
- Document request

Apple push notifications still require Apple Developer configuration, APNs keys, and the correct Xcode capabilities.

---

## 10. Configure App Check

Firebase App Check helps reduce abuse by verifying that requests are coming from legitimate app instances.

Recommended rollout:

1. Configure App Check providers.
2. Run in monitoring mode.
3. Confirm legitimate traffic is accepted.
4. Fix rejected legitimate clients.
5. Enforce App Check for Firestore, Storage, and Functions.

Do not enforce App Check until testing confirms production clients are passing checks.

---

## 11. Environment Separation

Do not use production Firebase credentials for local development.

Recommended environments:

| Environment | Purpose |
|---|---|
| Development | Local development and experiments |
| Staging | TestFlight and pre-release validation |
| Production | Customer and fleet usage |

---

## 12. Handoff Checklist

Before handing a deployment to a customer or fleet, confirm:

- Firebase project created
- Billing enabled
- Budget alerts configured
- Apple apps registered
- Authentication enabled
- Firestore database created
- Firestore rules deployed
- Storage bucket created
- Storage rules deployed
- Cloud Functions configured
- AI secrets stored backend-side
- FCM configured
- App Check tested
- Production app tested end-to-end
