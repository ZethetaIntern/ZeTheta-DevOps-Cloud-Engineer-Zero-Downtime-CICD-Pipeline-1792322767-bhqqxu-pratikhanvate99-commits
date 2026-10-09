package novapay.compliance.rbi

import future.keywords.in

default allow = false

# RBI Master Direction (2023) Chapter III, Para 14 - Change Governance Gate
# Pull Request or Release Payload must contain a validated Change Advisory Board (CAB) ticket
allow {
    cab_ticket_valid
    sast_scan_passed
    sca_scan_passed
    dast_scan_passed
    coverage_threshold_met
    zero_destructive_ddl
}

# 1. Validate CAB ticket exists, follows format, and is in APPROVED status
cab_ticket_valid {
    regex.match("^CAB-[0-9]{4,6}$", input.change_request.cab_ticket_id)
    input.change_request.status == "APPROVED"
    count(input.change_request.cab_approvers) >= 2
}

# 2. RBI Para 23 - SAST Gate: Zero Blocker/Critical/High findings
sast_scan_passed {
    input.security_gates.sast.status == "PASSED"
    input.security_gates.sast.critical_count == 0
    input.security_gates.sast.high_count == 0
    input.security_gates.sast.sq_quality_gate == "OK"
}

# 3. RBI Para 22 - SCA Gate: Zero unmitigated Critical/High CVEs
sca_scan_passed {
    input.security_gates.sca.status == "PASSED"
    input.security_gates.sca.critical_count == 0
    input.security_gates.sca.high_count == 0
    input.security_gates.sbom.generated == true
    input.security_gates.sbom.format in ["CycloneDX", "SPDX"]
}

# 4. RBI Annex 1, Para 8 - DAST Gate: Zero dynamic security flaws
dast_scan_passed {
    input.security_gates.dast.status == "PASSED"
    input.security_gates.dast.critical_count == 0
    input.security_gates.dast.high_count == 0
}

# 5. RBI Para 16 - Quality Assurance: Minimum 85% line coverage
coverage_threshold_met {
    input.quality_gates.line_coverage >= 85.0
    input.quality_gates.branch_coverage >= 80.0
}

# 6. RBI Para 24 - Data Integrity: No locking/destructive DDL without expand-contract lifecycle
zero_destructive_ddl {
    not has_table_lock_ddl
    not has_immediate_drop_column
}

has_table_lock_ddl {
    ddl_statement := input.database_migrations.statements[_]
    regex.match("(?i)(ALTER\\s+TABLE.*ADD\\s+COLUMN.*DEFAULT\\s+(?!NULL)|LOCK\\s+TABLE|DROP\\s+TABLE)", ddl_statement)
}

has_immediate_drop_column {
    ddl_statement := input.database_migrations.statements[_]
    regex.match("(?i)ALTER\\s+TABLE.*DROP\\s+COLUMN", ddl_statement)
    input.database_migrations.phase != "contract"
}

# Failure reasons for auditing and clear developer feedback
deny[msg] {
    not cab_ticket_valid
    msg := "RBI NC-01 Violation: Missing or unapproved Change Advisory Board (CAB) ticket."
}

deny[msg] {
    not sast_scan_passed
    msg := sprintf("RBI NC-04 Violation: SAST failed with %v critical and %v high findings.", [
        input.security_gates.sast.critical_count,
        input.security_gates.sast.high_count
    ])
}

deny[msg] {
    not sca_scan_passed
    msg := sprintf("RBI NC-03 Violation: SCA dependency scan failed or missing SBOM with %v high/critical CVEs.", [
        input.security_gates.sca.critical_count + input.security_gates.sca.high_count
    ])
}

deny[msg] {
    not coverage_threshold_met
    msg := sprintf("RBI NC-09 Violation: Code coverage %v%% is below required 85.0%%.", [
        input.quality_gates.line_coverage
    ])
}

deny[msg] {
    has_table_lock_ddl
    msg := "RBI NC-10 Violation: Destructive or table-locking DDL detected. Expand-contract pattern required."
}
