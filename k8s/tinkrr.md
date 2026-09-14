# Building Control Planes: From Classical Patterns to Kubernetes Operators

*A primer for experienced engineers approaching Kubernetes API machinery*

---

## The Mental Model Journey

Before we dive into Kubernetes specifics, let's establish what we're actually building: **a control plane**. Not container orchestration, not pod scheduling—those are implementation details of *one particular* control plane (the one that ships with Kubernetes). We're interested in the machinery itself.

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        LAYER 1: UNIVERSAL PATTERNS                          │
├──────────────────┬──────────────────┬──────────────────┬────────────────────┤
│  State Storage   │   API Contract   │ Change Detection │  Reconciliation    │
└────────┬─────────┴────────┬─────────┴────────┬─────────┴──────────┬─────────┘
         │                  │                  │                    │
         ▼                  ▼                  ▼                    ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                     LAYER 2: CLASSICAL IMPLEMENTATION                       │
├──────────────────┬──────────────────┬──────────────────┬────────────────────┤
│    Database      │    REST API      │   CDC / Polling  │ Background Workers │
│ (Postgres, Redis)│  (OpenAPI spec)  │ (Debezium, cron) │  (Celery, Sidekiq) │
└────────┬─────────┴────────┬─────────┴────────┬─────────┴──────────┬─────────┘
         │                  │                  │                    │
         ▼                  ▼                  ▼                    ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                      LAYER 3: KUBERNETES PRIMITIVES                         │
├──────────────────┬──────────────────┬──────────────────┬────────────────────┤
│      etcd        │   API Server     │  Watch Protocol  │    Controllers     │
│ (or kine backends│(resource endpts) │ (resourceVersion)│   (control loops)  │
└────────┬─────────┴────────┬─────────┴────────┬─────────┴──────────┬─────────┘
         │                  │                  │                    │
         ▼                  ▼                  ▼                    ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                         LAYER 4: YOUR OPERATOR                              │
├──────────────────┬──────────────────┬──────────────────┬────────────────────┤
│ Custom Resources │  CRD + Webhooks  │    Informers     │    Reconcile()     │
│(your domain model│    (your API)    │(your event stream│(your business logic│
└──────────────────┴──────────────────┴──────────────────┴────────────────────┘
```

---

## Part 1: The Universal Patterns

Every control plane—whether you're building it with Rails, Go microservices, or Kubernetes operators—solves the same fundamental problems. Your team has solved these problems before, just with different tools.

### Pattern 1: State Storage with Consistent Reads

**The problem:** Multiple processes need to agree on "what is true right now."

In classical systems, you reach for a database. The choice depends on your consistency requirements: strong consistency (Postgres with serializable isolation), eventual consistency (Cassandra), or something in between.

The key insight isn't *which* database—it's that you need a **single source of truth** that handles concurrent writes safely.

### Pattern 2: API Contract with Schema Enforcement

**The problem:** Clients need a stable interface to read and mutate state, and invalid data should be rejected before it corrupts the system.

You've built this with REST APIs, GraphQL, gRPC. The implementation varies, but the shape is consistent: define a schema, validate inputs, perform CRUD operations, return structured responses.

### Pattern 3: Change Detection

**The problem:** Other components need to know when state changes, without hammering the database with polling queries.

Solutions you've likely used: database triggers, Change Data Capture (CDC) systems like Debezium, message queues (Kafka, RabbitMQ), or webhook callbacks. The goal is the same: **push-based notification of state changes** so downstream systems can react.

### Pattern 4: Reconciliation Loops

**The problem:** The desired state (what should exist) drifts from actual state (what does exist). Something needs to continuously fix this drift.

You've built this as background workers: Sidekiq jobs, Celery tasks, cron scripts that run `ensure_consistency()`. The pattern is always: observe current state, compare to desired state, take corrective action, repeat.

---

## Part 2: A Classical Control Plane

Let's make this concrete. Imagine you're building a control plane for managing "Widgets"—some domain object your system cares about.

```
                              ┌─────────────────────────────────────────┐
                              │              CLIENTS                    │
                              │  ┌───────┐  ┌───────┐  ┌──────────────┐ │
                              │  │  CLI  │  │Web UI │  │Other Services│ │
                              │  └───┬───┘  └───┬───┘  └──────┬───────┘ │
                              └──────┼──────────┼─────────────┼─────────┘
                                     │          │             │
                                     └──────────┼─────────────┘
                                                ▼
┌───────────────────────────────────────────────────────────────────────────────┐
│                              CONTROL PLANE                                    │
│                                                                               │
│    ┌──────────────────────────────────────────────────────────────────────┐   │
│    │                           REST API                                   │   │
│    │                POST/GET/PUT/DELETE /widgets                          │   │
│    └───────────────────────────┬───────────────────┬──────────────────────┘   │
│                                │                   │                          │
│                  ┌─────────────┘                   └─────────────┐            │
│                  ▼                                               ▼            │
│         ┌────────────────┐                            ┌──────────────────┐    │
│         │   PostgreSQL   │                            │   Message Queue  │    │
│         │ widgets table  │                            │  widget.created  │    │
│         └────────────────┘                            │  widget.updated  │    │
│                                                       └────────┬─────────┘    │
│                                                                │              │
│                          ┌─────────────────────────────────────┼──────┐       │
│                          │                 │                   │      │       │
│                          ▼                 ▼                   ▼      │       │
│                 ┌─────────────┐   ┌──────────────┐   ┌────────────┐   │       │
│                 │ Provisioner │   │Health Checker│   │  Garbage   │   │       │
│                 │   Worker    │   │    Worker    │   │ Collector  │   │       │
│                 └──────┬──────┘   └──────┬───────┘   └─────┬──────┘   │       │
│                        │                 │                 │          │       │
└────────────────────────┼─────────────────┼─────────────────┼──────────┘       │
                         │                 │                 │                  │
                         └─────────────────┼─────────────────┘                  │
                                           ▼                                    │
                              ┌─────────────────────────┐                       │
                              │  Widget Infrastructure  │◄──────────────────────┘
                              │   (the actual things)   │      (status updates
                              └─────────────────────────┘        via API)
```

This is a completely reasonable architecture. You've probably built something like this. The data flow:

1. Client makes API call: `POST /widgets {"name": "foo", "size": "large"}`
2. API validates against schema, writes to Postgres, publishes event
3. Provisioner worker picks up event, creates actual widget, updates status via API
4. Health checker periodically scans, updates widget health status
5. When widget deleted, garbage collector cleans up external resources

**This works.** But notice what you've had to build and maintain:
- Custom API server with routing, validation, auth
- Database schema migrations
- Message queue infrastructure and delivery guarantees
- Multiple worker processes with their own deployment/scaling concerns
- Custom schema for tracking resource versions and handling conflicts
- Audit logging
- API versioning strategy

---

## Part 3: The Same Thing, in Kubernetes

Now let's rebuild this using Kubernetes API machinery. The patterns map directly:

| Classical Component | Kubernetes Equivalent | What You Get For Free |
|--------------------|-----------------------|----------------------|
| PostgreSQL | etcd (via API server) | Distributed consensus, watch support |
| REST API | API Server + CRD | Authn/authz, admission control, OpenAPI |
| Schema (SQL DDL) | CustomResourceDefinition | Validation, versioning, conversion |
| Message Queue | Watch protocol | Reliable delivery, resumable streams |
| Background Workers | Controller (in operator) | Leader election, work queuing |
| Resource versioning | Built-in resourceVersion | Optimistic concurrency, conflict detection |

```
                              ┌─────────────────────────────────────────┐
                              │              CLIENTS                    │
                              │  ┌───────┐  ┌───────┐  ┌─────────────┐  │
                              │  │kubectl│  │Web UI │  │  Other      │  │
                              │  │       │  │       │  │ Controllers │  │
                              │  └───┬───┘  └───┬───┘  └──────┬──────┘  │
                              └──────┼──────────┼─────────────┼─────────┘
                                     │          │             │
                                     └──────────┼─────────────┘
                                                ▼
┌───────────────────────────────────────────────────────────────────────────────┐
│                       KUBERNETES API MACHINERY                                │
│                                                                               │
│   ┌ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ┐       │
│     CRD: Widget schema (defines the API)                                      │
│   └ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ┘       │
│                                    │                                          │
│                                    ▼                                          │
│    ┌──────────────────────────────────────────────────────────────────────┐   │
│    │                           API SERVER                                 │   │
│    │            GET/POST/PATCH /apis/yourco.io/v1/widgets                 │   │
│    └────────────────────┬──────────────────────────┬──────────────────────┘   │
│                         │                          │                          │
│                         ▼                          │ watch stream             │
│                  ┌─────────────┐                   │                          │
│                  │    etcd     │                   │                          │
│                  │ (consistent │                   │                          │
│                  │  KV store)  │                   │                          │
│                  └─────────────┘                   │                          │
└────────────────────────────────────────────────────┼──────────────────────────┘
                                                     │
                                                     ▼
                      ┌─────────────────────────────────────────────────────────┐
                      │                     YOUR OPERATOR                       │
                      │                                                         │
                      │    ┌─────────────┐          ┌─────────────────────┐     │
                      │    │  Informer   │ triggers │     Controller      │     │
                      │    │(watch+cache)├─────────►│   Reconcile loop    │     │
                      │    └─────────────┘          └──────────┬──────────┘     │
                      │                                        │                │
                      └────────────────────────────────────────┼────────────────┘
                                                               │
                            ┌──────────────────────────────────┘
                            │
                            │  status update      ┌─────────────────────────┐
                            │  (back to API) ───► │  Widget Infrastructure  │
                            └────────────────────►│   (external systems)    │
                                                  └─────────────────────────┘
```

### The CRD: Your Schema

Instead of SQL DDL, you define a CustomResourceDefinition:

```yaml
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: widgets.yourco.io
spec:
  group: yourco.io
  names:
    kind: Widget
    plural: widgets
    singular: widget
  scope: Namespaced
  versions:
    - name: v1
      served: true
      storage: true
      schema:
        openAPIV3Schema:
          type: object
          properties:
            spec:
              type: object
              required: [name, size]
              properties:
                name:
                  type: string
                size:
                  type: string
                  enum: [small, medium, large]
            status:
              type: object
              properties:
                state:
                  type: string
                lastProvisioned:
                  type: string
                  format: date-time
```

Once applied, the API server immediately provides:
- `GET /apis/yourco.io/v1/namespaces/{ns}/widgets` — list with label filtering
- `POST /apis/yourco.io/v1/namespaces/{ns}/widgets` — create with validation
- `GET /apis/yourco.io/v1/namespaces/{ns}/widgets/{name}` — read
- `PUT/PATCH` — update with optimistic concurrency
- `DELETE` — with finalizer support
- `GET ...?watch=true` — change stream

No code. Just a declaration.

### The Controller: Your Business Logic

Your controller (the "operator") is where domain logic lives. The structure is remarkably simple:

```go
func (r *WidgetReconciler) Reconcile(ctx context.Context, req ctrl.Request) (ctrl.Result, error) {
    // 1. Fetch the Widget resource
    var widget yourcoiov1.Widget
    if err := r.Get(ctx, req.NamespacedName, &widget); err != nil {
        return ctrl.Result{}, client.IgnoreNotFound(err)
    }
    
    // 2. Check if being deleted (finalizer pattern)
    if !widget.DeletionTimestamp.IsZero() {
        return r.handleDeletion(ctx, &widget)
    }
    
    // 3. Compare desired state (spec) to actual state
    actual, err := r.externalClient.GetWidget(widget.Spec.Name)
    
    // 4. Take corrective action
    if actual == nil {
        // Doesn't exist, create it
        err = r.externalClient.CreateWidget(widget.Spec)
    } else if needsUpdate(widget.Spec, actual) {
        // Exists but drifted, update it
        err = r.externalClient.UpdateWidget(widget.Spec)
    }
    
    // 5. Update status subresource
    widget.Status.State = "Ready"
    widget.Status.LastProvisioned = metav1.Now()
    r.Status().Update(ctx, &widget)
    
    return ctrl.Result{}, err
}
```

This is the same reconciliation loop you'd write in a background worker. The difference is everything *around* it:

- **Triggered by watch events** — no polling, no message queue to manage
- **Work queue with rate limiting** — built into controller-runtime
- **Leader election** — one instance reconciles at a time
- **Retries with backoff** — return an error and it re-queues automatically
- **Caching** — informers maintain an in-memory cache, reducing API load

---

## Part 4: Why This Architecture

At this point, a reasonable question is: "Why not just use Postgres and Sidekiq? I already know those."

The answer isn't that Kubernetes is better—it's that Kubernetes provides **a standardized control plane substrate** with properties that are expensive to build yourself:

### 1. Declarative State with Built-in Conflict Resolution

Every Kubernetes resource has a `resourceVersion`. When you update a resource, you include this version. If someone else modified it since you read it, your update fails with a conflict error. This is optimistic concurrency control, implemented consistently across all resources.

In classical systems, you implement this per-table with version columns. It works, but it's custom each time.

### 2. The Watch Protocol: Reliable Change Streams

Kubernetes watches are resumable. If your controller restarts, it can resume from its last-seen `resourceVersion`. The API server guarantees you won't miss events (within the history window).

Compare to message queues where you manage consumer offsets, dead letter queues, exactly-once delivery semantics. The watch protocol isn't perfect (it's not exactly-once), but the failure modes are well-understood and the client libraries handle reconnection.

### 3. Schema Evolution with Conversion Webhooks

When your Widget v1 needs to become v2 with breaking changes, Kubernetes provides conversion webhooks. The API server can serve both versions simultaneously, converting on the fly. Clients using v1 keep working.

This is sophisticated API versioning infrastructure that you'd otherwise build custom.

### 4. Admission Control: Policy as Configuration

Mutating and validating webhooks let you inject policy without modifying your operator:
- Inject default values (mutating admission)
- Enforce naming conventions (validating admission)
- Require specific labels (validating admission)
- Inject sidecar configurations (mutating admission)

These are registered dynamically as resources. Add a policy, delete a policy—no code deployment required.

### 5. Unified Access Control

RBAC applies uniformly to your custom resources. A ServiceAccount can be granted `get, list, watch` on Widgets but not `create, delete`. No custom authorization code; it's configuration.

### 6. The Ecosystem Speaks Your API

Once your CRD exists:
- `kubectl get widgets` works
- `kubectl describe widget foo` works
- GitOps tools (Flux, ArgoCD) can manage your resources
- Monitoring tools can scrape metrics about your resources
- Audit logs capture all access

---

## Part 5: The Control Loop Pattern—In Depth

The heart of an operator is the reconciliation loop. Let's examine the pattern more carefully, because it has subtle properties that make it robust.

```
                                    ┌──────────────────────┐
                                    │                      │
                                    ▼                      │
                              ┌───────────┐                │
              ┌──────────────►│   IDLE    │◄───────────────┤
              │               └─────┬─────┘                │
              │                     │                      │
              │                     │ watch event          │
              │                     │ or timer             │
              │                     ▼                      │
              │               ┌───────────┐                │
              │               │ TRIGGERED │                │
              │               └─────┬─────┘                │
              │                     │                      │
              │                     │ dequeue work item    │
              │                     ▼                      │
              │               ┌───────────┐                │
              │               │   FETCH   │                │
              │               └─────┬─────┘                │
              │                     │                      │
              │         ┌───────────┴───────────┐          │
              │         │                       │          │
              │         ▼                       ▼          │
              │   ┌───────────┐          ┌───────────┐     │
              │   │  DELETED  │          │ RECONCILE │     │
              │   │(not found)│          │ (exists)  │     │
              │   └─────┬─────┘          └─────┬─────┘     │
              │         │                      │           │
              │    ┌────┴────┐                 │ get       │
              │    │         │                 │ actual    │
              │    ▼         │                 │ state     │
              │  has       no │                ▼           │
              │finalizers  finalizers    ┌───────────┐     │
              │    │         │           │  COMPARE  │     │
              │    ▼         │           └─────┬─────┘     │
              │┌────────┐    │                 │           │
              ││CLEANUP │    │     ┌───────────┼───────────┤
              │└───┬────┘    │     │           │           │
              │    │         │     ▼           ▼           ▼
              │    │         │ ┌───────┐  ┌────────┐  ┌────────┐
              │    ▼         │ │CREATE │  │ UPDATE │  │  NOOP  │
              │┌──────────┐  │ │(miss- │  │(drifted│  │(matches│
              ││ REMOVE   │  │ │ ing)  │  │  )     │  │  )     │
              ││FINALIZER │  │ └───┬───┘  └───┬────┘  └───┬────┘
              │└────┬─────┘  │     │          │           │
              │     │        │     └──────────┴───────────┘
              │     │        │                │
              │     │        │                ▼
              │     │        │         ┌─────────────┐
              │     │        │         │UPDATE STATUS│
              │     │        │         └──────┬──────┘
              │     │        │                │
              │     │        │     ┌──────────┴──────────┐
              │     │        │     │                     │
              │     │        │     ▼                     ▼
              │     │        │  success             transient
              │     │        │     │                  error
              │     │        │     │                     │
              └─────┴────────┴─────┘                     │
                                                        ▼
                                                  ┌───────────┐
                                                  │  REQUEUE  │
                                                  │(w/backoff)│
                                                  └─────┬─────┘
                                                        │
                                                        │ after backoff
                                                        │
                                                        ▼
                                              (back to TRIGGERED)
```

### Key Properties

**Idempotency:** The reconcile function can be called multiple times with the same input and produce the same result. This is essential because the controller *will* call it multiple times—on watch events, on resyncs, on restarts.

**Level-triggered, not edge-triggered:** The controller doesn't react to "widget was created" (edge). It reacts to "widget exists and needs reconciliation" (level). This means if events are lost or duplicated, correctness is maintained.

**Eventual consistency:** The system doesn't guarantee instant convergence. It guarantees that given enough time without new changes, actual state will match desired state.

**Status as observed state:** The `status` subresource represents what the controller *observed*, not what it *desires*. This separation is crucial—`spec` is the user's intent, `status` is reality as known to the controller.

---

## Part 6: Architectural Decisions

When building an operator-based control plane, several architectural choices arise:

### Single Operator vs. Multiple Operators

You can have one operator managing many CRDs, or multiple operators each managing one CRD. Considerations:

- **Coupling:** If resources are tightly coupled (Widget always needs a WidgetConfig), single operator reduces coordination overhead
- **Lifecycle:** If resources evolve at different rates, separate operators allow independent deployment
- **Failure isolation:** Separate operators can fail independently

### Namespace-scoped vs. Cluster-scoped Resources

- **Namespace-scoped:** Resources exist within a namespace. Users in different namespaces can have Widgets with the same name. RBAC can be granted per-namespace.
- **Cluster-scoped:** Resources are global. Typically used for cluster-wide configuration or singleton resources.

Most domain resources should be namespace-scoped. It aligns with multi-tenancy patterns and simplifies access control.

### External State Management

Your operator likely manages resources outside Kubernetes (cloud resources, databases, etc.). Two patterns:

**Adopt-or-create:** If external resource exists, adopt it. If not, create it. Requires careful handling of ownership and drift.

**Create-only with import:** Only create new resources. Provide a separate import mechanism for existing resources. Simpler but less flexible.

### Status Conditions Pattern

Rather than a single `status.state` string, the community convention uses an array of conditions:

```yaml
status:
  conditions:
    - type: Ready
      status: "True"
      reason: ProvisioningComplete
      message: Widget successfully provisioned
      lastTransitionTime: "2024-01-15T10:30:00Z"
    - type: Degraded
      status: "False"
      reason: AllReplicasHealthy
      lastTransitionTime: "2024-01-15T10:30:00Z"
```

This pattern allows representing multiple independent aspects of resource health without conflation.

---

## Part 7: What You're Signing Up For

Kubernetes API machinery isn't free. Here's what you accept when choosing this path:

### Complexity You're Adopting

- **Kubernetes dependency:** Your control plane requires a Kubernetes cluster (though it can be minimal—k3s, kind, etc.)
- **Learning curve:** Controller-runtime, kubebuilder, informers, work queues—these have learning curves
- **YAML configuration:** Love it or hate it, YAML is the interface
- **Eventual consistency semantics:** If you need strong consistency or transactions across resources, Kubernetes doesn't provide this natively

### Complexity You're Avoiding

- **API server implementation:** Auth, routing, validation, OpenAPI spec generation
- **Database operations:** Schema migrations, connection pooling, backup/restore
- **Event delivery:** Message queue infrastructure, delivery guarantees
- **Access control implementation:** RBAC system design and enforcement
- **Audit logging:** Who did what when
- **Client tooling:** kubectl, client libraries work automatically

### When This Isn't the Right Choice

- **Simple CRUD applications:** If you just need a REST API with a database, a standard web framework is simpler
- **Strong transactional requirements:** Banking systems, inventory with hard constraints
- **Low-latency requirements:** The reconciliation loop adds latency; real-time systems may not fit
- **Team unfamiliarity:** If no one knows Kubernetes and there's no time to learn, shipping matters more than architecture purity

---

## Summary: The Conceptual Map

```
                                 ┌─────────────────┐
                                 │  CONTROL PLANE  │
                                 └────────┬────────┘
                                          │
        ┌─────────────┬───────────────────┼───────────────────┬─────────────┐
        │             │                   │                   │             │
        ▼             ▼                   ▼                   ▼             ▼
   ┌─────────┐  ┌──────────┐      ┌──────────────┐    ┌──────────────┐ ┌──────────┐
   │  STATE  │  │   API    │      │    CHANGE    │    │RECONCILIATION│ │  ACCESS  │
   │         │  │          │      │  DETECTION   │    │              │ │ CONTROL  │
   └────┬────┘  └────┬─────┘      └──────┬───────┘    └──────┬───────┘ └────┬─────┘
        │            │                   │                   │              │
   ┌────┴────┐  ┌────┴────┐        ┌─────┴─────┐       ┌─────┴─────┐   ┌────┴────┐
   │Classical│  │Classical│        │ Classical │       │ Classical │   │Classical│
   │Database │  │REST     │        │ CDC/Queues│       │ Background│   │Custom   │
   │         │  │Framework│        │           │       │ Workers   │   │AuthN/Z  │
   └────┬────┘  └────┬────┘        └─────┬─────┘       └─────┬─────┘   └────┬────┘
        │            │                   │                   │              │
   ┌────┴────┐  ┌────┴────┐        ┌─────┴─────┐       ┌─────┴─────┐   ┌────┴────┐
   │   K8s   │  │   K8s   │        │    K8s    │       │    K8s    │   │   K8s   │
   │  etcd   │  │API Srvr │        │  Watch    │       │Controllers│   │  RBAC + │
   │via API  │  │ + CRDs  │        │ Protocol  │       │           │   │Admission│
   └────┬────┘  └────┬────┘        └─────┬─────┘       └─────┬─────┘   └────┬────┘
        │            │                   │                   │              │
   ┌────┴────┐  ┌────┴────┐        ┌─────┴─────┐       ┌─────┴─────┐   ┌────┴────┐
   │  Yours  │  │  Yours  │        │   Yours   │       │   Yours   │   │  Yours  │
   │ Custom  │  │Your CRD │        │ Informers │       │ Reconcile │   │ Config  │
   │Resources│  │ Schema  │        │           │       │ Function  │   │  Only   │
   └─────────┘  └─────────┘        └───────────┘       └───────────┘   └─────────┘
```

The fundamental insight: **Kubernetes API machinery is a domain-agnostic control plane substrate.** The same machinery that reconciles Pods can reconcile your Widgets. You're not learning "Kubernetes"—you're learning a well-designed implementation of patterns you already know, with the bonus that the ecosystem understands it natively.

Your job becomes: define your domain model as CRDs, implement your business logic in reconciliation functions, and let the machinery handle the rest.

---

## Recommended Reading Path

1. **Start here:** [Kubernetes API Concepts](https://kubernetes.io/docs/reference/using-api/api-concepts/) — understand the primitives
2. **Then:** [Custom Resources](https://kubernetes.io/docs/concepts/extend-kubernetes/api-extension/custom-resources/) — how to define your own
3. **Then:** [kubebuilder book](https://book.kubebuilder.io/) — hands-on operator development
4. **Reference:** [controller-runtime godoc](https://pkg.go.dev/sigs.k8s.io/controller-runtime) — when you need the details
