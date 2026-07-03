# NNNN — <Short Descriptive Title>

- **Status**: Proposed <!-- Proposed | Accepted | Implemented | Rejected | Superseded by NNNN -->
- **Date proposed**: YYYY-MM-DD
- **Date decided**: —
- **Date implemented**: —
- **Owner**: <who drives this>
- **Related plans**: <NNNN links, or N/A>

## Context
What situation or need prompts this change? What is true today that makes this worth doing now? Reference `docs/current-state-analysis.md` and `docs/hardware.md` where relevant.

## Decision
The single, clear decision being made. State it as a committed choice, not a list of options.

## Rationale
Why this is the right call for a single-node DevOps + Data Engineering portfolio homelab. Tie it to learning/portfolio goals and to the hardware envelope.

## Alternatives considered
| Option | Pros | Cons | Why not chosen |
| :--- | :--- | :--- | :--- |
| … | … | … | … |

## Resource budget
Concrete impact on the node (be specific — the box has 6 vCPU / 32GB RAM / finite storage):
- **vCPU**: …
- **RAM**: …
- **Storage**: … (which pool — `local-lvm` NVMe vs. the reclaimable 256GB SSD)
- **Network**: … (bridges, VLANs, ports)

## Implementation outline
High-level steps to carry this out (not the full code — that's the implementation step). Vertical slices where possible, each independently verifiable.
1. …
2. …

## Risks & rollback
What could go wrong, how it's detected, and how to back out.

## Portfolio framing
Honest one-liner on what this demonstrates to a reviewer — and what it deliberately does *not* claim (e.g. "demonstrates k3s operations, not production HA").

## Follow-ups
- [ ] Update `docs/current-state-analysis.md` once implemented
- [ ] …
