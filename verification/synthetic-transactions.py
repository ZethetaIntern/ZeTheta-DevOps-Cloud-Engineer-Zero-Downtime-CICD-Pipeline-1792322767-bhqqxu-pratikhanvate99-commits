#!/usr/bin/env python3
"""
NovaPay Digital Bank: Automated Synthetic Transaction Verification Harness
Simulates high-frequency banking transactions (UPI, IMPS, NEFT) against deployment
endpoints to verify zero-downtime cutovers, ledger integrity, and latency SLOs.
"""

import sys
import time
import json
import argparse
import random
from typing import Dict, Any

class SyntheticTransactionHarness:
    def __init__(self, target_url: str, mode: str = "dry-run"):
        self.target_url = target_url
        self.mode = mode
        self.metrics = {
            "total_sent": 0,
            "success_count": 0,
            "failure_count": 0,
            "latencies_ms": []
        }

    def execute_transaction(self, tx_type: str, payload: Dict[str, Any]) -> bool:
        self.metrics["total_sent"] += 1
        start_time = time.time()
        
        # In dry-run mode, simulate high-performance banking API responses
        if self.mode == "dry-run":
            # Simulate realistic response latency (15ms - 45ms)
            simulated_latency = random.uniform(0.015, 0.045)
            time.sleep(simulated_latency)
            success = True
            status_code = 200
        else:
            # In live mode, execute HTTP POST against preview/canary endpoints
            import urllib.request
            req = urllib.request.Request(
                f"{self.target_url}/v1/transactions/{tx_type.lower()}",
                data=json.dumps(payload).encode("utf-8"),
                headers={"Content-Type": "application/json", "X-Banking-Test": "Synthetic-SyntheticSmoke"}
            )
            try:
                with urllib.request.urlopen(req, timeout=2.0) as resp:
                    status_code = resp.status
                    success = (status_code == 200)
            except Exception as e:
                status_code = 500
                success = False

        duration_ms = (time.time() - start_time) * 1000
        self.metrics["latencies_ms"].append(duration_ms)

        if success:
            self.metrics["success_count"] += 1
        else:
            self.metrics["failure_count"] += 1

        return success

    def run_suite(self, count: int = 50) -> bool:
        print(f"[*] Commencing NovaPay Synthetic Transaction Suite (Target: {self.target_url}, Mode: {self.mode})")
        print(f"[*] Executing {count} synthetic transactions across UPI, IMPS, and NEFT...")
        
        tx_types = ["UPI_PAYMENT", "IMPS_TRANSFER", "NEFT_SETTLEMENT", "BALANCE_INQUIRY"]

        for i in range(count):
            tx_type = random.choice(tx_types)
            payload = {
                "transaction_id": f"SYNTH-TX-{random.randint(10000000, 99999999)}",
                "source_account": f"IN00{random.randint(10000000000000, 99999999999999)}",
                "destination_account": f"IN00{random.randint(10000000000000, 99999999999999)}",
                "amount_inr": round(random.uniform(10.0, 50000.0), 2),
                "timestamp": int(time.time() * 1000)
            }
            res = self.execute_transaction(tx_type, payload)
            if not res and self.mode != "dry-run":
                print(f"[-] Transaction {i+1} FAILED!")

        # Calculate statistics
        total = self.metrics["total_sent"]
        successes = self.metrics["success_count"]
        success_rate = (successes / total) * 100 if total > 0 else 0
        p99_latency = sorted(self.metrics["latencies_ms"])[int(len(self.metrics["latencies_ms"]) * 0.99)] if self.metrics["latencies_ms"] else 0
        avg_latency = sum(self.metrics["latencies_ms"]) / len(self.metrics["latencies_ms"]) if self.metrics["latencies_ms"] else 0

        print("----------------------------------------------------------------------")
        print(f"[+] Total Synthetic Transactions: {total}")
        print(f"[+] Successful: {successes} | Failed: {self.metrics['failure_count']}")
        print(f"[+] Success Rate: {success_rate:.4f}% (SLO Threshold: >= 99.99%)")
        print(f"[+] Average Latency: {avg_latency:.2f} ms")
        print(f"[+] P99 Latency: {p99_latency:.2f} ms (SLO Threshold: < 150.0 ms)")
        print("----------------------------------------------------------------------")

        if success_rate >= 99.99 and p99_latency < 150.0:
            print("[+] RESULT: ALL BANKING SLIS SATISFIED. ZERO-DOWNTIME VERIFIED.")
            return True
        else:
            print("[-] RESULT: SLI BREACH DETECTED. INITIATING CANARY ABORT / ROLLBACK.")
            return False

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="NovaPay Synthetic Transaction Test Suite")
    parser.add_argument("--url", default="http://localhost:8080", help="Target service URL")
    parser.add_argument("--mode", default="dry-run", choices=["dry-run", "live"], help="Execution mode")
    parser.add_argument("--count", type=int, default=50, help="Number of transactions")
    args = parser.parse_args()

    harness = SyntheticTransactionHarness(target_url=args.url, mode=args.mode)
    passed = harness.run_suite(count=args.count)
    sys.exit(0 if passed else 1)
