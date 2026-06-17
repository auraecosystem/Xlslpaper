# Cooperation-Native Distributed State

## Content-Addressed Temporal Ordering for Multi-Agent Systems

**Authors:** Kathryn Morgan (BrainCraft.io / ContainerCraft.io)

**Status:** Draft — June 2026

**Abstract.** Distributed systems built in the last decade assume the unit of orchestration is a container, identity is a service account, state is a mutable key-value store, and all participants are software processes managed by human operators. These assumptions no longer hold. AI agents, hardware sensors, and humans increasingly operate as peers in the same systems, requiring identity models that do not privilege any participant type, state substrates that preserve temporal depth, and governance that composes geometrically rather than stacking as rules. This paper describes an architectural model where consensus is scoped to ordering decisions over content-addressed state, time is a first-class bounded interval, all agents are structural peers under attestation-based governance, and the unit of orchestration is a cooperation session rather than a workload. Each component primitive has been validated independently through systems operating under production pressure. The paper presents the structural thesis, the primitives it requires, and the evidence that each primitive is individually viable.

---

## 1. Introduction

The dominant model for distributed system orchestration was established by Kubernetes between 2014 and 2018. Its design reflects the assumptions of that era: the unit of compute is a Linux container, identity is a service account bound to a namespace, state is a mutable key-value store (etcd) where consensus and storage are coupled, policy is role-based access control, and the operator — always a human — manages the system from outside it.

These assumptions produced a system that achieved extraordinary adoption. As of 2026, Kubernetes underpins the majority of container orchestration worldwide, and its programmable state machine model (custom resource definitions, reconciliation controllers) has proven to be one of the most flexible abstractions in infrastructure engineering. Even in a post-Kubernetes world, any replacement would need to preserve programmable interfaces and state-driven reconciliation [1].

However, three developments have eroded the assumptions Kubernetes was built on.

**First, the participants changed.** AI agents now perform work that was previously the exclusive domain of human operators. They write code, operate infrastructure, make planning decisions, and interact with other agents and humans in real time. Agent frameworks (LangChain, CrewAI, AutoGen, and their successors) have invented ad-hoc identity, state, and coordination mechanisms because the orchestration layer does not provide the right primitives. A Kubernetes ServiceAccount was designed for a container making API calls, not for an AI agent that needs to be identified, attested, delegated to, and governed across trust boundaries.

**Second, the topology changed.** Multi-cloud is the default deployment posture, not the exception. Edge computing, IoT device fleets, and intermittently-connected sites are production realities. A single etcd cluster backing a single Kubernetes API server is architecturally incapable of spanning these topologies. Organizations work around this by operating dozens of separate clusters, each with independent state, losing the coherent state model that made Kubernetes powerful in the first place. CERN operates 47 etcd clusters to support its Kubernetes infrastructure, each limited to approximately 2,000 concurrent watches before latency degradation [2].

**Third, the governance model broke.** Role-based access control was designed for a world where a small number of human administrators manage a larger number of software processes. When agents, humans, and hardware all participate as peers in the same system — and when cooperation between participants is the primary mode of operation rather than unilateral control — RBAC's binary allow/deny model cannot express the graduated, compositional, context-dependent governance that multi-agent cooperation requires.

This paper does not propose a better version of Kubernetes. It proposes a different set of first principles for distributed state management, derived from the observation that the unit of orchestration is changing from a workload container to a cooperation session between heterogeneous agents.

---

## 2. Thesis

The architectural claim of this paper can be stated in four parts:

**2.1** Consensus can be scoped to ordering decisions. In a distributed state system, the values being stored and the decisions about which version of a value is canonical are independent concerns. Values can be stored as content-addressed blobs — immutable, self-verifying, infinitely cacheable. Consensus need only determine which content-addressed reference is current for a given key at a given time. This scoping decouples read throughput (which scales with storage) from write coordination (which scales with consensus), eliminating the single-leader bottleneck that limits coupled systems like etcd.

**2.2** Time is a first-class bounded interval, not a monotonic counter. Distributed systems that treat time as a revision number (etcd's mod_revision) or a wall-clock point lose either causality or operational meaning. Hybrid Logical Clocks provide both: physical time for human interpretability, logical counters for causal ordering, bounded uncertainty for consistency reasoning. Timestamps as version identifiers (timestamp-as-tag) make every state version a human-readable temporal coordinate, and time registration tiers make the same system viable from datacenter controllers (10ms skew tolerance) to air-gapped edge sites (minutes of acceptable drift).

**2.3** All agents are structural peers. Systems that embed trust hierarchies into their identity model — "humans are more trusted than AI agents" or "operators are more privileged than workloads" — create attack surfaces precisely at the privileged tier. The history of authorization system failures (Active Directory forest trust escalation, Kerberos cross-realm attacks, PKI CA compromises) demonstrates that privileged tiers become targets because they are privileged. The alternative is attestation-based capability evaluation: an agent's effective capabilities at any moment are determined by the attestations it currently holds, evaluated against the policy governing the requested operation. A human agent with only a password attestation has fewer effective capabilities than an AI agent with a delegation attestation, a process attestation, and a device attestation. Capabilities flow from evidence, not from species. This is the Agent Peer Axiom, and it holds across all protocol versions and cannot be overridden by policy.

**2.4** The unit of orchestration is a cooperation session. Kubernetes orchestrates containers: it schedules them onto nodes, monitors their health, and restarts them on failure. The system described in this paper orchestrates cooperation sessions: structured interactions between multiple agents (human, software, hardware, or any mix) with declared goals, role assignments, communication patterns, and governance constraints. A cooperation session is to this system what a Pod is to Kubernetes — the smallest schedulable unit. The difference is that a Pod contains processes; a session contains relationships.

These four claims are independent but mutually reinforcing. Scoped consensus provides the state substrate. Temporal intervals provide the ordering primitive. Peer identity provides the participant model. Cooperation sessions provide the orchestration unit. Together, they define a system that is structurally different from container orchestration rather than a parametric improvement of it.

---

## 3. Background

This section describes the prior systems whose properties the architecture combines. Each subsection identifies the specific property being adopted, not the full system.

### 3.1 Content-Addressed Storage at Internet Scale

The OCI Distribution Specification [3] codifies a content-addressed storage model proven at internet scale. Docker Hub, GitHub Container Registry, and cloud provider registries collectively serve billions of image pulls daily. The model's relevant properties: blobs identified by cryptographic digest are immutable and infinitely cacheable; manifests compose blobs into logical units with typed relationships; tags provide mutable references to immutable content; the Referrers API enables graph relationships between artifacts.

OCI content-addressing has been validated not only for container images but for Helm charts, WASM modules, Sigstore signatures, and arbitrary artifacts. The model is protocol-agnostic (HTTP for distribution, any storage backend for persistence) and has existing implementations at every major cloud provider and in self-hosted registries (Zot, Distribution, Harbor).

### 3.2 Hybrid Logical Clocks

Hybrid Logical Clocks (HLC) [4] combine physical wall-clock time with a logical counter to provide both causal ordering and temporal interpretability. An HLC timestamp is a tuple `(physical_time, logical_counter)` where the physical component is bounded within a known uncertainty window and the logical component increments only when physical time is insufficient to order events.

The practical efficiency of HLC is established by production data: in AWS deployments, 95% of wide-area events have `counter = 0` because network latency exceeds clock uncertainty — the logical counter overhead approaches zero exactly where it matters most [5]. Google's TrueTime [6] demonstrated the interval model `{earliest, latest}` for distributed transactions; HLC achieves equivalent ordering guarantees without GPS or atomic clock hardware dependency.

### 3.3 Raft Consensus and Its Scoping

Raft [7] provides understandable distributed consensus with leader election, log replication, and safety guarantees. Its limitation is not correctness but scope: in systems like etcd, Raft processes every write operation through a single leader, creating a throughput ceiling regardless of cluster resources.

CASPaxos [8] eliminates the leader bottleneck for operations on independent keys by requiring coordination only between operations on the same key. DARE [9] demonstrates RDMA-accelerated consensus where the leader writes directly to follower memory, achieving approximately 5μs consensus latency — followers' CPUs are passive during normal operation.

The architectural insight is that consensus algorithms are substitutable when the consensus domain is scoped. If consensus determines only which tag points to which digest (not the values themselves), the consensus algorithm can be selected per-deployment based on hardware availability and latency requirements.

### 3.4 Noise Protocol Framework

The Noise Protocol Framework [10] provides a family of authenticated key exchange patterns built from Diffie-Hellman operations, symmetric encryption, and hashing. The IK pattern (static key known to initiator, transmitted by responder) enables mutual authentication with forward secrecy in a single round trip. When combined with kernel-level peer credential verification (Unix UCred: PID, UID), Noise IK provides zero-trust encrypted channels suitable for inter-process communication on the same host or across a network.

### 3.5 Ceph RADOS

Ceph's Reliable Autonomic Distributed Object Store (RADOS) [11] provides the foundational storage primitives: objects support atomic read-modify-write operations via object classes; the omap facility provides atomic key-value storage within objects; CRUSH-based data placement eliminates centralized metadata servers. RADOS Gateway (RGW) demonstrates the protocol extension pattern: S3 and Swift APIs are implemented as REST handlers translating HTTP operations to RADOS calls.

CERN's deployment of Ceph (currently exceeding 200 PB across multiple data centers) provides operational evidence of content-addressed storage at extreme scale.

### 3.6 Cooperative Game Theory and Session Specification

The Living Framework for Cooperative Games (LFCG) [12] provides a formal taxonomy for describing cooperation between multiple participants: Player Identity, Goal Structure, Forms of Cooperation (Arrangement, Synchronicity, Communication), Dependencies, Asymmetry patterns, and Resource Sharing. The framework was developed for game design but describes a more general phenomenon: multiple heterogeneous agents with differing capabilities, information, and roles, coordinating toward goals within a governed shared environment under rules they did not individually author.

The specific tension LFCG resolves is the distinction between structural equality and functional asymmetry. Participants can be structurally equal (the Agent Peer Axiom) while being functionally asymmetric (different capabilities, different information, different roles). This asymmetry drives cooperation rather than hierarchy. LFCG provides the vocabulary for specifying these relationships declaratively.

### 3.7 UOR Content Addressing

The Universal Object Reference addressing specification (UOR-ADDR-1) [13] provides chain-agnostic canonical content addressing for agent-produced content. SHA-256 over JCS-RFC8785 (JSON Canonicalization Scheme) with Unicode NFC canonical bytes produces deterministic κ-labels (kappa-labels) that identify content regardless of serialization format, transport protocol, or storage backend. The κ-label is the content-addressing primitive that unifies OCI digests, semantic identifiers, and integrity verification into a single addressing scheme.

---

## 4. Architectural Model

The architecture separates three concerns that existing systems couple: value storage, ordering authority, and event propagation.

### 4.1 Value Storage

Values are stored as content-addressed blobs in an OCI-compatible storage layer. A value's identity is its cryptographic digest. Identical values produce identical digests regardless of when, where, or by whom they were stored. Values are immutable once stored. Deduplication is automatic and free.

The storage layer exposes three protocol projections onto the same underlying objects:

- **OCI Distribution** — existing container tooling (Docker, containerd, Podman, ORAS, Helm) interacts with a conformant registry
- **S3-compatible** — data pipeline tools interact via the S3 API
- **κ-addressed native** — applications interact via content-addressed retrieval with optional graph traversal and capability-gated access

A blob pushed via OCI is retrievable via the κ-addressed API by computing its κ-label, and vice versa. The compatibility guarantee is structural, not a translation layer.

### 4.2 Ordering Authority

Consensus is scoped to a single operation: determining which content-addressed reference is current for a given key. The consensus log entry is minimal:

```
{ key: "namespace/resource/name", winner: "1732851800.345678901" }
```

The Raft apply operation updates a single pointer: `key/latest → timestamp`. Values are already in content-addressed storage before consensus begins. Consensus does not store values, does not process values, and does not transmit values. It resolves ordering conflicts.

This scoping has three consequences:

**Reads scale independently of writes.** Content-addressed blobs are served via HTTP at CDN scale. A read does not touch the consensus path. Read throughput scales with storage and caching infrastructure, not with consensus membership.

**Writes shard by namespace.** Each namespace has its own consensus group. Cross-namespace reads are cheap; cross-namespace writes are rare and explicitly coordinated. A system with 1,000 namespaces has 1,000 independent write-coordination domains.

**Consensus algorithms are substitutable.** Because the consensus domain is scoped to tag resolution, the consensus algorithm can be selected per-deployment. Raft for proven reliability. CASPaxos for leaderless operation on independent keys. RDMA-accelerated protocols for hardware-equipped deployments requiring microsecond latency. The storage layer does not change.

### 4.3 Event Propagation

State changes emit structured telemetry events via OpenTelemetry (OTEL). This replaces etcd's watch mechanism.

In etcd, watches require the leader to maintain per-client state and deliver ordered notification streams. Under high churn, watch fan-out becomes the dominant CPU consumer. The etcd leader is responsible for both consensus and notification delivery — two responsibilities with different scaling characteristics forced through the same process.

In this architecture, state changes are emitted as OTEL spans with structured attributes (operation type, key, new digest, timestamp). OTEL collectors receive, buffer, route, and replay events. Disconnected clients reconnect and catch up from the collector's buffer, not from the consensus layer. This separation means:

- Event consumers do not load the consensus path
- Event routing is configurable per-consumer (filter by namespace, by key prefix, by event type)
- Event replay uses the collector's existing retention, not a consensus log
- The observability infrastructure (tracing, metrics, alerting) consumes the same event stream as the state machinery — state changes are observable by construction

### 4.4 Directory Layout

The state substrate organizes content in a namespace hierarchy:

```
/store/
├── blobs/
│   └── {hash-prefix}/{digest}          # Content-addressed values
│
├── namespaces/
│   └── {uuid}/                          # Namespace identity is UUID
│       ├── _meta/
│       │   ├── name → "production"      # Human-readable alias (cosmetic)
│       │   ├── controller → {endpoint}  # Namespace controller location
│       │   └── policy → {digest}        # Governance policy (content-addressed)
│       │
│       ├── keys/
│       │   └── {resource-type}/{name}/
│       │       ├── tags/
│       │       │   ├── {timestamp} → {digest}   # Every write is a tag
│       │       │   └── ...
│       │       └── latest → {timestamp}          # Consensus-elected pointer
│       │
│       └── events/
│           └── {timestamp} → {event-digest}
│
└── federation/
    ├── controllers/
    │   └── {uuid} → {controller-manifest-digest}
    └── time/
        └── sources/
            └── {node-id} → {time-registration-digest}
```

Namespace identity is a UUID. Human-readable names are cosmetic aliases. The UUID correlates across compute namespaces, OCI registry paths, and state storage paths — a single identifier that is the namespace everywhere it appears.

---

## 5. Distributed Time

Time is the hardest subproblem and receives dedicated treatment.

### 5.1 Timestamp-as-Tag

Every write creates a tag named for its timestamp in nanosecond precision:

```
1. Compute digest:   sha256(value) → abc123
2. Capture timestamp: now()         → 1732851800.345678901
3. Store blob:        /blobs/ab/c123
4. Create tag:        /keys/.../tags/1732851800.345678901 → abc123
5. Update pointer:    /keys/.../latest → 1732851800.345678901
6. Emit OTEL event
```

Time IS the revision number. History is all tags under a key. Any past state is queryable by timestamp. Operational debugging is temporal navigation — "show me the state at 14:32:00" is a direct tag lookup, not a log replay.

### 5.2 Bounded Skew

HLC timestamps have bounded uncertainty. The uncertainty window is not hidden — it is a first-class parameter of the time system. A timestamp `1732851800.345678901 ± 10ms` means the event occurred within that interval. Consistency decisions can reason about whether two events' intervals overlap (concurrent, requiring consensus) or are disjoint (ordered, requiring no coordination).

### 5.3 Tiered Registration

Not all nodes need the same temporal precision. The time system supports tiered registration:

| Node Class       | Registration | Max Skew   |
|------------------|-------------|------------|
| Core controller  | 1 second    | 10ms       |
| Edge controller  | 1 minute    | 1 second   |
| IoT device       | 1 hour      | 30 seconds |
| Air-gapped site  | Annual      | Minutes    |

Tiered registration makes the same system viable from datacenter controllers to intermittently-connected edge nodes. An air-gapped site that reconnects after months synchronizes by exchanging tags — not by replaying a consensus log. The content-addressed values are self-verifying regardless of when they arrive.

### 5.4 Temporal Trust

Clock skew is not noise to suppress. It is a trust signal to measure, model, and certify. Each node develops a temporal fingerprint — a statistical model of its HLC deviation behavior. A Temporal Trust Certificate (TTC) is a cryptographically signed assertion that a node's current temporal behavior matches its established fingerprint. TTCs are valid under specified temporal conditions (not time windows), making them robust to network partitions and rejoins.

The Distributed Time Variance Authority (DTVA) manages temporal trust across the system. A node with consistent temporal behavior earns trust certificates that allow it to participate in higher-precision consensus. A node with erratic behavior has its temporal trust reduced, limiting it to eventual-consistency operations until its behavior stabilizes.

---

## 6. Identity and the Agent Peer Axiom

### 6.1 The Axiom

All agents are structural peers. Always. In every context. In every federation topology.

Humans are agents. AI systems are agents. Hardware sensors are agents. Robotic actuators are agents. Logical compositions of agents (a team, a swarm, a mixed squad) are agents. The system does not privilege any agent type over any other in its identity model.

This is not a philosophical preference. It is a security requirement.

Hierarchy is an active persistent threat vector. Any system that embeds "humans are more trusted than AI" into its identity model creates a privileged tier that becomes an attack target precisely because it is privileged. The defense against compromised agents — whether human or software — must be the same: attestation verification, capability enforcement, rate limiting, behavioral anomaly detection, delegation scope constraints, and revocation.

### 6.2 Attestation-Based Capabilities

Instead of hierarchical trust, capabilities flow from evidence:

An agent's identity is cryptographically generated (keypair), attestable (at least one mechanism for third-party verification), revocable (with bounded propagation time), delegatable (with scope constraints and time bounds), and auditable (every event recorded in a hash-chained log).

Agent type (human, AI, sensor, composite) is descriptive metadata for cooperation routing. It is never input to an authorization decision. An AI agent with appropriate attestations can receive the same capabilities as a human agent with equivalent attestations. A human agent without appropriate attestations is denied capabilities that a well-attested AI agent possesses.

### 6.3 Threat Model

The identity model defends against: local unprivileged attackers (filesystem permissions, Landlock, UCred), compromised agents of any type (static capability limits, delegation scope, rate limiting, behavioral anomaly detection), compromised devices in federation (cross-device posture verification, per-device key hierarchies, revocation propagation), network attackers (Noise IK mutual authentication, forward secrecy), supply chain attacks on extensions (OCI digest pinning, capability manifests, per-invocation enforcement), and governance hacking (the Agent Peer Axiom is non-overridable, base policies are compiled into the binary, policy narrowing is an invariant).

---

## 7. Cooperation Sessions

### 7.1 The Session as the Unit of Orchestration

In Kubernetes, a Deployment declares what containers to run. In this architecture, a Session Spec declares what cooperation structure to instantiate.

A session spec, expressed in the LFCG vocabulary, declares:

- **Participants**: which agents (by identity or by capability requirement) are involved
- **Goal structure**: what the session is trying to accomplish, decomposed into sub-goals with dependencies
- **Cooperation forms**: arrangement (who works with whom), synchronicity (real-time vs. asynchronous), communication (channels and protocols)
- **Asymmetry patterns**: which participants have different information, abilities, or roles
- **Resource sharing**: what state, secrets, and capabilities are shared within the session and how
- **Governance constraints**: policy manifold boundaries that the session must operate within

### 7.2 Session Lifecycle

The lifecycle of a session parallels but extends the lifecycle of a Kubernetes Deployment:

1. **Author**: A human or AI session designer writes the session spec
2. **Compile**: A policy compiler produces an enforcement bundle — content-addressed, containing all constraint rules, namespace configurations, capability requirements, and goal state machine definitions
3. **Validate**: Static analysis checks for internal consistency (no contradictory rules), security soundness (no capability escalation paths), and resource feasibility (required agents exist and have sufficient attestations)
4. **Deploy**: The bundle is stored in the state substrate. Goal state machines are initialized. Agent enrollment begins.
5. **Enroll**: Each agent defined in the spec is invited to join. Enrollment requires attestation verification against the session's capability requirements.
6. **Run**: Agents cooperate within the session's governance constraints. The goal state machine tracks progress. Policy enforcement is continuous.
7. **Conclude**: The session reaches its declared completion criteria, or is terminated by governance action.

### 7.3 Goal State Machines

Goals are not static declarations. They are distributed state machines stored in the state substrate, tracking the evolution of cooperation goals through their lifecycle states. A Goal State Machine (GSM) tracks:

- Current goal state (proposed, active, blocked, achieved, failed, abandoned)
- Sub-goal dependencies (which goals must complete before others can begin)
- Responsible agents (which participants are working on which goals)
- Progress evidence (content-addressed artifacts that demonstrate progress)
- Temporal constraints (deadlines, rate limits, ordering requirements)

GSMs are observable via the same OTEL event stream as all other state changes. A cooperation session's progress is as monitorable as a Kubernetes Deployment's rollout status.

---

## 8. The Policy Manifold

### 8.1 Policy as Geometry

Traditional policy systems are rule evaluators: a request arrives, rules are checked in sequence, access is granted or denied. As systems grow, rules accumulate, conflict, and become ungovernable. Composition of two policy sets is undefined — the result depends on evaluation order, conflict resolution conventions, and implicit precedence that lives in the administrators' heads.

The alternative is geometric. A distributed system at any moment occupies a state — a point in a high-dimensional configuration space. The set of all states the system is allowed to occupy forms a subset of that space. Policy is the geometry of that subset: its boundaries, its topology, the paths through it that are traversable.

Under this framing:

- A rule is a halfspace: one linear constraint on one dimension
- A policy is a convex body: the intersection of many halfspaces
- A policy violation is a trajectory that exits the permitted region
- A policy engine is a manifold constraint system that monitors trajectories and applies corrective forces when they approach boundaries

### 8.2 Dimensions

The Policy Manifold has at least seven independent dimensions:

1. **Temporal** — constraints on when operations can occur and in what causal order. Grounded in HLC timestamps and the DTVA.
2. **Identity** — constraints on which agents can perform which operations. Grounded in the Agent Peer Axiom and attestation-based capabilities.
3. **Cooperation Structure** — constraints on how agents must cooperate. Grounded in LFCG session specifications.
4. **Resource** — constraints on what computational, storage, and network resources can be consumed.
5. **Content** — constraints on what data can be created, read, modified, or deleted. Grounded in κ-label content addressing.
6. **Spatial** — constraints on where operations can occur geographically or topologically.
7. **Governance** — meta-constraints on how the other dimensions can be modified.

### 8.3 Properties

This geometric framing provides properties that rule-based systems lack:

**Composability**: Two policies compose by intersecting their constraint manifolds. The result is always a valid policy. Rule systems do not compose — they conflict.

**Gradualism**: A manifold has interior and boundary. States near the interior are deeply within policy. States near the boundary are at risk. The policy engine can apply graduated responses — warnings, rate limiting, capability reduction — without binary allow/deny decisions.

**Observability**: The distance from a state to the policy boundary is a scalar metric — policy headroom — that can be monitored, graphed, and alarmed. Policy becomes a first-class operational signal, not a post-hoc audit artifact.

**Evolution**: A manifold can be deformed continuously. Policies can be loosened or tightened without invalidating existing operations. Rule systems require version coordination; manifolds support smooth migration.

**Frictionless flow**: Well-behaved agents (those operating deep within the manifold interior) experience zero policy overhead. Enforcement friction is proportional to behavioral deviation from the cooperation norm, not to the number of rules in the policy.

---

## 9. Component Evidence

Each architectural primitive has been validated independently through systems operating under production pressure. This section reports measured evidence, not projected performance.

### 9.1 Node Agent Architecture

**System:** Open Sesame — a multi-daemon desktop application suite functioning as a window switcher, application launcher, and secret manager. 21 Rust crates, 331 commits, 10 releases (v1.9.5), daily-driven.

**What it validates:** The daemon-per-concern architecture with encrypted IPC. Seven cooperating daemons communicate over a Noise IK encrypted bus (X25519 + ChaChaPoly + BLAKE2s). Each daemon is sandboxed with Landlock filesystem restrictions and seccomp syscall filtering. Secret-carrying types use page-aligned secure memory with guard pages, canary verification, and `memfd_secret(2)` — pages removed from the kernel direct map, invisible to `/proc/pid/mem`, kernel modules, DMA, and ptrace.

**Measured:** Sub-200ms window switching activation. 7-daemon lifecycle under systemd with watchdog health monitoring. Vault unlock with Argon2id KDF (19 MiB memory, 2 iterations). BLAKE3 hash-chained audit log with tamper-evidence verification.

**Relevance:** This is the node agent architecture — the equivalent of the kubelet in container orchestration. The IPC bus, identity model, secrets management, and sandbox enforcement are directly reusable as the local management layer for cooperation session participants.

### 9.2 Peer Networking and Identity

**System:** Rekindle — a decentralized communication platform built on Veilid's peer-to-peer DHT. Multi-user TUI with communities, channels, and direct messages.

**What it validates:** Peer-to-peer encrypted messaging with identity rotation, multi-user communities, and the transport layer that D2 will use for cross-node state propagation. The `rekindle-transport-ipc` crate provides the IPC bus with measured performance. The `rekindle-identity` crate provides peer identity with rotation, validated through adversarial code review (305 tests including compile-fail, frozen vectors, fuzz, source-scan, and statistical unlinkability).

**Measured:** AEGIS-128L seal throughput at 14.18 GiB/s on Coffee Lake i5-9300H. AES-256-GCM decrypt asymmetry eliminated. Pool acquire at 34ns. Parallel scaling at 59% efficiency with 4 workers.

**Relevance:** This is the networking and identity substrate. The transport crate is portable between projects (originally extracted from Open Sesame, enhanced under Rekindle's pressure, returning to Open Sesame with improvements). The identity model with rotation, attestation, and revocation is the Agent Peer Axiom implemented at the crate level.

### 9.3 High-Throughput I/O

**System:** SpiritStream — a real-time video streaming application that reencodes and distributes to multiple platforms simultaneously. Rust + Tauri + FFmpeg. Two external contributors.

**What it validates:** The transport and buffer management primitives under the most demanding conventional I/O workload: real-time video at 1080p and 4K with simultaneous multi-platform distribution.

**Relevance:** If the transport layer handles video reencoding pressure, it handles state propagation pressure. The buffer management patterns, backpressure mechanisms, and parallel encoding pipeline inform the event propagation design.

### 9.4 Distributed Time

**System:** Chronosphere — a nine-crate distributed time toolkit providing five clock families (scalar logical, vector/matrix logical, hybrid logical, bounded hybrid with hardware attestation, and cryptographically attested).

**What it validates:** HLC + ClockBound composition as the canonical time primitive. The five-family taxonomy provides the implementation vocabulary for tiered temporal registration. Temporal fingerprinting (jitter spectrum FFT bins) provides the measurement substrate for Temporal Trust Certificates.

**Status:** Specified and implementation in progress. The SoftClock specification has undergone adversarial review identifying a P0 wire format overflow (corrected to 20-byte fixed layout) and incorrect restart-safety pattern (corrected to CockroachDB's persisted-upper-bound approach).

### 9.5 Content Addressing

**System:** UOR-ADDR (UOR Foundation) — reference Rust implementation of UOR-ADDR-1 for chain-agnostic canonical content addressing. SHA-256 over JCS-RFC8785 + Unicode NFC canonical bytes.

**What it validates:** Deterministic κ-labels for agent-produced content. The integration specification for Rekindle identifies the exact API surface: `asn1::address_blake3` for binary keypair data, `json::address_blake3` for structured content, `ContentDigest` newtype as the cross-crate carrier. The governing invariant — the transport carries `&[u8]` and never deserializes application payloads — ensures that content addressing is a semantic-layer concern, not a transport-layer concern.

**Relevance:** κ-labels are the identity primitive for stored values. They unify OCI digests, message IDs, artifact references, and policy bundle identifiers into a single addressing scheme.

### 9.6 Multi-Tenant Vaults

**Systems:** Open Sesame and Rekindle both implement encrypted per-profile databases (SQLCipher, AES-256-CBC with HMAC-SHA512), multi-factor authentication (Argon2id + SSH agent), and hash-chained audit logs. Trust profiles provide complete isolation: secrets, clipboard history, frecency ranking, snippets, and launch configurations are scoped per profile with no cross-profile leakage.

**What it validates:** Multi-tenancy framed as peer isolation rather than administrative hierarchy. Each trust profile is a tenant boundary, but no profile is inherently privileged over another — the same model that cooperation sessions will use for participant isolation.

### 9.7 Platform Infrastructure

**System:** Konductor — a Nix flake providing reproducible polyglot development environments for local, container, and virtual machine deployment. Used as the daily development environment across all projects.

**Deployed infrastructure:** Kubernetes clusters on Talos Linux with Cilium CNI (Gateway API, eBPF), Rook-Ceph tiered storage (31.4 TiB across 3 hosts, 9 OSDs), KubeVirt virtual machines, CloudNativePG, Forgejo self-hosted git, Zot OCI registry (deployed in dozens of regulated datacenters), Envoy Gateway with OIDC, cert-manager, Prometheus/Grafana, Pulumi Python as exclusive IaC.

**Relevance:** The operational experience of running distributed storage, networking, and identity at production scale informs every architectural decision in this paper. The Ceph deployment validates the RADOS storage model. The Kubernetes deployment validates the reconciliation-loop pattern that cooperation sessions extend.

---

## 10. What Does Not Exist Yet

This section identifies the unbuilt components and the open problems.

### 10.1 Unbuilt Components

**The D2 consensus layer.** The state substrate directory layout, timestamp-as-tag semantics, and OTEL event emission are specified. The consensus implementation — whether Raft, CASPaxos, or RDMA-accelerated — has not been built. The kine compatibility adapter that would allow D2 to back a kcp-lineage API server has been designed but not implemented.

**The Policy Manifold compiler.** The geometric framing, the seven dimensions, and the LFCG-to-enforcement compilation pipeline are specified. The compiler that takes a session spec and produces an enforcement bundle does not exist.

**The Distributed Time Variance Authority.** Temporal fingerprinting, Temporal Trust Certificates, and the DTVA consensus mechanism are specified. The implementation is in progress via Chronosphere but has not reached the integration stage.

**The RADOS/RGW OCI extension.** The κ-addressed RADOS backend with triple protocol projection (OCI, S3, native) has been designed in detail. The RGW extension has not been implemented.

**The cooperation session runtime.** Session specs, Goal State Machines, enrollment, and the session lifecycle are specified. The runtime that executes them does not exist as a standalone component — elements exist within Open Sesame (profile management, daemon lifecycle) and Rekindle (community sessions, peer enrollment), but the generalized session runtime is unbuilt.

### 10.2 Open Problems

**Consensus algorithm selection.** The architecture is algorithm-agnostic by design, but a specific deployment needs a specific algorithm. The selection criteria — latency requirements, hardware availability, failure domain topology — have not been validated against real cooperation session workloads.

**Policy Manifold topology and deadlock.** Can session spec configurations produce Policy Manifolds with topological properties (disconnected components, holes) that make certain goal configurations unreachable? Static analysis of manifold topology at compile time is a research direction.

**Multi-ecosystem federation.** When two independent deployments federate, their Policy Manifolds must compose. Conflict resolution at federation boundaries is unspecified.

**Adversarial learning.** If a compromised agent can manipulate the reconciliation ledger, it can influence the policy learning subsystem to weaken governance. The learning loop requires integrity protection at least as strong as the policy it learns from.

**Write latency floor.** The separation of blob storage from consensus adds latency compared to systems where consensus and storage are unified. If this latency makes interactive cooperation sessions non-viable, the thesis does not hold at the session layer and requires architectural revision. This is the primary kill criterion for the architecture.

---

## 11. Relationship to Existing Work

**etcd, ZooKeeper, Consul** couple consensus with storage, providing linearizability at the cost of throughput. This architecture demonstrates that the coupling is a design choice, not a requirement — consensus can be scoped to ordering decisions while storage scales independently.

**IPFS, Filecoin** use content-addressing for immutable data. This architecture extends content-addressing to mutable configuration by adding a thin consensus layer for tag resolution — the values are immutable, the pointers are not.

**Kubernetes** proved that programmable state machines with reconciliation loops work. This architecture preserves the reconciliation model while changing what is being reconciled: cooperation sessions instead of container workloads.

**CockroachDB, TiKV** provide distributed SQL/KV with strong consistency. They couple storage and consensus (differently from etcd, but still coupled). This architecture decouples them and operates on content-addressed blobs rather than rows or key-value pairs.

**kcp / generic-controlplane** (CNCF Sandbox) stripped Kubernetes to a pure generic API server, removing containers as built-in resources and making them optional CRDs. This is the closest existing work to the API surface this architecture targets — a programmable state machine without container assumptions.

**Agent frameworks (LangChain, CrewAI, AutoGen)** provide ad-hoc coordination for AI agents but without formal identity, governance, or temporal ordering. This architecture provides the infrastructure layer that agent frameworks currently reinvent per-deployment.

---

## 12. References

[1] K. Morgan, "Kubernetes VMware Replacement: Building Simplicity with Modern Technology," ContainerCraft.io, Feb. 2025.

[2] R. Bagnasco et al., "CERN Computing: Strategy and Evolution," CERN-IT, 2024.

[3] Open Container Initiative, "OCI Distribution Specification v1.1," 2023. https://github.com/opencontainers/distribution-spec

[4] S. Kulkarni, M. Demirbas, D. Madeppa, B. Avva, and M. Leone, "Logical Physical Clocks and Consistent Snapshots in Globally Distributed Databases," OPODIS, 2014.

[5] A. Brooker, "Clocks and Clocks and Clocks," brooker.co.za, 2023.

[6] J. C. Corbett et al., "Spanner: Google's Globally-Distributed Database," OSDI, 2012.

[7] D. Ongaro and J. Ousterhout, "In Search of an Understandable Consensus Algorithm," USENIX ATC, 2014.

[8] D. Rystsov, "CASPaxos: Replicated State Machines without logs," arXiv:1802.07000, 2018.

[9] M. P. Poke and T. Hoefler, "DARE: High-Performance State Machine Replication on RDMA Networks," HPDC, 2015.

[10] T. Perrin, "The Noise Protocol Framework," noiseprotocol.org, 2018.

[11] S. A. Weil, S. A. Brandt, E. L. Miller, D. D. E. Long, and C. Maltzahn, "Ceph: A Scalable, High-Performance Distributed File System," OSDI, 2006.

[12] P. Pais, D. Gonçalves, D. Reis, J. C. N. Godinho et al., "A Living Framework for Understanding Cooperative Games," CHI '24, 2024. DOI: 10.1145/3613904.3641953

[13] UOR Foundation, "UOR-ADDR-1: Canonical Content Addressing," https://github.com/UOR-Foundation/uor-addr

---

## Appendix A: Comparison of Orchestration Models

| Dimension | Container Orchestration (Kubernetes) | Cooperation-Native (This Paper) |
|-----------|--------------------------------------|--------------------------------|
| Unit | Pod (container group) | Cooperation Session |
| Identity | Service Account (namespace-scoped) | Agent with attestations (peer axiom) |
| Policy | RBAC / ABAC (binary allow/deny) | Policy Manifold (geometric, graduated) |
| State | etcd (coupled consensus + storage) | Content-addressed blobs + scoped consensus |
| Time | Monotonic revision counter | HLC bounded interval with temporal trust |
| Events | Watch mechanism (leader-maintained) | OTEL structured telemetry |
| Governance | Admin-operated from outside | Agents governed from within by policy |
| Networking | Services / Ingress | Encrypted peer IPC bus with capability routing |
| Scheduling | kube-scheduler (bin-packing) | Cooperation policy compiler + session runtime |
| Extension | Custom Resource Definitions | WASM policy filters + cooperation patterns |

## Appendix B: Glossary

**Agent Peer Axiom**: The foundational identity principle that no agent type has inherent privilege over any other. Trust is a function of attestations and policy, not type membership. Non-overridable.

**Behavioral Clearance**: Clearance earned through demonstrated cooperation fidelity, as distinct from clearance granted by attestation.

**Cooperation Session**: The unit of orchestration — a structured interaction between agents with declared goals, roles, and governance.

**DTVA**: Distributed Time Variance Authority. The system for temporal trust management using clock skew as a trust signal.

**Ecosystem Engineering**: The discipline concerned with designing attractor states, phase transitions, and homeostatic regimes of multi-agent distributed systems.

**Goal State Machine (GSM)**: Distributed state machine tracking cooperation goal lifecycle, stored in the state substrate.

**κ-label (kappa-label)**: Content-addressed identifier produced by canonical hashing. The universal reference for stored values.

**LFCG**: Living Framework for Cooperative Games. The cooperation specification vocabulary for session specs.

**Policy Headroom**: Scalar distance from current system state to nearest policy manifold boundary. An operational metric.

**Policy Manifold**: Geometric representation of permitted system states across multiple constraint dimensions.

**Session Spec**: LFCG-vocabulary declaration of cooperation structure. Input to the policy compiler.

**Temporal Fingerprint**: Statistical model of a node's HLC deviation behavior, basis for Temporal Trust Certificates.

**Temporal Trust Certificate (TTC)**: Cryptographically signed assertion of temporal behavioral consistency, valid under conditions rather than time windows.

**Timestamp-as-tag**: The principle that every state version is identified by its HLC timestamp, making time the universal ordering primitive.

---

*BrainCraft.io Research · ContainerCraft.io · opensovereign.org*
