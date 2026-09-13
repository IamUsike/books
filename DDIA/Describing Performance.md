- **Response Time**: The elapsed time from which a user makes a req and receives a response. 
- **Throughput**: The no. of req/s or vol of data/s that the system is processing. 

![](img/Pasted%20image%2020260906154851.png)
**M/M/1 queue:** a simple model with one server, random (Poisson) arrivals at rate λ, and random (exponential) service times at rate μ. Average time in system: **W = 1/(μ − λ)**.
where μ : service rate and 
	  λ : arrival rate 

Think of a single queue with:
- λ = arrival rate (requests/sec coming in)
- μ = service rate (requests/sec the system can process)
- ρ = λ/μ = utilization (how "full" the system is, 0 to 1)

As throughput (λ) approaches the server's max capacity (μ), the denominator shrinks toward zero, so W shoots up toward infinity — that's the vertical asymptote in the graph above. It's a hyperbola, not a saturating curve, because nothing caps how long the queue can grow; response time only stays bounded if λ stays comfortably below μ.

## When an overloaded system wont recover 

**metastable failure**: a feedback loop where system's own recovery behavior makes the overload worse instead of better. 

The chain of causality: 
1. **System approaches capacity**: Throughput is rear the limit -> queues start forming -> requests wait longer to get processed 
2. **Response times balloon**: every request sitting in it adds latency to everything behind it. Once you're near saturation, small increases in load cause disproportionately large increases in queueing delay (this is a property of queueing theory in general, not specific to this book — utilization near 100% causes latency to blow up nonlinearly).
3. **clients start timing out**: they give up on waiting and assume that the req failed and *retry*
4. **retries add more load**: cos there's duplicates too 
5. **this pushes response times further**: causing more timeouts and more retries => *retry storm*. The feedback loop is self re-inforcing, each cycle adds more load than the last. 

The nasty part is the "metastable" property: once you're in this state, just fixing the original trigger (say, traffic spikes back down to normal) **isn't enough**. The system doesn't automatically fall back into its healthy state, because there's now a large backlog of retried/duplicated requests still circulating that keep utilization pinned near the overload threshold. It behaves like it's stuck in a second stable equilibrium — hence "metastable." Often the only way out is a hard reset: restart the service, drop the queue, or otherwise forcibly clear the backlog rather than waiting for it to drain.

The mitigations listed (exponential backoff, circuit breakers, load shedding, backpressure, token buckets) all attack different points in that loop:

- **Exponential backoff + jitter** — spaces out retries so they don't all pile on at once
- **Circuit breakers** — stop even _trying_ to send requests to a service that's clearly already failing, cutting off the retry supply entirely
- **Load shedding / backpressure** — let the server itself refuse or push back on excess work before it degrades, rather than accepting everything and drowning
- **Token bucket** — caps the rate of requests admitted in the first place

## latency and response time 
![](./img/Pasted%20image%2020260913175812.png)

**head of line blocking**: it only takes a small no. of slow reqs to hold up the processing of subsequesnt reqs 

## Average, Median and Percentiles 
- because response times vary per req, we need to think of it as a distribution of values. 
- variation in network delay is known as *jitter*
- avg times sensitive to *outliers*
- *median/percentiles* are often better as they tell us what percentage of reqs come under a certain threshold 