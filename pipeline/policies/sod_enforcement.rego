package novapay.compliance.sod

import future.keywords.in

default allow = false

# Segregation of Duties (SoD) & Four-Eyes Principle Gate
# Evaluated before allowing merge to main or initiating production GitOps deployment
allow {
    author_not_approver
    minimum_two_approvals
    security_champion_approved
    deployment_initiated_by_service_account
    no_direct_human_push
}

# 1. Author of the pull request or commit CANNOT approve the PR
author_not_approver {
    every approver in input.pull_request.approvers {
        approver.login != input.pull_request.author.login
        approver.id != input.pull_request.author.id
    }
}

# 2. Minimum of 2 distinct peer approvals required
minimum_two_approvals {
    count(input.pull_request.approvers) >= 2
}

# 3. At least one approval must be an authorized Security Champion / SecOps lead
security_champion_approved {
    some approver in input.pull_request.approvers
    approver.role in ["Security-Champion", "SecOps-Lead", "CISO-Delegate"]
}

# 4. Production deployments must be executed strictly by the automated GitOps agent (ArgoCD)
# and never directly triggered by personal human developer credentials
deployment_initiated_by_service_account {
    input.deployment.triggered_by in [
        "argocd-service-account",
        "github-actions[bot]",
        "novapay-release-automation"
    ]
}

# 5. Direct push to production branches is disabled
no_direct_human_push {
    input.git.is_direct_push == false
    input.git.ref == "refs/heads/main"
}

# Failure reasons for auditing
deny[msg] {
    not author_not_approver
    msg := "SoD Violation: Self-approval detected. Author cannot approve their own change."
}

deny[msg] {
    not minimum_two_approvals
    msg := sprintf("SoD Violation: 4-Eyes principle requires at least 2 distinct approvals, but found %v.", [
        count(input.pull_request.approvers)
    ])
}

deny[msg] {
    not security_champion_approved
    msg := "SoD Violation: Mandatory review by a designated Security Champion or SecOps Lead is missing."
}

deny[msg] {
    not deployment_initiated_by_service_account
    msg := sprintf("SoD Violation: Production deployment triggered by human user '%v'. Must be triggered via automated GitOps engine.", [
        input.deployment.triggered_by
    ])
}

deny[msg] {
    not no_direct_human_push
    msg := "SoD Violation: Direct commit push to main/production branch detected without pull request."
}
