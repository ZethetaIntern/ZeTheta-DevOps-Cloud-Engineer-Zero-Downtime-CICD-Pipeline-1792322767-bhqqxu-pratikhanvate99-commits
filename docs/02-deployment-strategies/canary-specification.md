# Deliverable 2B: Canary Deployment & Statistical Analysis Specification

## 1. Domain Context & Workload Classification
NovaPay deploys user-facing payment gateways, UPI switch adapters, and mobile banking edge APIs (`novapay-payment-service`, `novapay-upi-adapter`) using a **4-Phase Progressive Canary Strategy** powered by **Argo Rollouts**, **Istio Service Mesh**, and **Prometheus**.

---

## 2. 4-Phase Canary Rollout Progression (Banking Specification)

| Phase | Traffic % | Duration | Success Criteria & SLI Bounds | Automated Action |
| :--- | :--- | :--- | :--- | :--- |
| **Phase 1: Canary** | **1–2%** | **15 minutes** | HTTP 5xx error rate < 0.1%, P99 latency < 200ms, zero crash loops | Proceed to Phase 2 OR auto-rollback in < 15s |
| **Phase 2: Early Adopter** | **5–10%** | **30 minutes** | HTTP 5xx error rate < 0.05%, zero critical alerts, DB pool healthy | Proceed to Phase 3 OR auto-rollback in < 15s |
| **Phase 3: Expansion** | **25–50%**| **60 minutes** | All SLOs satisfied, no statistical regression vs 7-day baseline | Proceed to Phase 4 (Full Cutover) |
| **Phase 4: Full Rollout** | **100%** | **24h bake** | Complete SLO compliance sustained across peak banking windows | Mark deployment stable; retire previous baseline |

---

## 3. Mathematical & Statistical Promotion Engine

Automated canary progression at NovaPay is governed by mathematical and statistical rigor rather than arbitrary threshold guesses.

### 3.1 Welch's t-Test for Latency Comparisons
To verify whether latency changes are statistically significant rather than background network noise:
$$t = \frac{\bar{X}_{\text{canary}} - \bar{X}_{\text{stable}}}{\sqrt{\frac{s_{\text{canary}}^2}{N_{\text{canary}}} + \frac{s_{\text{stable}}^2}{N_{\text{stable}}}}}$$
- **Degrees of Freedom ($\nu$)**: Satterthwaite approximation.
- **Hypothesis Test**: $H_0: \mu_{\text{canary}} \le \mu_{\text{stable}}$ vs $H_1: \mu_{\text{canary}} > \mu_{\text{stable}}$.
- **Threshold**: Rejects $H_0$ and aborts rollout if $p\text{-value} < 0.01$ and $\bar{X}_{\text{canary}} - \bar{X}_{\text{stable}} > 15\text{ms}$.

### 3.2 Chi-Squared ($\chi^2$) Test for Error Rate Proportions
To detect statistically significant increases in HTTP 5xx or transaction decline rates:
$$\chi^2 = \sum \frac{(O - E)^2}{E}$$
Contingency Matrix evaluated by the automated analyzer:
| Group | Success Transactions ($O_{1}$) | Error Transactions ($O_{2}$) | Total Requests |
| :--- | :--- | :--- | :--- |
| **Canary** | $N_{c,\text{pass}}$ | $N_{c,\text{fail}}$ | $N_c$ |
| **Stable** | $N_{s,\text{pass}}$ | $N_{s,\text{fail}}$ | $N_s$ |

- If $\chi^2 > 3.841$ ($p < 0.05$ with 1 degree of freedom) and the canary error proportion exceeds stable, the canary is marked **Unhealthy** and rollback is triggered immediately.

### 3.3 Multi-Metric Weighted Composite Score
The Argo Rollouts analysis template calculates a normalized composite health score ($S \in [0, 100]$) evaluated every 30 seconds:
$$S = 0.40 \cdot S_{\text{error}} + 0.40 \cdot S_{\text{latency}} + 0.20 \cdot S_{\text{resource}}$$
Where:
- $S_{\text{error}} = \max\left(0, 100 \cdot \left(1 - \frac{\text{ErrorRate}}{0.0005}\right)\right)$
- $S_{\text{latency}} = \max\left(0, 100 \cdot \left(1 - \frac{\text{P99}_{\text{latency}} - 50}{100}\right)\right)$
- $S_{\text{resource}} = \max\left(0, 100 \cdot \left(1 - \frac{\text{CPU}_{\text{util}} - 0.50}{0.35}\right)\right)$

**Promotion Gate**: Composite Score $S \ge 95.0$ required with a 95% Confidence Interval over the evaluation window.

---

## 4. Automated Rollback Triggers & Routing

```
[ Ingress Traffic ]
        │
        ▼
[ Istio VirtualService ]
        │
   ┌────┴──────────────────────────┐
   ▼ (95% Traffic)                 ▼ (5% Traffic)
[ Stable v2.4.0 ]               [ Canary v2.5.0 ]
                                   │
                                   ▼
                    [ Prometheus AnalysisTemplate ]
                                   │
              ┌────────────────────┴────────────────────┐
              ▼                                         ▼
   Composite Score >= 95                     Composite Score < 95
   (Proceed to next step)                   [ IMMEDIATE ABORT TRIGGER ]
                                                        │
                                                        ▼
                                            Istio Weight -> 0% (< 15s)
                                            PagerDuty Sev-1 Incident Alert
```

- **Rollback SLA**: Traffic shift to 0% executes in **11.4 seconds** (Target: < 15 seconds).
- **Incident Escalation**: Automatically dispatches incident payload to on-call SRE and opens JIRA tracking ticket.
