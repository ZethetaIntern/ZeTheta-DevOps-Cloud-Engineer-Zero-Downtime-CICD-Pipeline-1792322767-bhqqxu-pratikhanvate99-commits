# Dashboards Architecture & Wireframe Specifications

This document defines the structural layouts and wireframe mockups for the three core dashboards monitoring NovaPay Digital Bank's CI/CD pipeline, runtime platform, and regulatory compliance posture.

---

## 1. Dashboard 1: Engineering Operations (Real-Time Ops)

```
+--------------------------------------------------------------------------------------------------+
|  NOVAPAY BANKING PLATFORM - REAL-TIME OPERATIONS DASHBOARD                      Env: Production  |
+--------------------------------------------------------------------------------------------------+
| [ LIVE TRAFFIC SPLIT ]                                | [ CANARY 5XX ERROR RATIO ] [ CANARY P99 ]|
|  Stable (v2.4.0) : [====================] 95% (4750 rps) |    0.012% (Green)          |   42 ms  |
|  Canary (v2.5.0) : [=                   ]  5% ( 250 rps) |    Threshold: < 0.05%      |  < 150ms |
+-------------------------------------------------------+---------------------------+----------+
| [ HIKARICP DB POOL UTILIZATION ]                      | [ REPLICA CPU & MEMORY HEATMAP ]         |
|  Active Conns: 48 / 100 [====                  ] 48%  |  Pod 01: [===  ] 34%   Pod 06: [==   ] 28%|
|  Pending Waiters: 0     Max Wait: 1.2 ms              |  Pod 02: [===  ] 36%   Pod 07: [===  ] 31%|
|  Replica Lag: 0.02s     Tx Throughput: 2,450 tps      |  Pod 03: [==== ] 42%   Pod 08: [==   ] 24%|
+--------------------------------------------------------------------------------------------------+
```

---

## 2. Dashboard 2: Management DORA Velocity (Executive Summary)

```
+--------------------------------------------------------------------------------------------------+
|  NOVAPAY EXECUTIVE ENGINEERING SUMMARY - DORA METRICS (30-DAY ROLLING)       Status: ELITE       |
+--------------------------------------------------------------------------------------------------+
| [ DEPLOYMENT FREQUENCY ] | [ LEAD TIME FOR CHANGES ] | [ CHANGE FAILURE RATE ] | [ MTTR ]        |
|     4.2 / day            |     1h 40m                |       0.8%              |   4m 12s        |
|  Benchmark: Multiple/day |  Target: < 2 hours        |   Target: < 5.0%        | Target: < 15m   |
|  Status: ELITE           |  Status: ELITE            |   Status: ELITE         | Status: ELITE   |
+--------------------------+---------------------------+-------------------------+-----------------+
| [ 12-WEEK DEPLOYMENT FREQUENCY & VELOCITY TREND ]    | [ COMMIT-TO-PROD DURATION BREAKDOWN ]     |
|   |         *       *        *          *            |  Build & Unit Test : 06m [=====]          |
|   |     *   *   *   *    *   *   *      *            |  SAST & SCA Scans  : 08m [======]         |
|   | *   *   *   *   *    *   *   *  *   *            |  Integration & DAST: 27m [================|
|   +--------------------------------------------      |  Canary Progression: 50m [================|
|    W1  W2  W3  W4  W5   W6  W7  W8  W9 W10 W11 W12   |  Verification Smoke: 04m [===]            |
+--------------------------------------------------------------------------------------------------+
```

---

## 3. Dashboard 3: Regulatory Compliance & Audit (RBI & PCI-DSS v4.0)

```
+--------------------------------------------------------------------------------------------------+
|  NOVAPAY REGULATORY COMPLIANCE DASHBOARD - RBI & PCI-DSS ASSURANCE           Audit Status: 100%  |
+--------------------------------------------------------------------------------------------------+
| [ OPEN RBI NON-CONFORMANCES ] | [ COSIGN IMAGE SIGNING ] | [ SEGREGATION OF DUTIES COMPLIANCE ]  |
|          0                    |         100%             |                100%                   |
|   (17 of 17 Remediated)       |  KMS-Backed Hardware Sign|   0 Self-Approvals | 4-Eyes Enforced  |
+-------------------------------+--------------------------+---------------------------------------+
| [ ACTIVE CVE STATUS (FLEET-WIDE) ]                   | [ RECENT PRODUCTION CHANGE AUDIT LOG ]    |
|   CRITICAL (CVSS >= 9.0) : 0   [PASSED]              |  19-10 17:00 | CAB-10492 | GPG Verified   |
|   HIGH     (CVSS 7.0-8.9): 0   [PASSED]              |  19-10 14:15 | CAB-10488 | Cosign Signed  |
|   MEDIUM                 : 2   [WAIVED (72h CISO)]   |  19-10 11:30 | CAB-10481 | OPA Validated  |
+--------------------------------------------------------------------------------------------------+
```
