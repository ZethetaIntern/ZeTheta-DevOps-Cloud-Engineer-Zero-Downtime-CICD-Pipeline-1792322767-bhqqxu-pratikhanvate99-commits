package novapay.compliance.pcidss

import future.keywords.in

default allow = false

# PCI-DSS v4.0 Release & Container Admission Gate
allow {
    image_cryptographically_signed
    slsa_provenance_valid
    zero_hardcoded_secrets
    container_security_hardened
    no_critical_or_high_vulnerabilities
}

# PCI-DSS Req 6.2.1 / 6.4.3: Cryptographic verification of image via Cosign
image_cryptographically_signed {
    input.container_security.signature.verified == true
    input.container_security.signature.key_arn == "arn:aws:kms:ap-south-1:123456789012:key/novapay-image-signing-key"
}

# PCI-DSS Req 6.3.2 / 10.2: Supply chain provenance
slsa_provenance_valid {
    input.container_security.slsa.level >= 3
    input.container_security.slsa.verified == true
}

# PCI-DSS Req 8.3: Secret Scanning (Gitleaks / Trufflehog)
zero_hardcoded_secrets {
    input.security_gates.secret_scan.findings_count == 0
}

# PCI-DSS Req 6.4.1 & OS Security: Non-root execution and read-only filesystem
container_security_hardened {
    input.pod_spec.securityContext.runAsNonRoot == true
    input.pod_spec.securityContext.runAsUser > 0
    input.pod_spec.containers[_].securityContext.readOnlyRootFilesystem == true
    input.pod_spec.containers[_].securityContext.allowPrivilegeEscalation == false
    input.pod_spec.containers[_].securityContext.capabilities.drop[_] == "ALL"
}

# PCI-DSS Req 6.3.1: Zero Critical/High vulnerabilities
no_critical_or_high_vulnerabilities {
    input.security_gates.vulnerabilities.critical == 0
    input.security_gates.vulnerabilities.high == 0
}

# Deny rules for audit transparency
deny[msg] {
    not image_cryptographically_signed
    msg := "PCI-DSS 6.4.3 Violation: Container image is unsigned or fails Cosign KMS verification."
}

deny[msg] {
    not slsa_provenance_valid
    msg := "PCI-DSS 6.3.2 Violation: Artifact lacks valid SLSA Level 3 supply chain provenance."
}

deny[msg] {
    not zero_hardcoded_secrets
    msg := sprintf("PCI-DSS 8.3 Violation: Secret scan detected %v plaintext credentials.", [
        input.security_gates.secret_scan.findings_count
    ])
}

deny[msg] {
    not container_security_hardened
    msg := "PCI-DSS 6.4.1 Violation: Container violates non-root or read-only filesystem security constraints."
}

deny[msg] {
    not no_critical_or_high_vulnerabilities
    msg := sprintf("PCI-DSS 6.3.1 Violation: Unmitigated vulnerabilities present: %v Critical, %v High.", [
        input.security_gates.vulnerabilities.critical,
        input.security_gates.vulnerabilities.high
    ])
}
