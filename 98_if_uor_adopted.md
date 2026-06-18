# Cooperation-Native Distributed State

## Content-Addressed Temporal Ordering for Multi-Agent Systems

**Authors:** Kathryn Morgan (BrainCraft.io / ContainerCraft.io)

**Status:** Working Paper — June 2026

---

**Abstract.** The dominant model for distributed system orchestration assumes the unit of compute is a container, identity is a service account, state is a mutable key-value store, and all participants are software processes managed by human operators. These assumptions no longer hold. AI agents, hardware sensors, and humans increasingly operate as peers within the same systems, requiring identity models that do not privilege any participant type, state substrates that preserve temporal depth, and governance frameworks that compose geometrically rather than accumulate as rules. This paper describes an architectural model — and its partially-realized implementation — in which consensus is scoped to ordering decisions over content-addressed state, time is a first-class bounded interval, all agents are structural peers under attestation-based governance, and the unit of orchestration is a cooperation session rather than a workload. The architecture rests on a content-addressing substrate (the κ-label system) that unifies value identity, computation memoization, peer networking, and audit provenance into a single deterministic addressing scheme. Each layer of the system has been validated independently: the content-addressing primitive through a reference implementation with five σ-axis hash families; the storage and execution substrate through a content-addressed boot layer capable of running real operating system kernels on native hardware, in browsers, and on bare metal from a single portable core; the peer networking and identity layers through encrypted messaging and desktop application suites under daily production use; and the inference layer through a content-addressed ML engine with algebraic memoization. The consensus mechanism, policy compiler, and temporal trust authority remain unbuilt. This paper presents the structural thesis, the primitives it requires, the evidence that each primitive is individually viable, and an honest accounting of what does not yet exist.

---

## 1. Introduction

The architectural assumptions underlying distributed system orchestration were established between 2014 and 2018, primarily through the design of Kubernetes. These assumptions reflect the computational landscape of that era: the unit of compute is a Linux container; identity is a service account scoped to a namespace; state is a mutable key-value store (etcd) where consensus and storage are coupled in a single process; policy is role-based access control; and the operator — always a human — manages the system from outside it.

These assumptions produced a system of extraordinary utility. Kubernetes' programmable state machine model — custom resource definitions paired with reconciliation controllers — is among the most flexible abstractions in infrastructure engineering. Even in a successor system, programmable interfaces and state-driven reconciliation would need to be preserved.

However, three developments have eroded the foundations these assumptions rest on.

**The participants changed.** AI agents now perform work previously exclusive to human operators: writing code, operating infrastructure, making planning decisions, and interacting with other agents and humans in real time. Agent frameworks have invented ad-hoc identity, state, and coordination mechanisms because the orchestration layer does not provide appropriate primitives. A Kubernetes ServiceAccount was designed for a container making API calls, not for an AI agent requiring identification, attestation, delegation, and governance across trust boundaries. Meanwhile, IoT sensor networks, robotic actuators, and edge compute nodes introduce hardware participants that are neither containers nor human-operated services.

**The topology changed.** Multi-cloud deployment is the default posture, not the exception. Edge computing, IoT device fleets, and intermittently-connected sites are production realities. A single etcd cluster backing a single API server is architecturally incapable of spanning these topologies. Organizations work around this limitation by operating dozens of independent clusters, each with separate state, sacrificing the coherent state model that made centralized orchestration powerful. At scale, operational reports document organizations running 40 or more etcd clusters, each limited to approximately 2,000 concurrent watches before latency degrades unacceptably.

**The governance model broke.** Role-based access control was designed for a world where a small number of human administrators manage a larger number of software processes. When agents, humans, and hardware all participate as peers in the same system — and when cooperation between participants is the primary operational mode rather than unilateral control — binary allow/deny decisions cannot express the graduated, compositional, context-dependent governance that multi-agent cooperation requires.

This paper does not propose a better version of container orchestration. It proposes a different set of first principles for distributed state management, derived from the observation that the unit of orchestration is shifting from a workload container to a cooperation session between heterogeneous agents. It describes the architectural model, the substrate that implements its lower layers, and the evidence that the constituent primitives are individually viable.

---

## 2. Thesis

The architectural claim can be stated in four parts. Each is independent; together they define a system structurally different from container orchestration rather than parametrically improved.

**2.1 Consensus can be scoped to ordering decisions.** In a distributed state system, the values being stored and the decisions about which version of a value is canonical are independent concerns. Values can be stored as content-addressed blobs — immutable, self-verifying, infinitely cacheable. Consensus need only determine which content-addressed reference is current for a given key at a given time. This scoping decouples read throughput (which scales with storage and caching infrastructure) from write coordination (which scales with consensus membership), eliminating the single-leader bottleneck inherent in coupled systems.

**2.2 Time is a first-class bounded interval.** Distributed systems that treat time as a monotonic revision counter lose temporal interpretability. Systems that treat time as a wall-clock point lose causality guarantees. Hybrid Logical Clocks provide both: physical time for human interpretability and operational debugging, logical counters for causal ordering, and bounded uncertainty windows for consistency reasoning. When timestamps serve as version identifiers — a principle termed timestamp-as-tag — every state version becomes a human-readable temporal coordinate. Tiered time registration extends this model from datacenter controllers with millisecond skew tolerance to air-gapped edge sites with minutes of acceptable drift, using the same protocol.

**2.3 All agents are structural peers.** Systems that embed trust hierarchies into their identity model create attack surfaces at the privileged tier. The history of authorization system failures — Active Directory forest trust escalation, Kerberos cross-realm attacks, PKI certificate authority compromises — demonstrates that privileged tiers become targets precisely because they are privileged. The alternative is attestation-based capability evaluation: an agent's effective capabilities at any moment are determined by the attestations it currently holds, evaluated against the policy governing the requested operation. Agent type (human, AI, sensor, composite) is descriptive metadata for cooperation routing, never input to an authorization decision. This principle — the Agent Peer Axiom — holds across all protocol versions and cannot be overridden by policy.

**2.4 The unit of orchestration is a cooperation session.** Container orchestration schedules containers onto nodes, monitors their health, and restarts them on failure. The system described here orchestrates cooperation sessions: structured interactions between multiple agents with declared goals, role assignments, communication patterns, and governance constraints. A cooperation session is to this system what a Pod is to Kubernetes — the smallest schedulable unit. The difference is that a Pod contains processes; a session contains relationships.

---

## 3. Background

Each subsection identifies a prior system and the specific property adopted by the architecture. The intent is to establish that every component primitive has precedent; the contribution is their composition under a unified addressing and governance model.

### 3.1 Content-Addressed Storage at Internet Scale

The OCI Distribution Specification [1] codifies content-addressed storage proven at internet scale. Docker Hub, GitHub Container Registry, and cloud provider registries collectively serve billions of artifact pulls daily. The properties relevant to this architecture: blobs identified by cryptographic digest are immutable and infinitely cacheable; manifests compose blobs into logical units with typed relationships; tags provide mutable references to immutable content; the Referrers API enables directed graph relationships between artifacts. OCI content-addressing has been validated for container images, Helm charts, WebAssembly modules, cryptographic signatures, and arbitrary artifacts. The model is protocol-agnostic and has existing implementations at every major cloud provider and in self-hosted registries.

### 3.2 Hybrid Logical Clocks

Hybrid Logical Clocks (HLC) [2] combine physical wall-clock time with a logical counter to provide both causal ordering and temporal interpretability. An HLC timestamp is a tuple `(physical_time, logical_counter)` where the physical component is bounded within a known uncertainty window and the logical component increments only when physical time is insufficient to order events. Production telemetry from large-scale deployments indicates that 95% of wide-area events have `counter = 0` because network latency exceeds clock uncertainty — the logical counter overhead approaches zero where it is needed least [3]. Google's TrueTime [4] established the interval model `{earliest, latest}` for distributed transactions; HLC achieves equivalent ordering guarantees without GPS or atomic clock hardware dependency.

### 3.3 Consensus Algorithm Families

Raft [5] provides understandable distributed consensus with leader election, log replication, and safety guarantees. Its limitation is throughput: in coupled systems such as etcd, Raft processes every write through a single leader, creating a ceiling independent of cluster resources. CASPaxos [6] eliminates the leader bottleneck for operations on independent keys by requiring coordination only between conflicting operations. DARE [7] demonstrates RDMA-accelerated consensus achieving approximately 5μs round-trip latency by writing directly to follower memory — followers' CPUs remain passive during normal operation. The architectural insight is that consensus algorithms are substitutable when the consensus domain is scoped to ordering decisions rather than value processing.

### 3.4 The Noise Protocol Framework

The Noise Protocol Framework [8] provides a family of authenticated key exchange patterns built from Diffie-Hellman operations, symmetric encryption, and hashing. The IK pattern enables mutual authentication with forward secrecy in a single round trip. Combined with kernel-level peer credential verification, Noise IK provides zero-trust encrypted channels suitable for inter-process communication on the same host or across a network boundary.

### 3.5 Ceph RADOS

Ceph's Reliable Autonomic Distributed Object Store (RADOS) [9] provides foundational storage primitives: objects support atomic read-modify-write via object classes; the omap facility provides atomic key-value storage within objects; CRUSH-based data placement eliminates centralized metadata servers. RADOS Gateway (RGW) demonstrates the protocol projection pattern: S3 and Swift APIs are implemented as REST handlers translating HTTP operations to RADOS calls, with multiple protocols projecting onto the same underlying objects. CERN's deployment of Ceph, currently exceeding 200 PB across multiple data centers, provides operational evidence of content-addressed storage at extreme scale.

### 3.6 Cooperative Game Theory and Session Specification

The Living Framework for Cooperative Games (LFCG) [10] provides a formal taxonomy for describing cooperation between multiple participants: Player Identity, Goal Structure, Forms of Cooperation (Arrangement, Synchronicity, Communication), Dependencies, Asymmetry patterns, and Resource Sharing. The framework was developed for game design but describes a more general phenomenon: multiple heterogeneous agents with differing capabilities, information, and roles coordinating toward goals within a governed shared environment under rules they did not individually author. The specific tension LFCG resolves is the distinction between structural equality and functional asymmetry — participants can be structurally equal while being functionally asymmetric, and that asymmetry drives cooperation rather than hierarchy.

### 3.7 Content-Addressed Deterministic Computation

Functional programming and build systems (Nix, Bazel) have long established that deterministic computation over content-addressed inputs produces content-addressed outputs. The principle generalizes: if a computation's code, inputs, and configuration are all identified by their content digests, the output's digest is a deterministic function of those identifiers. This enables memoization at arbitrary granularity — from individual tensor operations to entire inference pipelines — where cache keys are derived from the content identity of operands rather than their storage location or creation time.

---

## 4. The κ-Label Substrate

The architecture rests on a unified content-addressing primitive: the κ-label (kappa-label). All higher layers — storage, computation, networking, identity, governance — reference content through κ-labels. This section describes the addressing system and its implementation.

### 4.1 Canonical Content Addressing

A κ-label is a fixed-length ASCII string of the form `{axis}:{hex-digest}`, where the axis identifies the hash algorithm and the hex-digest is the lowercase hexadecimal encoding of the hash output. For SHA-256, a κ-label is 71 bytes: `sha256:` (7 bytes) + 64 hex characters. This format is structurally identical to an OCI content digest — a κ-label produced with the SHA-256 axis IS an OCI digest, with no translation layer.

The addressing system supports five σ-axis (sigma-axis) hash families:

| Axis | Digest Size | Label Size | Authority | Primary Use |
|------|-------------|------------|-----------|-------------|
| sha256 | 32 bytes | 71 bytes | FIPS 180-4 | Default; OCI compatibility |
| blake3 | 32 bytes | 71 bytes | BLAKE3 spec | High-throughput internal paths |
| sha3-256 | 32 bytes | 73 bytes | FIPS 202 | Post-quantum transition readiness |
| keccak256 | 32 bytes | 74 bytes | Keccak (pre-FIPS) | Ethereum ecosystem compatibility |
| sha512 | 64 bytes | 135 bytes | FIPS 180-4 | 256-bit security margin |

A critical invariant: κ-labels from different σ-axes are never comparable. `sha256:abc...` and `blake3:abc...` are distinct identifiers even if the hex portion happens to match. The composition module enforces this with a compile-time axis mismatch check.

### 4.2 The ψ-Pipeline

κ-label generation follows a deterministic pipeline (the ψ-pipeline) consisting of format-specific canonicalization followed by σ-axis hashing:

1. **Canonicalization.** Raw input bytes are transformed into a canonical form specific to the input format. For JSON: JCS (RFC 8785) key sorting plus Unicode NFC normalization. For ASN.1/DER: validation that the encoding is already canonical (zero-copy path — no allocation required). For CBOR: RFC 8949 §4.2 Deterministic Encoding. For S-expressions: Rivest 1997 canonical form. Canonicalization ensures that semantically identical content produces identical κ-labels regardless of serialization differences.

2. **Streaming hash fold.** The canonical bytes are streamed through the selected σ-axis hash function in a chunk-by-chunk fold. The hasher state (~96 bytes for SHA-256) fits in L1 cache. The streaming interface avoids materializing large inputs in memory.

3. **Label formatting.** The digest bytes are formatted as lowercase hexadecimal with the axis prefix, producing a fixed-length ASCII κ-label on the stack. No heap allocation occurs in the formatting step.

4. **Witness generation.** Every addressing operation produces an `AddressOutcome` containing both the κ-label and an `AddressWitness` — a replay proof that can verify the derivation was performed correctly without re-hashing the original input. The witness records the ψ-pipeline execution trace, enabling offline audit verification.

### 4.3 Composition Operations

Five algebraic operations enable κ-label composition for compound identifiers:

- **g2 (commutative binary product):** Produces a single κ-label from two input κ-labels via lexicographically-ordered concatenation and re-hashing. The operation is commutative: g2(A, B) = g2(B, A). This is the primitive for deriving cooperation session identity from participant identities — a session between agents A and B has a stable κ-label regardless of enrollment order.

- **f4 (involution quotient):** Produces a derived κ-label via bitwise complement and re-hashing.

- **e6 (degree-partition filtration):** Tags the digest with a degree classification derived from its first byte, then re-hashes.

- **e7 (S₄-orbit augmentation):** Produces a canonical representative of the 24-element symmetric group orbit of the input digest.

- **e8 (direct embedding):** Identity operation — re-hashes canonical-form bytes without transformation.

All composition operations enforce σ-axis homogeneity: both operands must share the same axis.

### 4.4 Format Realizations

The κ-label system provides typed entry points for domain-specific data:

- **JSON realization:** `json::address()` canonicalizes via JCS+NFC, then hashes. Requires allocation for the canonical form. Used for structured agent state, session specifications, policy bundles, and goal state machines.

- **ASN.1 realization:** `asn1::address_blake3()` validates DER encoding and hashes the existing bytes with zero copy and zero allocation. Used for cryptographic keypairs, certificates, and attestations.

- **CBOR realization:** Canonicalizes via RFC 8949 §4.2. Used for compact binary interchange at trust boundaries.

- **GGUF / ONNX realizations:** Feature-gated entry points for ML model files, producing stable κ-labels for AI agent capability substrates.

- **CodeModule realization:** Addresses WebAssembly modules and code artifacts via the CCMAS canonical form.

Schema-pinned descendants extend format realizations with domain-specific structural typing. A `schema::cooperation_session` would be a JSON realization constrained to session-spec structure — the extension mechanism for domain vocabularies.

### 4.5 Cost-Model Variants

Admission predicates gate κ-label emission based on the digest's properties:

- **Storage variant:** Emits a κ-label only if the digest is lexicographically below a configurable threshold — a probabilistic admission filter for tiered storage. Content that does not pass the threshold is not admitted to expensive storage tiers.

- **Signed variant:** Requires the digest to be ultrametrically close to a reference — a proximity-based admission predicate suitable for authenticated addressing.

### 4.6 Reference Implementation

The κ-label system is implemented as `uor-addr` (UOR-ADDR-1), a Rust workspace of three crates: the core library (`no_std` capable, `#![forbid(unsafe_code)]`), a C FFI shim, and a WebAssembly component model binding. The crate is compiled with `panic = "abort"`, full LTO, and single codegen unit, ensuring the entire ψ-pipeline inlines to a single code path with no virtual dispatch. The test suite exceeds 361 tests.

---

## 5. The Content-Addressed Storage and Execution Substrate

Above the κ-label primitive, a storage and execution substrate provides the runtime infrastructure for content-addressed systems. This substrate — implemented across a family of crates collectively termed the hologram substrate — defines the traits and implementations for storing, retrieving, synchronizing, and executing content-addressed artifacts.

### 5.1 KappaStore: Content-Addressed Value Storage

The `KappaStore` trait defines the value storage interface:

```
put(axis, bytes) → KappaLabel    // Content-address and store
get(kappa)       → Option<Bytes> // Retrieve by κ-label
contains(kappa)  → bool          // Existence check
pin(kappa)       // Protect from garbage collection
unpin(kappa)     // Release GC protection
iterate()        → Vec<KappaLabel>  // Enumerate stored content
```

`Bytes` is `Arc<[u8]>` — zero-copy on retrieval. Three production implementations exist:

- **MemKappaStore:** In-memory, using `spin::Mutex` and `hashbrown::HashMap`. Supports all five σ-axes. Garbage collection by reachability from pinned roots. Suitable for `no_std` environments with an allocator.

- **NativeKappaStore:** Persistent storage backed by redb B-trees with three tables (inline, sharded, pinned). Large values (>64 KiB) are sharded into 64 KiB fragments. An LRU cache (default 256 MiB, configurable) provides read acceleration. BLAKE3 is the canonical put axis.

- **OPFS Store:** Browser-resident storage using the Origin Private File System API, enabling WebAssembly peers to persist content-addressed data across sessions.

The `KappaStore` trait has no `delete` method. This is a compile-time guarantee: content, once stored, can only be reclaimed through reachability-based garbage collection from explicitly pinned roots. Accidental or malicious deletion is structurally impossible.

### 5.2 KappaSync: Content-Addressed Peer Networking

The `KappaSync` trait defines peer-to-peer content exchange:

```
fetch(kappa)     → Option<Bytes> // Retrieve from network
announce(kappa)                   // Declare local availability
discover()       → Vec<KappaLabel> // Enumerate peer content
```

The primary implementation uses κ-XOR Kademlia — a distributed hash table where distance is computed over decoded κ-label digest bytes (not hex characters). Parameters: K=20 bucket capacity, α=3 concurrency factor, 256 k-buckets. The wire format is a length-prefixed frame with a single-byte kind discriminant.

Peer identity in this network is itself a κ-label: `address_bytes(peer_endpoint.canonicalize())`. There are no PeerIds, no Multiaddrs, no libp2p abstractions. Peer identity is derived from content addressing the peer's canonical endpoint description.

A foundational security property — verify-on-receipt — governs all network fetches: every byte sequence received from the network is re-hashed through the σ-axis before acceptance. If the re-derived κ-label does not match the requested κ-label, the response is rejected. Forged responses are detected and discarded without trusting the transport, the peer, or any intermediate cache. This property is proven by adversarial tests that inject intentionally incorrect responses and verify rejection.

### 5.3 ContainerRuntime: Content-Addressed Execution

The `ContainerRuntime` manages the lifecycle of capability-scoped execution containers:

**Spawn:** A container manifest (itself a κ-labeled artifact) references a code module (also κ-labeled). The runtime resolves the code, instantiates it within an execution engine, and applies capability constraints.

**Deliver:** Events are delivered to containers through a Deficit Round-Robin (DRR) scheduler that processes containers in deterministic sorted order. Each container has a priority weight that determines its scheduling quantum. Delivery order within a scheduling round is monotonic and reproducible.

**Suspend / Resume:** Container state is captured as a κ-labeled snapshot — a content-addressed artifact containing the container's memory, storage usage, and identity. Snapshots are stored in the `KappaStore`. Resumption on the same or a different peer requires only the snapshot's κ-label: the peer fetches the snapshot via `KappaSync`, restores the container's memory, and resumes execution. This enables live migration between peers through content addressing alone.

**Capability Enforcement:** Each container operates under a `Capabilities` set specifying: storage roots (which κ-labels the container may access), memory ceiling, CPU time budget per event, network permissions (fetch/announce), and priority weight. The `admits` function enforces a narrowing invariant: a child container's capabilities must be a subset of its parent's. Capability escalation is structurally prevented.

The WebAssembly execution engine (backed by Wasmtime with Cranelift JIT) provides the reference container engine. Host imports are restricted to a closed surface under the `"hologram"` namespace: storage operations (`storage_put`, `storage_get`, `storage_contains`), event operations (`publish`, `subscribe`), lifecycle operations (`spawn_child`, `diagnostics`), entropy (`entropy` via ChaCha20 RFC 8439), and time (`time_now`). Any import outside the `"hologram.*"` namespace causes instantiation failure — a property termed SPINE-6 (closed host surface).

### 5.4 Canonical Wire Formats

Content-addressed artifacts use a canonical wire format (SPINE-2):

```
IRI bytes | 0x00 | u32-LE ref_count | [κ-label × ref_count] | u32-LE payload_len | payload
```

References are other κ-labels that the artifact depends on. This structure enables reachability analysis (for garbage collection), dependency resolution (for fetching), and migration planning (for live transfer between peers).

DoS protection is structural: `extract_refs` bounds `Vec::with_capacity` to `min(n, bytes.len() / KAPPA71)` — a forged large reference count cannot trigger a multi-gigabyte allocation when the actual payload is small.

---

## 6. Content-Addressed Boot and Workspace Execution

The holospaces layer builds on the substrate to provide content-addressed operating system boot, workspace management, and execution environment orchestration.

### 6.1 OCI Image Ingestion

Standard OCI container images are ingested through a pipeline that re-derives every content hash at the trust boundary:

1. Fetch the image manifest from an OCI registry
2. Re-derive the manifest's SHA-256 digest (verify-on-receipt)
3. Fetch each layer blob
4. Re-derive each blob's digest
5. Store each verified blob in the `KappaStore`

The result is an `IngestedImage` — a list of layer κ-labels and their media types, anchored in the content-addressed store.

### 6.2 Streaming Filesystem Assembly

Ingested OCI layers are assembled into a bootable ext4 filesystem image through a streaming pipeline designed to bound peak memory usage:

1. **Layer overlay:** Each layer is decompressed (gzip via miniz_oxide, zstd via ruzstd) and applied through tar processing with OCI whiteout and opaque directory rules. Layers are applied sequentially; each compressed blob is dropped before the next is decompressed. Peak memory is one decompressed layer plus the growing directory tree.

2. **Sparse block extraction:** The overlaid tree is converted to 4 KiB filesystem blocks. Only non-zero blocks are materialized. The tree is explicitly dropped after block extraction to free its heap allocation before the disk is populated.

3. **Content-addressed disk construction:** Each non-zero sector is stored as a κ-labeled blob in the `KappaStore`. The disk index is a vector of κ-labels where `None` represents a sparse (all-zero) sector. A written-zeros sector and a never-written sector are canonically identical.

The ext4 filesystem writer is implemented in-crate without external tooling (no `mke2fs`), verified by `e2fsck` and `dumpe2fs`.

### 6.3 Multi-Architecture Emulation

Content-addressed disk images boot within CPU emulators implemented for three instruction set architectures:

- **RISC-V (RV64GC):** Full Sv39/Sv48/Sv57 virtual memory, CLINT timer, PLIC interrupt controller, SBI firmware interface, M-mode and S-mode privilege delegation. Passes the official riscv-tests conformance suite.

- **AArch64 (ARMv8-A):** Boots real ARM64 Linux to userspace, verified against QEMU reference.

- **x86-64:** Long-mode integer ISA with PC serial platform.

The emulator's hot path is carefully designed for cache residency. Hart register state (256 bytes), the CSR file (32 KiB flat `Box<[u64; 4096]>` — O(1) indexed access, not a tree), and the three-level TLB (18 KiB direct-mapped, generation-tagged flush) all fit in L1/L2 cache. The interrupt check (`mip & mie`) on every instruction step is a single array index. The RAM fast path gates device dispatch at a single constant (`DEVICE_MMIO_END`): any physical address above this threshold goes directly to RAM without checking CLINT, PLIC, or VirtIO ranges, ensuring that the overwhelming majority of load/store instructions skip all device dispatch logic.

VirtIO block I/O passes through the content-addressed disk: guest writes produce new κ-labeled sectors in the `KappaStore`; guest reads resolve κ-labels through an LRU sector cache (4096 sectors, 2 MiB, L3-resident for hot working sets).

### 6.4 Workspace Projection

The `Workspace` type provides interactive terminal access to a running emulator through VirtIO 9p filesystem passthrough. The `/workspace/` directory inside the guest maps to a host-side seed directory, enabling the guest environment to access project source code, configuration, and specifications while the emulator manages the operating system environment.

Input is delivered through `Intent` types (`Type` for keystrokes, `Edit` for content injection) channeled to the emulator's console. The workspace projection model — one emulator per workspace, one agent per workspace directory — is the structural foundation for fleet-scale agent topology where each module in a workspace layout runs under its own isolated execution environment.

### 6.5 Portable Peer Core

The entire boot and execution layer compiles from a single portable core for three deployment targets:

- **Native host (std):** Full OCI ingestion, network import, Wasmtime JIT, filesystem-backed `KappaStore`.
- **Browser peer (wasm32):** OCI image pull via `fetch()`, OPFS-backed storage, WebRTC content networking.
- **Bare metal (no_std):** HAL-backed storage and networking, wasmi interpreter for container execution.

The portable core has zero `std` dependencies. Surface-specific code (network transport, storage backend, execution engine) is injected through trait implementations. The same content-addressed boot sequence runs in a datacenter, a browser tab, and on embedded hardware.

---

## 7. Content-Addressed Computation

The hologram inference engine extends content addressing from storage into computation itself. Every operation in an ML inference pipeline is content-addressed: inputs, weights, intermediate results, and outputs all carry κ-labels. Identical computations produce identical κ-labels and are memoized without re-execution.

### 7.1 The .holo Archive Format

ML models are compiled into `.holo` archives — content-addressed binary artifacts with a BLAKE3 footer covering all preceding bytes. An archive contains:

- **KernelCalls section:** A sequence of typed operation descriptors (`MatMul`, `LayerNorm`, `Attention`, `Softmax`, etc. — 115 discriminants total). Each `KernelCall` is `Copy` — no heap allocation in the dispatch loop.

- **Schedule section:** Topologically sorted level groups enabling parallel execution within each level.

- **Weights section:** BLAKE3-deduplicated weight tensors. Identical weight blocks across different model layers are stored once.

- **ExecPlan section:** Per-level kernel-call indices mapping schedule levels to dispatch sequences.

- **WarmStart section:** Pre-computed results for the constant cone — nodes whose outputs are deterministic functions of compile-time constants.

- **Inputs/Outputs section:** Port descriptors specifying name, slot, element count, data type, and shape.

Archive integrity is verified on load: the BLAKE3 footer is re-derived from the archive contents.

### 7.2 Algebraic Memoization

During inference execution, every intermediate result receives a κ-label derived from the operation's opcode, parameters, and input κ-labels — not from the result's byte content. This `derive_label` operation costs O(operands), independent of tensor size, and produces a reuse key.

When the `BufferArena` (a two-generation transient memory pool) already contains a buffer with a matching reuse key, the operation is elided entirely — no dispatch, no computation, no memory allocation. For commutative operations (`Add`, `Mul`, `Xor`, `And`, `Or`, `Min`, `Max`, `Equal`), operand labels are sorted before key derivation, ensuring `a + b` and `b + a` share one κ-label.

Layout-only operations (`Reshape`, `Transpose`, `Slice`) are zero-movement: they propagate or alias their input's κ-label without copying any data.

The `graph_memo` provides whole-graph memoization: if the complete set of input κ-labels matches a previous invocation, all outputs are returned in O(1) with zero dispatch. This is particularly effective for workloads where the same inputs recur (e.g., repeated queries against static model weights).

### 7.3 Tiered Dispatch

Operations are assigned to memory tiers based on their Witt bit-width — a compile-time classification that determines the optimal cache hierarchy level:

| Bit Width | Memory Tier | Cache Target | Mechanism |
|-----------|-------------|--------------|-----------|
| ≤ 8 bits (i8) | L1 | ~32 KB | 256-entry LUT (256 bytes) |
| 9–16 bits (f16) | L2 | ~256 KB | 65536-entry LUT (128 KB) |
| 17–24 bits | Main | DDR | Segmented tables |
| ≥ 25 bits (f32) | Device | GPU VRAM | Algorithmic compute |

Tier assignment is a pure function of bit-width — no runtime branching, no element-count heuristics. LUT-accelerated operations for quantized models (i8, f16) achieve approximately 28× speedup over scalar transcendental evaluation.

### 7.4 Kernel Dispatch: Zero Virtual Dispatch

The dispatch loop uses exhaustive pattern matching on the `KernelCall` enum. There are no trait objects, no function pointer tables, no dynamic dispatch registries. The compiler can optimize the entire dispatch as a jump table. `SplitReads` uses `SmallVec<[&[u8]; 4]>` — inline-stacked for up to four operands with no heap allocation. All buffer alignment is 64 bytes (AVX-512 / cache-line alignment).

### 7.5 Backward Pass as Forward Composition

Automatic differentiation is implemented by appending backward nodes to the forward graph using vector-Jacobian product (VJP) rules composed entirely from forward operations. The backward pass uses the same `KernelCall` variants, the same `BufferArena`, the same content addressing, the same warm-start mechanism, and the same fusion passes as the forward pass. There is no separate backward code path.

### 7.6 Fusion Passes

Four load-time fusion passes reduce dispatch overhead:

- **MatMul + Activation → MatMulActivation:** Eliminates an intermediate buffer and a memory round-trip.
- **Dequantize + MatMul → MatMulDequant:** Dequantizes panel-by-panel during the matrix multiply.
- **Dequantize + Activation → DequantActivation:** Replaces dequant+widen+transcendental with a single LUT lookup.
- **Expand + Binary → BroadcastBinary:** Folds broadcast expansion into the binary operation with stride-0 indexing.

Fusion decisions are made at archive load time, once. The fused `KernelCall` discriminants exist only in the runtime dispatch vocabulary — they do not appear in the `OpKind` graph IR, maintaining clean separation between compilation and execution.

---

## 8. Scoped Consensus and Temporal Ordering

The state management layer uses the κ-label substrate for value storage and adds a thin consensus mechanism for ordering.

### 8.1 Value Storage

Values are stored as content-addressed blobs in a `KappaStore`. A value's identity is its κ-label. Identical values produce identical κ-labels regardless of when, where, or by whom they were stored. Deduplication is automatic.

The storage layer exposes three protocol projections onto the same underlying objects:

- **OCI Distribution:** Existing container tooling interacts with a conformant registry. The SHA-256 κ-label IS the OCI digest — no translation.
- **S3-compatible:** Data pipeline tools interact via the S3 API.
- **κ-addressed native:** Applications interact via content-addressed retrieval with graph traversal and capability-gated access.

### 8.2 Ordering Authority

Consensus is scoped to a single decision: which content-addressed reference is current for a given key. A consensus log entry is minimal:

```
{ key: "namespace/resource/name", winner_timestamp: "1732851800.345678901" }
```

The apply operation updates a pointer: `key/latest → timestamp`. Values are already in content-addressed storage before consensus begins. Consensus does not store values, process values, or transmit values. It resolves conflicts between concurrent writers.

Three consequences follow from this scoping:

**Read scalability.** Content-addressed blobs are served via HTTP at CDN scale. Reads do not touch the consensus path. Read throughput scales with storage and caching, not with consensus membership.

**Write sharding by namespace.** Each namespace operates its own consensus group. Cross-namespace reads are cheap; cross-namespace writes are rare and explicitly coordinated. A system with 1,000 namespaces has 1,000 independent write-coordination domains.

**Algorithm substitutability.** Because consensus is scoped to tag resolution, the algorithm can be selected per-deployment: Raft for proven reliability; CASPaxos for leaderless operation; RDMA-accelerated protocols for hardware-equipped deployments. The storage layer does not change.

### 8.3 Event Propagation

State changes emit structured telemetry events via OpenTelemetry (OTEL). This replaces the etcd watch mechanism. In etcd, the leader must maintain per-client watch state and deliver ordered notification streams, making watch fan-out the dominant CPU consumer under high churn. The leader is responsible for both consensus and notification — two concerns with different scaling characteristics forced through the same process.

In this architecture, state changes are emitted as OTEL spans with structured attributes. Collectors receive, buffer, route, and replay events. Disconnected clients reconnect from the collector's buffer, not from the consensus layer. Event consumers do not load the consensus path. Event routing is configurable per-consumer. The observability infrastructure consumes the same event stream as the state machinery — state changes are observable by construction.

### 8.4 Namespace and Directory Structure

State is organized in a namespace hierarchy where namespace identity is a UUID:

```
/store/
├── blobs/
│   └── {hash-prefix}/{digest}
├── namespaces/
│   └── {uuid}/
│       ├── _meta/
│       │   ├── name → "production"     # Cosmetic alias
│       │   ├── controller → {endpoint}
│       │   └── policy → {κ-label}      # Content-addressed governance
│       ├── keys/
│       │   └── {resource-type}/{name}/
│       │       ├── tags/
│       │       │   └── {timestamp} → {κ-label}
│       │       └── latest → {timestamp}
│       └── events/
│           └── {timestamp} → {event-κ-label}
└── federation/
    ├── controllers/
    │   └── {uuid} → {manifest-κ-label}
    └── time/
        └── sources/
            └── {node-id} → {registration-κ-label}
```

The UUID correlates across compute namespaces, OCI registry paths, and state storage — a single identifier that is the namespace everywhere it appears. Human-readable names are cosmetic aliases stored as metadata.

---

## 9. Distributed Time

### 9.1 Timestamp-as-Tag

Every state write creates a tag named for its HLC timestamp in nanosecond precision. Time IS the revision number. History is the set of all tags under a key. Any past state is queryable by timestamp — operational debugging is temporal navigation, not log replay.

### 9.2 Bounded Skew

HLC timestamps carry bounded uncertainty. A timestamp `1732851800.345678901 ± 10ms` means the event occurred within that interval. Consistency decisions reason about whether two events' uncertainty windows overlap (concurrent — requiring consensus) or are disjoint (causally ordered — requiring no coordination).

### 9.3 Tiered Time Registration

The time system supports heterogeneous node classes through tiered registration:

| Node Class | Registration Interval | Maximum Skew |
|------------|----------------------|--------------|
| Core controller | 1 second | 10 ms |
| Edge controller | 1 minute | 1 second |
| IoT device | 1 hour | 30 seconds |
| Air-gapped site | Annual / manual | Minutes |

An air-gapped site that reconnects after months synchronizes by exchanging tags. Content-addressed values are self-verifying regardless of propagation delay.

### 9.4 Temporal Trust

Clock skew is treated not as noise to suppress but as a trust signal to measure, model, and certify. Each node develops a temporal fingerprint — a statistical model of its HLC deviation behavior, including jitter spectrum analysis via FFT bins for hardware platform identification. A Temporal Trust Certificate (TTC) is a cryptographically signed assertion that a node's current temporal behavior matches its established fingerprint. TTCs are valid under specified temporal conditions (not time windows), making them robust to network partitions.

The Distributed Time Variance Authority (DTVA) manages temporal trust across the system. Nodes with consistent temporal behavior earn certificates enabling participation in higher-precision consensus. Nodes with erratic behavior have their temporal trust reduced, limiting them to eventual-consistency operations until behavior stabilizes.

### 9.5 Implementation Status

The distributed time toolkit (nine crates) provides five clock families: scalar logical, vector/matrix logical, hybrid logical, bounded hybrid with hardware attestation (ClockBound-style), and cryptographically attested (Roughtime, NTS). The SoftClock specification has undergone adversarial review identifying a wire format overflow (corrected to 20-byte fixed layout) and an incorrect restart-safety pattern (corrected to the persisted-upper-bound approach). Integration between the time toolkit and the state substrate remains in progress.

---

## 10. Identity and the Agent Peer Axiom

### 10.1 The Axiom

All agents are structural peers. Always. In every context. In every federation topology.

Humans are agents. AI systems are agents. Hardware sensors are agents. Robotic actuators are agents. Logical compositions of agents — a team, a swarm, a mixed squad — are agents. The system does not privilege any agent type over any other in its identity model.

This is a security requirement, not a philosophical preference. Hierarchy is an active persistent threat vector. Any system that embeds type-based privilege into its identity model creates a target precisely at the privileged tier.

### 10.2 Attestation-Based Capabilities

Agent identity is cryptographic. Each agent possesses a keypair whose public component, when DER-encoded and content-addressed through `asn1::address_blake3`, produces a κ-label that IS the agent's identity. Identity is therefore:

- **Generatable:** Keypair generation produces a new agent identity.
- **Attestable:** Third parties can verify the identity through cryptographic challenge.
- **Revocable:** With bounded propagation time through the federation.
- **Delegatable:** With scope constraints and time bounds. The delegation narrowing invariant ensures delegation scope can only narrow through a chain.
- **Auditable:** Every identity event (creation, attestation, revocation, delegation) is recorded in a hash-chained audit log with AddressWitness entries for provenance verification.

Agent type (human, AI, sensor, composite) is descriptive metadata carried alongside the identity. It informs cooperation routing — an LFCG session spec may request "one human participant and two AI participants" — but it never enters an authorization decision. A human agent with only a password attestation has fewer effective capabilities than an AI agent with delegation, process, and device attestations.

### 10.3 Threat Model

The identity model addresses six threat actor profiles:

1. **Local unprivileged attacker:** Mitigated by filesystem permissions, Landlock, seccomp, and kernel credential (UCred) verification.
2. **Compromised agent (any type):** Mitigated by static capability limits, delegation scope, rate limiting, behavioral anomaly detection, and revocation. The Agent Peer Axiom ensures these defenses apply identically regardless of agent type — a compromised human is as dangerous as a compromised AI.
3. **Compromised device in federation:** Mitigated by cross-device posture verification, per-device key hierarchies, and revocation propagation.
4. **Network attacker:** Mitigated by Noise IK mutual authentication, forward secrecy, and onion routing for traffic analysis resistance.
5. **Supply chain attack on extensions:** Mitigated by OCI digest pinning, capability manifests, and per-invocation enforcement.
6. **Governance hacking:** Mitigated by the non-overridable Agent Peer Axiom, base policies compiled into binaries, and the policy narrowing invariant.

### 10.4 Validated Implementation

The identity model is implemented and under daily production use in two systems. A desktop application suite (21 crates, 10 releases, 331 commits) operates a seven-daemon architecture communicating over a Noise IK encrypted IPC bus with per-daemon keypairs, Landlock filesystem sandboxing, seccomp syscall filtering, and `memfd_secret`-backed secure memory for secret-carrying types. A decentralized messaging platform implements peer-to-peer encrypted communication with identity rotation, validated through adversarial code review (305 tests including compile-fail, frozen vectors, fuzz, source-scan, and statistical unlinkability). Both systems implement per-profile encrypted vaults (SQLCipher, AES-256-CBC with HMAC-SHA512) with hash-chained audit logs, demonstrating multi-tenancy through peer isolation rather than administrative hierarchy.

---

## 11. Cooperation Sessions

### 11.1 The Session as Orchestration Unit

A cooperation session is a structured interaction between multiple agents with declared goals, roles, and governance constraints. Where Kubernetes' Deployment declares what containers to run, a Session Spec declares what cooperation structure to instantiate.

A session spec, expressed in the LFCG vocabulary, declares:

- **Participants:** Which agents (by identity or by capability requirement) are involved.
- **Goal structure:** What the session aims to accomplish, decomposed into sub-goals with dependencies.
- **Cooperation forms:** Arrangement (who works with whom), synchronicity (real-time vs. asynchronous), communication (channels and protocols).
- **Asymmetry patterns:** Which participants have different information, abilities, or roles — functional asymmetry between structural peers.
- **Resource sharing:** What state, secrets, and capabilities are shared within the session.
- **Governance constraints:** Policy manifold boundaries within which the session must operate.

### 11.2 Session Identity

A cooperation session's identity is derived from its participants using the g2 composition operation. For a session between agents A and B: `session_κ = g2(κ(A), κ(B))`. The commutativity of g2 ensures session identity is stable regardless of enrollment order. For N-party sessions, g2 applications are chained over sorted participant κ-labels.

### 11.3 Session Lifecycle

1. **Author:** A human or AI session designer writes the session spec.
2. **Compile:** A policy compiler produces a content-addressed enforcement bundle containing constraint rules, namespace configurations, capability requirements, and goal state machine definitions.
3. **Validate:** Static analysis checks for internal consistency, security soundness (no capability escalation paths), and resource feasibility.
4. **Deploy:** The bundle is stored in the state substrate. Goal state machines are initialized.
5. **Enroll:** Each agent joins the session after attestation verification against capability requirements.
6. **Run:** Agents cooperate within governance constraints. Goal state machines track progress. Policy enforcement is continuous.
7. **Conclude:** The session reaches declared completion criteria or is terminated by governance action.

### 11.4 Goal State Machines

Goals are distributed state machines tracking the evolution of cooperation objectives: current state (proposed, active, blocked, achieved, failed, abandoned), sub-goal dependencies, responsible agents, progress evidence (content-addressed artifacts), and temporal constraints. Goal State Machines are stored in the state substrate and are observable via the same OTEL event stream as all other state changes.

### 11.5 Relationship to Existing Runtime Primitives

The `ContainerRuntime` in the substrate already implements elements of the session lifecycle: `spawn` (enrollment), `deliver_event` (cooperation), `suspend`/`resume` (session state management), and `Capabilities::admits` (governance enforcement). The DRR scheduler provides deterministic, priority-weighted event delivery across enrolled containers. What remains unbuilt is the policy compiler that translates LFCG session specs into the capability sets, channel configurations, and goal state machines that the runtime enforces.

---

## 12. The Policy Manifold

### 12.1 Policy as Geometry

Traditional policy systems evaluate rules sequentially: a request arrives, rules are checked, access is granted or denied. As systems grow, rules accumulate, conflict, and become ungovernable. Composition of two rule sets is undefined without explicit conflict resolution conventions.

The alternative is geometric. A distributed system at any moment occupies a point in a high-dimensional configuration space. The set of all states the system is allowed to occupy forms a region of that space. Policy is the geometry of that region: its boundaries, its topology, the trajectories through it that are traversable.

Under this framing:

- A **rule** is a halfspace: one linear constraint on one dimension.
- A **policy** is a convex body: the intersection of many halfspaces.
- A **policy violation** is a trajectory that exits the permitted region.
- A **policy engine** is a manifold constraint system that monitors trajectories and applies corrective forces as they approach boundaries.

### 12.2 Seven Dimensions

The Policy Manifold has at least seven independent constraint dimensions:

1. **Temporal:** When operations can occur and in what causal order. Grounded in HLC timestamps and the DTVA.
2. **Identity:** Which agents can perform which operations. Grounded in the Agent Peer Axiom.
3. **Cooperation Structure:** How agents must cooperate. Grounded in LFCG session specifications.
4. **Resource:** Computational, storage, and network resource consumption limits.
5. **Content:** What data can be created, accessed, or modified. Grounded in κ-label content addressing and capability-scoped storage roots.
6. **Spatial:** Geographic or topological constraints on where operations occur.
7. **Governance:** Meta-constraints on how the other dimensions can be modified.

### 12.3 Properties

**Composability:** Two policies compose by intersecting their constraint manifolds. The result is always a valid policy. Rule systems require conflict resolution; manifold intersection is mathematically well-defined.

**Gradualism:** A manifold has interior and boundary. States near the interior are deeply within policy; states near the boundary are at risk. The engine applies graduated responses — warnings, rate limiting, capability reduction — rather than binary allow/deny decisions.

**Observability:** The distance from a state to the policy boundary is a scalar metric — policy headroom — that can be monitored, graphed, and alarmed. Policy becomes a first-class operational signal.

**Evolution:** A manifold can be deformed continuously. Policies can be loosened or tightened without invalidating existing operations.

**Frictionless flow:** Agents operating deep within the manifold interior experience zero policy overhead. Enforcement friction is proportional to behavioral deviation, not to the number of governance rules.

### 12.4 Behavioral Clearance

Beyond attestation-granted clearance, the manifold model enables behavioral clearance: clearance earned through demonstrated cooperation fidelity. An agent accumulating cooperation debt (frequent boundary approaches) has its effective clearance reduced. An agent demonstrating sustained cooperative behavior has its clearance expanded toward attestation limits. This creates a continuous trust signal that augments the binary attestation model.

### 12.5 Implementation Status

The Policy Manifold is specified but not implemented. The `Capabilities` struct in the container runtime provides a flat capability set — the closest existing primitive. The geometric policy engine, manifold boundary evaluation, PolicyGradient signals, and the LFCG-to-enforcement compiler remain unbuilt. Static analysis of manifold topology (detecting unreachable goal configurations at compile time) is a research direction.

---

## 13. Ecosystem Engineering

The layers described above — content addressing, storage, computation, consensus, time, identity, cooperation, and governance — compose into a system complex enough that its emergent behaviors cannot be predicted from component specifications alone. The discipline of designing, analyzing, and managing these emergent behaviors is termed Ecosystem Engineering.

Ecosystem Engineering borrows vocabulary from dynamical systems theory and applies it to multi-agent distributed systems:

- **Attractor states:** Configurations the ecosystem naturally converges toward given its current session specs and policy constraints.
- **Phase transitions:** Abrupt behavioral changes when control parameters cross thresholds. The engineering objective is to position the operating point away from transition boundaries.
- **Homeostatic regimes:** Stable operating ranges maintained by feedback mechanisms. Policy headroom provides the feedback signal.
- **Fitness landscapes:** Surfaces over which agent cooperation behaviors evolve. Peaks correspond to productive configurations; gradients guide agents from valleys to peaks.
- **Reconciliation ecology:** Treatment of reconciliation bandwidth as a finite ecosystem resource with carrying capacity, managed through backpressure and ecological succession.

The Policy Learning subsystem (specified, not implemented) reads reconciliation records, identifies patterns — which cooperation structures diverge under which conditions, which resolution strategies are most efficient — and compiles lessons into Policy Advisories: recommendations that session designers can apply to future specs. The learning subsystem does not automatically modify session specs (that would be a governance violation), but makes its accumulated knowledge available to designers.

Ecosystem Engineering is positioned as a general discipline applicable to any sufficiently complex multi-agent distributed system, not specific to this architecture. The contribution is the formal vocabulary that makes the discipline teachable and reproducible rather than an art practiced by experienced practitioners.

---

## 14. Substrate Validation

Each architectural layer has been validated through systems operating under production pressure. This section reports the validation relationship between the substrate and the application-layer systems that exercise it.

### 14.1 Node Agent Architecture

**System:** A multi-daemon desktop application suite (21 Rust crates, 10 releases, daily-driven) implementing window management, application launching, clipboard management, input remapping, multi-persona profiles, and secrets brokerage.

**What it validates:** The seven-daemon IPC bus architecture with Noise IK encryption, Landlock/seccomp sandboxing, `memfd_secret` secure memory, Argon2id key derivation, per-profile SQLCipher vaults, and hash-chained audit logging. The IPC transport crate was originally extracted from this system and enhanced under messaging workload pressure before returning with improvements — demonstrating the cross-project crate migration pattern.

**Measured:** Sub-200ms activation latency. Seven-daemon lifecycle under systemd watchdog monitoring.

### 14.2 Peer Networking and Identity

**System:** A decentralized messaging platform (approximately 30 workspace crates) built on peer-to-peer encrypted communication with multi-user communities, channels, and direct messages.

**What it validates:** The transport layer (IPC bus at measured throughput: AEGIS-128L seal at 14.18 GiB/s, AES-256-GCM at 3.87 GiB/s on Coffee Lake i5-9300H; pool acquire at 34ns; parallel scaling at 59% efficiency with 4 workers), the identity layer (peer identity with rotation, 305-test adversarial validation suite), and the content-addressing integration (`uor-addr` κ-labels as message identifiers with phased adoption through `ContentDigest` newtype).

### 14.3 High-Throughput I/O

**System:** A real-time video streaming application (Rust + Tauri + FFmpeg, two external contributors) that reencodes and distributes to multiple platforms simultaneously at 1080p and 4K.

**What it validates:** Transport and buffer management primitives under the most demanding conventional I/O workload. The backpressure mechanisms and parallel encoding pipeline inform event propagation design.

### 14.4 Distributed Time

**System:** A nine-crate distributed time toolkit providing five clock families.

**What it validates:** HLC + ClockBound composition as the canonical time primitive. Temporal fingerprinting with jitter spectrum FFT bins for hardware platform identification.

**Status:** Specified, implementation in progress.

### 14.5 Platform Infrastructure

**Deployed systems:** Kubernetes clusters on Talos Linux with Cilium CNI (Gateway API, eBPF), Rook-Ceph tiered storage (31.4 TiB across 3 hosts, 9 OSDs), KubeVirt virtual machines, CloudNativePG, self-hosted Forgejo, Zot OCI registry (deployed and operated in dozens of regulated datacenters), Envoy Gateway, cert-manager, Prometheus/Grafana. Nix flake-based reproducible development environments used as the daily development substrate across all projects.

**What it validates:** Operational experience running distributed storage, networking, and identity at production scale. The Ceph deployment validates the RADOS storage model. The Kubernetes deployment validates reconciliation-loop patterns. The Zot deployment validates OCI registry operation at regulated-datacenter scale.

---

## 15. Integration Surfaces and Open Problems

### 15.1 Unbuilt Components

**Consensus layer.** The state substrate, timestamp-as-tag semantics, and event emission model are specified. The consensus implementation — Raft, CASPaxos, or RDMA-accelerated — has not been built. The scope of consensus (tag-to-digest resolution only) is defined; the mechanism is not.

**Policy Manifold compiler.** The geometric framing, seven dimensions, and LFCG-to-enforcement compilation pipeline are specified. The compiler that translates session specs into enforcement bundles, manifold boundary guards, and goal state machine definitions does not exist.

**Distributed Time Variance Authority.** Temporal fingerprinting, Temporal Trust Certificates, and the DTVA consensus mechanism are specified. Implementation is in progress via the distributed time toolkit but has not reached integration.

**RADOS/RGW κ-addressed backend.** The triple protocol projection (OCI, S3, native) over a κ-addressed RADOS backend has been designed in detail, including pool organization (kappa-blobs EC 4+2 on HDD, kappa-manifests replica 3 on NVMe, kappa-index on NVMe, kappa-graph on NVMe, kappa-uploads ephemeral). The RGW extension has not been implemented. The `KappaStore` trait maps cleanly to RADOS semantics; the work is integration engineering, not architectural research.

**OTEL event emission.** The content networking layer provides fetch/announce/discover operations. OTEL span emission on state mutations — the bridge between content networking and the event propagation model — is not implemented. The `tracing` crate (compatible with `no_std` via `tracing-core`) is the identified integration path.

**Cooperation session runtime (generalized).** Elements of the session lifecycle exist within the container runtime (spawn, deliver, suspend, resume, capability enforcement) and within the application-layer systems (profile management, community sessions, peer enrollment). The generalized session runtime that accepts LFCG-compiled session specs is unbuilt.

### 15.2 Open Problems

**Write latency floor.** Separating blob storage from consensus adds latency compared to systems where both are unified. If this latency makes interactive cooperation sessions non-viable, the thesis does not hold at the session layer. This is the primary kill criterion.

**Policy Manifold topology and deadlock.** Session spec configurations may produce Policy Manifolds with topological properties (disconnected components, holes) that make certain goal configurations unreachable. Static analysis of manifold topology at compile time is a research direction with potential to catch design errors before deployment.

**Multi-ecosystem federation.** When two independent deployments federate, their Policy Manifolds must compose. Conflict resolution at federation boundaries is unspecified.

**Adversarial behavior in the learning loop.** If a compromised agent can manipulate the reconciliation ledger, it can influence the Policy Learning subsystem to weaken governance. The learning loop requires integrity protection at least as strong as the policy it learns from.

**Temporal fingerprint spoofing.** The DTVA's security model assumes that replicating a node's temporal fingerprint requires physically replicating its hardware environment. This assumption deserves formal analysis.

**Consensus algorithm selection.** The architecture is algorithm-agnostic by design, but specific deployments need specific algorithms. Selection criteria — latency requirements, hardware availability, failure domain topology — have not been validated against real cooperation session workloads.

---

## 16. Relationship to Existing Work

**etcd, ZooKeeper, Consul** couple consensus with storage, providing linearizability at the cost of throughput. This architecture demonstrates that the coupling is a design choice: consensus can be scoped to ordering decisions while storage scales independently.

**IPFS, Filecoin** use content-addressing for immutable data distribution. This architecture extends content-addressing to mutable configuration by adding scoped consensus for tag resolution, and to computation through algebraic memoization of content-addressed operations.

**Kubernetes** proved that programmable state machines with reconciliation loops work. This architecture preserves the reconciliation model while changing what is reconciled: cooperation sessions between heterogeneous agents rather than container workloads.

**CockroachDB, TiKV** provide distributed SQL/KV with strong consistency over coupled consensus-storage designs. This architecture decouples them and operates on content-addressed blobs rather than rows or key-value pairs.

**kcp / generic-controlplane** (CNCF Sandbox) stripped Kubernetes to a pure API server, removing containers as built-in resources and making them optional CRDs. This is the closest existing work to the programmable API surface — a state machine without container assumptions.

**Agent frameworks (LangChain, CrewAI, AutoGen)** provide ad-hoc multi-agent coordination without formal identity, governance, or temporal ordering. This architecture provides the infrastructure layer that agent frameworks currently reinvent per-deployment.

**Nix / Bazel** established content-addressed deterministic builds. The hologram inference engine generalizes this principle to arbitrary computation: content-addressed inputs produce content-addressed outputs with algebraic memoization at every granularity.

**Plan 9 namespaces** pioneered per-process filesystem namespace customization. The workspace projection model — content-addressed boot environments with VirtIO 9p passthrough to host workspace directories — extends this concept to content-addressed, migratable execution environments.

---

## 17. References

[1] Open Container Initiative, "OCI Distribution Specification v1.1," 2023. https://github.com/opencontainers/distribution-spec

[2] S. Kulkarni, M. Demirbas, D. Madeppa, B. Avva, and M. Leone, "Logical Physical Clocks and Consistent Snapshots in Globally Distributed Databases," OPODIS, 2014.

[3] M. Brooker, "Clocks and Clocks and Clocks," brooker.co.za, 2023.

[4] J. C. Corbett et al., "Spanner: Google's Globally-Distributed Database," OSDI, 2012.

[5] D. Ongaro and J. Ousterhout, "In Search of an Understandable Consensus Algorithm," USENIX ATC, 2014.

[6] D. Rystsov, "CASPaxos: Replicated State Machines without logs," arXiv:1802.07000, 2018.

[7] M. P. Poke and T. Hoefler, "DARE: High-Performance State Machine Replication on RDMA Networks," HPDC, 2015.

[8] T. Perrin, "The Noise Protocol Framework," noiseprotocol.org, 2018.

[9] S. A. Weil, S. A. Brandt, E. L. Miller, D. D. E. Long, and C. Maltzahn, "Ceph: A Scalable, High-Performance Distributed File System," OSDI, 2006.

[10] P. Pais, D. Gonçalves, D. Reis, J. C. N. Godinho et al., "A Living Framework for Understanding Cooperative Games," CHI '24, 2024. DOI: 10.1145/3613904.3641953

[11] UOR Foundation, "UOR-ADDR-1: Canonical Content Addressing," https://github.com/UOR-Foundation/uor-addr

[12] J. Benet, "IPFS - Content Addressed, Versioned, P2P File System," arXiv:1407.3561, 2014.

---

## Appendix A: Comparison of Orchestration Models

| Dimension | Container Orchestration | Cooperation-Native |
|-----------|------------------------|-------------------|
| Unit of orchestration | Pod (container group) | Cooperation Session |
| Identity | ServiceAccount (namespace-scoped) | Agent with attestations (peer axiom) |
| Policy | RBAC / ABAC (binary allow/deny) | Policy Manifold (geometric, graduated) |
| State substrate | etcd (coupled consensus + storage) | κ-addressed blobs + scoped consensus |
| Time model | Monotonic revision counter | HLC bounded interval with temporal trust |
| Event system | Watch mechanism (leader-maintained) | OTEL structured telemetry |
| Governance posture | Admin-operated from outside | Agents governed from within by policy |
| Inter-process communication | Services / Ingress / DNS | Encrypted peer IPC with capability routing |
| Scheduling | kube-scheduler (bin-packing) | Policy compiler + DRR session runtime |
| Extension model | Custom Resource Definitions | WASM policy filters + LFCG cooperation patterns |
| Computation model | Opaque container execution | Content-addressed memoized dispatch |
| Migration | Pod rescheduling (state loss) | κ-addressed snapshot (state preserved) |

## Appendix B: Substrate Layer Map

```
┌─────────────────────────────────────────────────────────────────────┐
│                    APPLICATION VALIDATION LAYER                      │
│  Desktop suite · Messaging · Streaming · Finance · Platform infra   │
│  (Pressure-test specific substrate capabilities under production    │
│   workloads: node agent, peer networking, I/O throughput, identity) │
└──────────────────────────────┬──────────────────────────────────────┘
                               │
┌──────────────────────────────▼──────────────────────────────────────┐
│                    HOLOSPACES: BOOT + WORKSPACE LAYER                │
│  OCI ingestion · ext4 assembly · Multi-arch emulation (RV64/A64/x64)│
│  VirtIO block/9p/net · Workspace projection · Session lifecycle     │
│  Portable core: native / browser (wasm32) / bare metal (no_std)     │
└──────────────────────────────┬──────────────────────────────────────┘
                               │
┌──────────────────────────────▼──────────────────────────────────────┐
│                    HOLOGRAM: INFERENCE LAYER                         │
│  .holo archive · Graph IR · Algebraic memoization · LUT dispatch    │
│  Autodiff as forward composition · Fusion passes · BufferArena      │
│  Zero virtual dispatch · Tiered memory hierarchy · Warm-start       │
└──────────────────────────────┬──────────────────────────────────────┘
                               │
┌──────────────────────────────▼──────────────────────────────────────┐
│                    HOLOGRAM SUBSTRATE: RUNTIME LAYER                 │
│  KappaStore (mem/native/OPFS) · KappaSync (κ-XOR Kademlia)         │
│  ContainerRuntime (DRR, capabilities, suspend/resume/migrate)       │
│  Canonical wire formats (SPINE-2) · Verify-on-receipt (SPINE-4)     │
│  Closed host surface (SPINE-6) · No-delete guarantee (SPINE-5)      │
└──────────────────────────────┬──────────────────────────────────────┘
                               │
┌──────────────────────────────▼──────────────────────────────────────┐
│                    UOR-ADDR: ADDRESSING LAYER                        │
│  κ-label (5 σ-axes) · ψ-pipeline · Format realizations             │
│  (JSON/JCS, ASN.1/DER, CBOR, S-expr, GGUF, ONNX, CodeModule)      │
│  Composition (g2, f4, e6, e7, e8) · Cost-model variants            │
│  AddressWitness (TC-05 replay) · Schema-pinned descendants          │
│  no_std + no_alloc capable · #![forbid(unsafe_code)]                │
└──────────────────────────────┬──────────────────────────────────────┘
                               │
┌──────────────────────────────▼──────────────────────────────────────┐
│                    UNBUILT D2 LAYER                                   │
│  Scoped consensus (Raft / CASPaxos / RDMA) · HLC integration       │
│  OTEL event emission · Policy Manifold compiler · DTVA              │
│  RADOS/RGW κ-addressed backend · Generalized session runtime        │
└─────────────────────────────────────────────────────────────────────┘
```

## Appendix C: Glossary

**Agent Peer Axiom.** The foundational identity principle that no agent type has inherent privilege over any other. Trust flows from attestations and policy, not from type membership. Non-overridable across all protocol versions.

**Behavioral Clearance.** Clearance earned through demonstrated cooperation fidelity, augmenting attestation-granted clearance. Both must be satisfied for high-trust operations.

**Cooperation Session.** The unit of orchestration — a structured interaction between agents with declared goals, roles, communication patterns, and governance constraints.

**DTVA.** Distributed Time Variance Authority. The temporal trust management system using clock skew as a behavioral signal.

**Ecosystem Engineering.** The discipline concerned with designing attractor states, phase transitions, homeostatic regimes, and ecological dynamics of multi-agent distributed systems.

**Goal State Machine (GSM).** Distributed state machine tracking cooperation goal lifecycle, stored in the content-addressed state substrate.

**κ-label (kappa-label).** Content-addressed identifier produced by the ψ-pipeline: `{σ-axis}:{hex-digest}`. The universal reference for all stored content, computed results, agent identities, and governance artifacts.

**LFCG.** Living Framework for Cooperative Games. The cooperation specification vocabulary adopted for session specs.

**Policy Headroom.** Scalar distance from current system state to the nearest policy manifold boundary. A first-class operational metric.

**Policy Manifold.** Geometric representation of permitted system states across seven constraint dimensions. The boundary of the manifold is the policy.

**Session Spec.** LFCG-vocabulary declaration of cooperation structure. Input to the policy compiler. Content-addressed via κ-label.

**σ-axis (sigma-axis).** The hash algorithm selection for κ-label generation. Five axes supported: sha256, blake3, sha3-256, keccak256, sha512.

**SPINE.** A family of structural security properties enforced by the substrate. SPINE-2: canonical wire format. SPINE-4: verify-on-receipt. SPINE-5: no-delete guarantee. SPINE-6: closed host surface.

**Temporal Fingerprint.** Statistical model of a node's HLC deviation behavior, basis for Temporal Trust Certificates.

**Temporal Trust Certificate (TTC).** Cryptographically signed assertion of temporal behavioral consistency, valid under specified conditions rather than time windows.

**Timestamp-as-tag.** The principle that every state version is identified by its HLC timestamp, making time the universal ordering primitive and every past state directly queryable.

**ψ-pipeline (psi-pipeline).** The deterministic processing pipeline from raw input bytes through format-specific canonicalization, σ-axis streaming hash fold, and κ-label formatting to AddressOutcome with replay witness.

---

*BrainCraft.io Research · ContainerCraft.io · opensovereign.org*