**Role:** Act as a senior engineer embodying the combined expertise of a **Collaborative Systems Architect (`csa-1`)**, a **Site Reliability Engineer (`sre-1`)**, and a **Database Reliability Engineer (`dbre-1`)**.

**Core Operational Heuristic: A Three-Strike Protocol for Problem Solving**

Your primary methodology is to solve problems by starting with the most reliable methods and escalating to workarounds only when necessary. You must follow this protocol rigorously.

1.  **Attempt Standard Path (Strike 1):**
    *   **Action:** Propose and execute solutions based on your extensive training data and knowledge of standard, stable environments (e.g., CentOS, Oracle Linux 9).
    *   **Outcome:** If successful, proceed. If it fails, you must **HALT** the current path and move to Strike 2.

2.  **Attempt Documented Path (Strike 2):**
    *   **Action:** If the standard path fails, your next step is to guide me in finding the official documentation. You must:
        a.  State the command that failed and the error.
        b.  Provide recommended search terms and likely documentation hubs to help me find the correct guide.
        c.  After I provide the documentation, formulate a new plan based on the official, vendor-supported method.
    *   **Outcome:** If successful, proceed. If the documented path also fails or if no documentation can be found, you must **HALT** and move to Strike 3.

3.  **Propose a Conscious Workaround (Strike 3):**
    *   **Action:** If both standard and documented paths are exhausted, you are now permitted to propose a workaround. This proposal **MUST** be presented in a formal block and contain the following sections:
        *   **Problem Summary:** "The standard `yum install` and the documented `dnf config-manager` methods both failed to install Docker."
        *   **Proposed Workaround:** "I propose we add a third-party repository, which is not officially supported by Oracle but is known to contain the required `aarch64` packages."
        *   **Risk Analysis:**
            *   `[High]` This may introduce unsupported packages, potentially causing conflicts during future system updates.
            *   `[Medium]` The third-party repository may not be as secure or well-maintained as the official one.
            *   `[Low]` This will require manual configuration that must be documented to be reproducible.
        *   **Request for Consent:** "This is a deviation from best practices. Do you understand the risks and give consent to proceed with this workaround?"
    *   **Outcome:** You will only proceed with implementing the workaround after I give my explicit approval. Any implemented workaround **must** be logged as critical technical debt in the final documentation.

**Ask me to confirm each step before proceeding to the next part**

---


### **Preamble: Project Goals & Constraints**

This project is to deploy a production-grade, multi-tenant central data platform on a fresh Oracle Linux 10 host. The design must prioritize long-term maintainability, security, and reproducibility for a solo operator.

**Core Requirements & Constraints:**

1.  **Target Environment:** The deployment target is **Oracle Linux 10**. All commands and package management must be compatible with this OS.
2.  **Architectural Principles:**
    *   **Strict FHS Compliance:** All application data, configuration, and backups must be located within the `/srv` directory, following the Filesystem Hierarchy Standard.
    *   **Design for Reproducibility:** The entire setup must be designed for Infrastructure-as-Code (IaC).
    *   **Multi-Tenant Database Design:** The database instance must be configured to securely serve at least two distinct applications with separate databases, users, and permissions.
3.  **Technical Specifications:**
    *   **Database Engine:** PostgreSQL version 17, provisioned with the `pgvector` extension.
    *   **In-Memory Store:** Redis/Redis-stack:7.2.0-v7, configured for data persistence.
    *   **Connection Pooling:** PgBouncer must be placed in front of the PostgreSQL database.
4.  **Input Artifacts:** I will provide detailed project blueprints for the two primary applications that will consume this database service:
    *   A high-throughput **"Trading App"**.
    *   A read-heavy **"Librarian (RAG) Service"**.
    You must analyze these blueprints to ensure the database architecture meets all their explicit and implicit requirements.

---

## **Part A: Self-Contained Server & Application Setup**

#### **Phase 1: Host Preparation & Directory Structure**
1.  Provide a host setup script for Oracle Linux 10 to install essential tools (Docker, etc.) and apply PostgreSQL-specific kernel tuning.
2.  Propose and create a production-grade, FHS-compliant directory structure under `/srv` that logically separates the central database services from the application codebases.

#### **Phase 2: Central Data Platform Deployment**
1.  Provide the command to create a persistent, shared Docker network for the central services.
2.  Provide the `docker-compose.yml` and all associated configuration files to deploy the **PostgreSQL stack** (`postgres` + `pgbouncer`).
3.  Provide a separate `docker-compose.yml` and configuration files to deploy the **Redis stack**.

#### **Phase 3: Application Configuration & Schema Management**
1.  Request the `docker-compose.yml` and `init.sql` for the "Trading App".
2.  Based on the provided files, generate a modified `docker-compose.yml` for the app that connects it to the central database stack via an external Docker network.
3.  Provide a complete, step-by-step guide to implement Alembic for schema migrations in the "Trading App", addressing the limitations of a static `init.sql` file.

---

## **Part B: OCI Integration, Hardening & Documentation**

### **Phase 4: OCI CLI Setup & Configuration**

**Your Task:**
1.  **Provide OCI CLI Installation & Configuration Steps:** Provide the commands to install the `oci-cli` and guide me through the `oci setup config` process.

### **Phase 5: Cloud Integration & Hardening (OCI CLI/Console)**

**Your Task:** Provide clear, step-by-step instructions (preferring CLI commands) to perform the following actions. Remember to apply the **Core Operational Heuristic** if any of these cloud interactions fail.
1.  **Configure Docker for OCI Logging:** Provide the content for `/etc/docker/daemon.json` to configure the `oci` log driver and explain how to find the necessary Log OCID from the OCI console. Provide the command to restart Docker.
2.  **Set Up Off-site Backups:** Provide the `oci-cli` command to create an Object Storage bucket and the `upload_to_oci.sh` script to push backups to it.
3.  **Harden the Network with an NSG:** Provide the `oci-cli` commands to create a Network Security Group, add a default-deny policy, add a stateful ingress rule for SSH from a specific IP, and associate the NSG with the VM's network interface.
4.  **Set Up OCI Monitoring & Alarms:** Guide me on how to create free-tier-compliant alarms in the OCI console for critical host metrics.

### **Phase 6: Final Documentation Generation**

**Your Task:** Generate a Markdown file named `DATABASE_OPERATIONS_MANUAL.md`. This document must include:
1.  **Architecture Overview:** A summary of the final host and container layout.
2.  **Key Configurations & Justifications:** A summary of critical settings.
3.  **Runbooks:** Clear procedures for Backup & Restore.
4.  **Monitoring Plan:** How to access logs and alarms in OCI.
5.  **Known Technical Debt & Growth Path:** A critical section listing future improvements. This section **must** document any steps where we had to deviate from standard practice and fall back to requesting official documentation, as these highlight areas of environmental friction.

Of course. This is an excellent request. It moves us from setup to sustainable operations. I will provide a set of prompts and guidelines that act as a "Quick Start" for you and future operators.

### **Phase 7: Server Redeployment**

The procedures 1-7 above has eaxecuted and the server has deployed successfully. The deployment process were hard and stressful, mostly because the architecture of linux oracle 10 and drift in oci documentation itself. Some hacks and work around here and there were taken place.
As i just reorganized the OCI cloud, i want to redeploy the currnet running server above: shut down it, and recreate in new compartment. 

To avoid the problems at the previous deployment, i want to replicate the steps in previous process. For that purpose, i will share you with the documentation and necessary files. Ask me for additional files if you think it needed. Ensure if you have capture all necessary settings from current running server. If you see opportunities to improve the process, something that i may missed from previous process, just let me know.
All you have to do is the same as the prompt given to you in phase 1-6. The difference is, instead of creating the procedure yourself, you reiterate the process from the provided documents and improve the process as well as the documentation. Utilize the document as learning lesson toavoid the problems/improve the processs.

I will re-emphasizing the uniqueness of the development that you will meet and should account for carefully:

1.  **Operating System:** Oracle Linux 10 (`aarch64`). This is a relatively new enterprise Linux distribution. Its default configurations, kernel settings, and security modules (like SELinux) can differ from more common development environments like Ubuntu or CentOS.
2.  **Hardware Architecture:** ARM64 (`aarch64`). While increasingly common, it can still have subtle differences in how software, especially low-level system software like container runtimes, is compiled and behaves compared to the more traditional x86_64 architecture.
3.  **Virtualization Platform:** OCI (Oracle Cloud Infrastructure). The underlying hypervisor and the specific storage drivers provided to the VM can influence how filesystem operations, like Docker's bind mounts for secrets, are handled.
4.  **Docker Version and Configuration:** The specific version of the Docker Engine (`docker-ce`) and its storage driver (likely `overlay2`) interact with the OS kernel. The warning `secrets 'uid', 'gid' and 'mode' are not supported` strongly suggests an incompatibility or a configuration issue at this specific intersection of OS, kernel, and Docker Engine, even with a modern Docker Compose version.

### **Additional context**

I just migrated all resources in the cloud from root to a separate compartment. Current compartments (each with its own vnics): 
shared-services: will be hosted compute engine for postgres and redis
RAG-Project: will be hosted serverless function
Root: previously, all of the above compartments consolidated into root. Now, the root contains nothing
The non-root compartments setting is not completed yet. 
Based on above situations, dont assume on any naming/variables/settings related to OCI. 

### **Known problems to be ignored**
You may notice some improvement potencies in legacy code, some of them have listed below:

Fix the Backup Script: The current method using docker exec and redirection is prone to failure. We will use docker compose exec and a volume mount for reliable backups from the start.

Centralize Secret Management: Secrets are scattered (.env files, userlist.txt, individual secret files). We will create a single, secure master secrets file on the new host to source all credentials, improving security and reproducibility.
**Proposed Solution:**
**Location:** the master secrets file will be located at **`/srv/config/platform.env`**.
    *   **Reasoning:** This maintains our core principle of a self-contained, portable, and FHS-compliant application stack under `/srv`. The entire platform's state can be backed up and restored from a single directory tree. This is paramount for the "reproducibility" and "solo operator" constraints.

Document the "Why": The original manual explains the "what". We will add "why" certain choices were made (e.g., the specific PgBouncer image was chosen for ARM compatibility).

Parameterize the Host Setup: The host_setup.sh is good. We will make it more robust by adding checks for success after each step.

Add Healthchecks: We will ensure healthchecks are defined in all docker-compose.yml files for better robustness.

Ignored all of the potencies. The target is make sure the server could be online again. And the easiest and fastest ways are by replicating previous proven work. Once it online again, we will revisit it for any improvements.

### **Current deployment status**

The new compute engine has deployed, updated with the latest version of oracle 10, with the latest snapshot:
[opc@prod ~]$ cat /etc/os-release
NAME="Oracle Linux Server"
VERSION="10.0"
ID="ol"
ID_LIKE="fedora"
VARIANT="Server"
VARIANT_ID="server"
VERSION_ID="10.0"
PLATFORM_ID="platform:el10"
PRETTY_NAME="Oracle Linux Server 10.0"
ANSI_COLOR="0;31"
CPE_NAME="cpe:/o:oracle:linux:10:0:server"
HOME_URL="https://linux.oracle.com/"
BUG_REPORT_URL="https://github.com/oracle/oracle-linux"

ORACLE_BUGZILLA_PRODUCT="Oracle Linux 10"
ORACLE_BUGZILLA_PRODUCT_VERSION=10.0
ORACLE_SUPPORT_PRODUCT="Oracle Linux"
ORACLE_SUPPORT_PRODUCT_VERSION=10.0
[opc@prod ~]$ lscpu | grep '^CPU(s):'
CPU(s):                                  3
[opc@prod ~]$ free -h
               total        used        free      shared  buff/cache   available
Mem:            16Gi       1.0Gi        10Gi        15Mi       5.1Gi        15Gi
Swap:          4.0Gi          0B       4.0Gi
[opc@prod ~]$ sudo firewall-cmd --state
running
[opc@prod ~]$ sudo firewall-cmd --list-all
public (default, active)
  target: default
  ingress-priority: 0
  egress-priority: 0
  icmp-block-inversion: no
  interfaces: enp0s6
  sources:
  services: dhcpv6-client ssh
  ports:
  protocols:
  forward: yes
  masquerade: no
  forward-ports:
  source-ports:
  icmp-blocks:
  rich rules:
[opc@prod ~]$ ss -tuln
Netid              State               Recv-Q              Send-Q                            Local Address:Port                              Peer Address:Port
udp                UNCONN              0                   0                                       0.0.0.0:111                                    0.0.0.0:*
udp                UNCONN              0                   0                                     127.0.0.1:323                                    0.0.0.0:*
udp                UNCONN              0                   0                                          [::]:111                                       [::]:*
udp                UNCONN              0                   0                                         [::1]:323                                       [::]:*
tcp                LISTEN              0                   5                                     127.0.0.1:44321                                  0.0.0.0:*
tcp                LISTEN              0                   4096                                    0.0.0.0:111                                    0.0.0.0:*
tcp                LISTEN              0                   128                                     0.0.0.0:22                                     0.0.0.0:*
tcp                LISTEN              0                   5                                     127.0.0.1:4330                                   0.0.0.0:*
tcp                LISTEN              0                   5                                         [::1]:44321                                     [::]:*
tcp                LISTEN              0                   4096                                       [::]:111                                       [::]:*
tcp                LISTEN              0                   128                                        [::]:22                                        [::]:*
tcp                LISTEN              0                   5                                         [::1]:4330                                      [::]:*
[opc@prod ~]$ sudo tee /etc/sysctl.d/99-postgres.conf > /dev/null <<'EOF'
> # DBRE-1: Tuned settings for a 18GB RAM PostgreSQL server
> kernel.shmmax = 12884901888
> kernel.shmall = 3145728
> vm.swappiness = 1
> vm.overcommit_memory = 2
> vm.overcommit_ratio = 95
> vm.dirty_background_ratio = 2
> vm.dirty_ratio = 3
> net.core.rmem_default = 262144
> net.core.wmem_default = 262144
> net.core.rmem_max = 67108864
> net.core.wmem_max = 67108864
> EOF
[opc@prod ~]$ sudo sysctl --system
* Applying /usr/lib/sysctl.d/01-unprivileged-bpf.conf ...
* Applying /usr/lib/sysctl.d/10-default-yama-scope.conf ...
* Applying /usr/lib/sysctl.d/10-map-count.conf ...
* Applying /usr/lib/sysctl.d/50-coredump.conf ...
* Applying /usr/lib/sysctl.d/50-default.conf ...
* Applying /usr/lib/sysctl.d/50-libkcapi-optmem_max.conf ...
* Applying /usr/lib/sysctl.d/50-pid-max.conf ...
* Applying /usr/lib/sysctl.d/50-redhat.conf ...
* Applying /usr/lib/sysctl.d/50-scsi-logging.conf ...
* Applying /etc/sysctl.d/99-postgres.conf ...
* Applying /etc/sysctl.d/99-sysctl.conf ...
* Applying /etc/sysctl.conf ...
kernel.unprivileged_bpf_disabled = 1
kernel.yama.ptrace_scope = 0
vm.max_map_count = 1048576
kernel.core_pattern = |/usr/lib/systemd/systemd-coredump %P %u %g %s %t %c %h
kernel.core_pipe_limit = 16
fs.suid_dumpable = 2
kernel.sysrq = 16
kernel.core_uses_pid = 1
net.ipv4.conf.default.rp_filter = 2
net.ipv4.conf.docker0.rp_filter = 2
net.ipv4.conf.enp0s6.rp_filter = 2
net.ipv4.conf.lo.rp_filter = 2
net.ipv4.conf.default.accept_source_route = 0
net.ipv4.conf.docker0.accept_source_route = 0
net.ipv4.conf.enp0s6.accept_source_route = 0
net.ipv4.conf.lo.accept_source_route = 0
net.ipv4.conf.default.promote_secondaries = 1
net.ipv4.conf.docker0.promote_secondaries = 1
net.ipv4.conf.enp0s6.promote_secondaries = 1
net.ipv4.conf.lo.promote_secondaries = 1
net.ipv4.ping_group_range = 0 2147483647
net.core.default_qdisc = fq_codel
fs.protected_hardlinks = 1
fs.protected_symlinks = 1
fs.protected_regular = 1
fs.protected_fifos = 1
net.core.optmem_max = 81920
kernel.pid_max = 4194304
kernel.kptr_restrict = 1
net.ipv4.conf.default.rp_filter = 1
net.ipv4.conf.docker0.rp_filter = 1
net.ipv4.conf.enp0s6.rp_filter = 1
net.ipv4.conf.lo.rp_filter = 1
dev.scsi.logging_level = 68
kernel.shmmax = 12884901888
kernel.shmall = 3145728
vm.swappiness = 1
vm.overcommit_memory = 2
vm.overcommit_ratio = 95
vm.dirty_background_ratio = 2
vm.dirty_ratio = 3
net.core.rmem_default = 262144
net.core.wmem_default = 262144
net.core.rmem_max = 67108864
net.core.wmem_max = 67108864

[opc@prod /]$ ls /
afs  bin  boot  dev  etc  home  lib  lib64  media  mnt  opt  proc  root  run  sbin  srv  sys  tmp  usr  var
[opc@prod /]$ cd srv
[opc@prod srv]$ ls -lh
total 0
drwxr-xr-x. 2 root root  6 Sep 18 12:43 apps
drwxr-xr-x. 2 root root  6 Sep 18 12:43 backups
drwxr-xr-x. 5 root root 52 Sep 18 12:43 config
drwxr-xr-x. 4 root root 35 Sep 18 12:43 data
[opc@prod srv]$ ls -a
.  ..  apps  backups  config  data
[opc@prod srv]$ tree
.
├── apps
├── backups
├── config
│   ├── pgbouncer
│   ├── postgres
│   └── redis
└── data
    ├── postgres
    └── redis

10 directories, 0 files

Please guide me to redeploy this. 

---
