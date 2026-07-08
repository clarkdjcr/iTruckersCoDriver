# Mudflap vs. iTrucker's Co-Driver

Last updated: 2026-06-26

## Executive Summary

Mudflap is primarily a diesel savings and fuel payment product. Its public positioning centers on discounted diesel, a fuel card, truck-safe fuel navigation, fleet spend controls, fraud prevention, and fuel-stop network access.

iTrucker's Co-Driver is positioned as an operating and revenue-protection companion. It helps drivers and dispatchers decide whether a load is worth taking, protect accessorial revenue, manage HOS-aware execution, track documents and settlement readiness, monitor maintenance and health risks, and coordinate dispatch communications.

In short:

- **Mudflap helps reduce fuel purchase cost.**
- **iTrucker's Co-Driver helps protect profit across the full load lifecycle.**

## Source Basis

Mudflap public feature set was reviewed from Mudflap's website on 2026-06-26:

- Mudflap app: instant diesel discounts using an existing credit or debit card.
- Truck-safe GPS navigation to fuel savings.
- Mudflap Card: fuel discounts with credit terms, fleet controls, fraud prevention, and Visa acceptance.
- Discount network claims include 3,600+ in-network truck stops and 70,000+ fuel stops accepting the Mudflap Card.

Source: <https://www.mudflapinc.com/>

iTrucker's Co-Driver comparison is based on the current local app modules, especially:

- `iTruckersCoDriver/Modules/Compliance/ProfitPlannerView.swift`
- `iTruckersCoDriver/Modules/Compliance/LoadOpportunity.swift`
- `iTruckersCoDriver/Modules/HOS/`
- `iTruckersCoDriver/Modules/Maintenance/`
- `iTruckersCoDriver/Modules/Communications/`
- `iTruckersCoDriver/Modules/Fleet/`
- `iTruckersCoDriver/Modules/Documents/`
- `iTruckersCoDriver/Modules/Health/`

## Product Positioning

| Area | Mudflap | iTrucker's Co-Driver |
| --- | --- | --- |
| Primary job | Save money on diesel purchases. | Improve load profitability, operations, compliance, and cash collection. |
| Core user moment | Driver needs fuel and wants a lower diesel price. | Driver or dispatcher needs to decide, execute, document, invoice, and collect on a load. |
| Main economic lever | Fuel discount / fuel card savings. | Better load acceptance, accessorial recovery, reduced compliance risk, faster invoicing, and receivable visibility. |
| Operating scope | Fuel buying and fleet fuel-card controls. | Dispatch, HOS, route, compliance, maintenance, health, documents, telemetry, and profit planning. |
| Differentiation | Large diesel discount network. | AI-assisted co-driver and dispatcher workflow across the full trucking job cycle. |

## Feature Comparison

| Feature Category | Mudflap | iTrucker's Co-Driver | Notes |
| --- | --- | --- | --- |
| Diesel discounts | Yes | No dedicated discount network | Avoid duplicating Mudflap's core value. |
| Fuel card | Yes | No fuel-card product | Mudflap owns this lane. |
| Fuel spend controls | Yes, via Mudflap Card / fleet controls | Not currently a card-control product | iTrucker may track costs, but should not compete as a card product. |
| Fraud prevention for fuel card | Yes | Not currently card-focused | Leave this to fuel-card providers. |
| Truck-safe fuel navigation | Yes | Route module exists, but not a fuel-discount navigator | iTrucker should focus routing on operations, HOS, weather, and destination execution. |
| Load profit analysis | Not core public positioning | Yes | iTrucker estimates revenue, all miles, deadhead, operating cost, tax reserve, target margin, and profit per mile. |
| Minimum acceptable rate | Not core public positioning | Yes | iTrucker calculates minimum linehaul targets and rate alerts. |
| Broker/customer scorecards | Not core public positioning | Yes | iTrucker groups broker/customer history by load count, profit, rate alerts, disputes, and receivables. |
| Detention evidence | Not core public positioning | Yes | iTrucker tracks appointment, arrival, dock start, departure, free time, proof notes, and calculated detention. |
| Accessorial capture | Not core public positioning | Yes | iTrucker supports detention, layover, lumper, extra stops, driver assist, TONU, washout, and scale tickets. |
| Invoice packet generation | Not core public positioning | Yes | iTrucker generates a shareable load invoice summary with revenue, evidence, settlement, and payment status. |
| Settlement readiness | Not core public positioning | Yes | iTrucker tracks rate confirmation, BOL, POD, lumper receipt, invoice sent, payment due, paid status, and missing items. |
| Outstanding receivables | Fleet finance dashboard exists for Mudflap account/fuel finances | Yes, for load invoices | iTrucker tracks unpaid load revenue and overdue payment states. |
| HOS-aware feasibility | Not core public positioning | Yes | iTrucker includes HOS modules and load-level drive-hour feasibility checks. |
| Dispatch messaging | Not core public positioning | Yes | iTrucker includes driver-dispatch communication. |
| Maintenance workflow | Not core public positioning | Yes | iTrucker includes maintenance scheduling, issue reporting, and dispatcher visibility. |
| Health/fatigue monitoring | Not core public positioning | Yes | iTrucker includes fatigue/health monitoring concepts with driver opt-in. |
| Documents and receipts | Not core public positioning | Yes | iTrucker includes driver document browsing, forms, and receipt scanning. |

## Complementary Use Case

The apps are more complementary than competitive:

1. A driver can use **Mudflap** to reduce diesel cost at the pump.
2. The same driver or dispatcher can use **iTrucker's Co-Driver** to decide whether a load is profitable, document accessorials, monitor HOS and maintenance risk, generate invoice support, and track whether the money was actually collected.

This distinction matters because fuel is only one part of trucking profitability. A load can have cheap fuel and still lose money if the rate is low, deadhead is high, detention is undocumented, POD is missing, or payment goes stale.

## Where iTrucker Should Avoid Duplication

iTrucker should avoid building features that directly mimic Mudflap's strongest public value:

- Diesel discount marketplace.
- Fuel-card issuance.
- Fuel-card credit terms.
- Fuel-card spend controls.
- Fuel-card fraud prevention.
- Fuel-stop discount network.
- Fuel-specific merchant dashboard.

If fuel appears in iTrucker, it should support **profit calculations and operating decisions**, not become a competing diesel-discount product.

## Where iTrucker Should Lean In

iTrucker should focus on the areas Mudflap does not publicly emphasize:

- Load profitability before acceptance.
- Rate negotiation support.
- Deadhead and all-miles economics.
- Accessorial capture and proof.
- Detention and layover recovery.
- Broker/customer profitability history.
- HOS-aware load feasibility.
- Maintenance downtime planning.
- Dispatch and driver coordination.
- Settlement checklist and missing-paperwork visibility.
- Invoice packet generation.
- Open receivables and overdue payment alerts.

## Suggested Product Message

> Mudflap helps truckers save money when they buy fuel. iTrucker's Co-Driver helps truckers and dispatchers make sure the whole load is worth running, every billable item is captured, and the money gets collected.

## Practical Boundary

The clean product boundary is:

- **Mudflap:** "Where should I fuel, and how do I pay less for diesel?"
- **iTrucker's Co-Driver:** "Should I take this load, how do I run it safely and legally, what money am I owed, and what is missing before I get paid?"

