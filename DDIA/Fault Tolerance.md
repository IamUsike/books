**Fault**: Occurs when a particular part of a system stops working correctly. 
**Failure**: is when the entire system stops providing the required service to the user. 

- we can a system fault tolerant if it continues providing the required service to the users in spite of certain faults occurring. 
- If  a system cannot tolerate a single part becoming faulty, we call it *single point of failure*(SPOF)

- fault tolerance is always limited to a certain no. of faults. 

**fault injection**: Deliberately injecting faults to test the fault tolerance. 

## Hardware and Software Faults 
- theres a certain percentage of HDDs, SSDs. RAM etc failing or the data in them getting corrupted. 

At a very large scale, hardware faults happen often enough that they become part of a normal system operation. 

### Tolerating faults through Redundancy 
- the first response to unreliable software is redundancy. Maybe disks can be setup in a RAID config. 
- Redundancy is most effective when faults are *independent*

### Software faults 
- altho hw faults can be weakly correlated, they are still mostly independent. 
- sw faults are often very highly correlated.
#### 1. A bug triggered by a shared input

If a particular malformed request, edge-case value, or specific date crashes one server, it will crash _every_ server running the same code when it receives that same input — because they all process requests from the same stream.

- Classic example: **leap second bugs**. In 2012, a Linux kernel bug interacting with NTP leap-second handling caused many servers across many companies (including Reddit, Mozilla, Qantas) to simultaneously spin at 100% CPU or hang — all at once, because they all hit midnight UTC at the same moment.

#### 2. Resource exhaustion from a shared trigger

- The famous **AWS S3 outage in 2017** was caused by an operator typo during routine maintenance that took down more capacity than intended, cascading through dependent subsystems — a single human/software trigger that rippled across a huge number of "independent" servers because they all depended on the same underlying service.

#### 3. Bugs that only manifest under specific timing/load conditions

- A **memory leak** that only becomes visible after N hours of uptime or M requests processed. If all your servers were deployed at roughly the same time (common in a rolling deploy) and receive similar traffic, they'll all hit the threshold and start failing within a similar window — not staggered like independent hardware failures would be.

#### 4. Cascading failures through shared dependencies

- If a **shared library, database, or downstream microservice** has a bug or degrades, every service that calls it is affected simultaneously — even though those calling services are running on totally separate, "redundant" hardware.
- Example: a bug in a widely-used TLS library (like the **Heartbleed** vulnerability in OpenSSL) affected virtually every server using that library at once, regardless of how many redundant machines an organization had.

#### 5. Runaway processes triggered by retries/cascades

- This connects back to what we discussed earlier: a **retry storm** is itself a correlated software fault — it's not that each server independently decided to misbehave, it's that the same client-side retry logic, deployed everywhere, reacts identically to the same triggering condition (timeouts), so all clients hammer the service at once.

#### 6. Bad configuration or deployment rollouts

- A **bad config push or software deploy** rolled out to all nodes simultaneously (a "config as code" mistake, a bad feature flag, a broken canary that wasn't caught) breaks every instance running that config at the same time — since they're all identical copies of the same artifact.
- Example: **CrowdStrike's 2024 outage** — a single faulty content update pushed to all Windows endpoints running their software caused mass simultaneous crashes (BSODs) worldwide, unrelated to any hardware diversity.

> these bugs lie dormant for a long time until certain circumstances are triggered. *It is then revealed that the sw is making some kind of assumption about the environment*. 

things that can help: 
- thinking about the assumptions and interactions between the systems
- thorough testing 
- ensuring process isolation 
- allowing processes to crash and restart. 