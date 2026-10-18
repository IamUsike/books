## establish the scope 
1. what kind of rate limiter? Client side or server side?
2. What param does the rl(use to throttle reqs) and other properties?
3. What is the scale of the system? 
4. Will the system work in distributed environments? 
5. Is rl a seperate service or should it be implemented in application code? 
6. Do we need to inform the users that it is throttled? 

how would different answers to these questions impact the design decisions? 
- where would you implement the rl? Full server side or on the API gateway? 
	- it mainly depends on the existing system stack, and also if using microservices it would be better to implement it on the api gateway?? 

> [!note] claude: yes, and here's how each answer moves the design
> - **client vs server**: client side can't be trusted, so the real limiter is always server side.
> - **throttle param (IP / user / API key)**: decides the key, and whether the limiter must sit *after* auth.
> - **scale**: 1k req/s fits in-memory on one box; 1M req/s means sharded Redis and maybe local counters.
> - **distributed**: if yes, you need shared state (Redis) or accept approximate limits.
> - **separate service vs app code**: gateway if you already have one and the limits are generic; in app code if limits need business logic or you want full control of the algorithm.
> - **inform users**: 429 + headers, so clients can back off.
> - also ask: **hard or soft limit?**, **fail open or closed?**, **how accurate must it be?** (sliding log vs counter), **one region or many?**
> 
> Gateway answer is good for microservices, but say the trade-off: gateways only see request metadata, so limits like "5 money transfers per account per day" still need app-level logic.

## Algorithms 
### Token Bucket 
![511](../img/Pasted%20image%2020261017094845.png)

- bucket size: max no of tokens allowed in the bucket. 
- refill rate: number of tokens put into the bucket every second. 

-> a bucket size will be allocated and then those many tokens can be used (like 1 req consumes one token). and the tokens are refilled at the refill rate. 
-> like if we doing ip throttling. each ip will have its bucket 
-> in prod these buckets are created on demand and refilled also on demand. 
`tokens_refill = (Instant::now() - bucket.last_filled) * refill_rate` 

> [!note] claude: cap the refill
> Without a cap an idle client accumulates unlimited tokens and can then burst forever. The full lazy-refill step is:
> ```
> tokens = min(capacity, tokens + (now - last_filled) * refill_rate)
> last_filled = now
> if tokens >= cost: tokens -= cost; allow
> else: reject (retry after (cost - tokens) / refill_rate)
> ```
> State per key is just two numbers (`tokens`, `last_filled`), which is why it's memory efficient. GCRA (see [[Blogs]]) gets it down to one timestamp.

**pros**
- easy to implement 
- memory efficient 
- allows for burst traffic for short periods 

**cons**
- fine tuning bucket size and token refill rate 

### Leaking Bucket 
![](../img/Pasted%20image%2020261017100625.png)

- bucket size
- outflow rate

**pros**
- memory efficient given the limited queue size ? (even token buckets will be memory efficient given the limited bucket size innit?)
- useful when stable outflow rate is needed. 

**cons**
- burst fills the queue with old reqs and if the processing is slow. 
- fine tune bucket size and outflow rate. 

> [!note] claude: re your memory question
> Yes, token bucket is also memory efficient, even more so. Leaky bucket *as a queue* stores the actual requests (O(queue size) per key) and needs something draining it at a fixed rate. Token bucket stores two numbers. There is also leaky bucket *as a meter* (no queue, just "is the bucket overflowing?"), which is mathematically equivalent to token bucket / GCRA.
> Key difference to say in an interview: token bucket **allows bursts** to pass through; leaky bucket (queue) **smooths bursts** into a constant outflow, at the cost of added latency. Shopify's API uses leaky bucket.

### Fixed Window Counter
- timeline is divided into fixed windows and a counter is assigned to each of those. 
- each req in that window increments the counter. 
- once the reqs reach the threshold no more reqs are processed in that window 

![](../img/Pasted%20image%2020261017102240.png)

- one main problem witrh this is traffic burts at the edge could cause more reqs than the allowed. 

> [!note] claude: edge burst example + pros/cons
> Limit 5/min. 5 reqs at 0:59, 5 reqs at 1:01. Each window sees 5, all allowed, but 10 reqs went through in 2 seconds. Worst case is **2x the limit** in any rolling window.
> **pros**: dead simple (`INCR key; EXPIRE key window` in Redis), O(1) memory per key, resets are easy to explain to users ("quota resets at the top of the minute").
> **cons**: the edge burst above; also a "thundering herd" at window boundaries, since every throttled client retries at the same reset instant.

### Sliding window Log 
this counters the main con of fixed window. 

- keep track of the timestamps. Timestamp data is usually kept in cache, such as sorted sets in redis. 
- when a new req comes in remove all the outdated timestamps(older than the start of the current time window)
- add timestamp of the new req to the log. 
- if the log size is the same or lower than the allowed count, a request is accepted. 
![527](../img/Pasted%20image%2020261017130540.png)

**pros**
- Rate limiting implemented by this is very accurate. In any rolling window, reqs will not exceed the rate limit. 

**cons**
- lots of memory consumption. cos everything is logged even if the request is rejected. 

> [!note] claude
> Logging rejected requests is a choice the book makes, not a requirement. If you log them, a client that keeps spamming stays blocked until it backs off (punishing). If you don't, memory is bounded at `limit` entries per key. Either way it's O(limit) per key vs O(1) for the counters, e.g. 1000 req/hr limit x 1M users x ~20 bytes per sorted set entry is ~20 GB just for timestamps.

### Sliding window counter 
- combines fixed window counter and sliding window log. 

![570](../img/Pasted%20image%2020261017131446.png)

- no of reqs in the rolling window is calculated using the formula 
`reqs in cur window + req in the prev window * overlap percentage of the rolling window and the prev window`

whicch is basically 
```
estimated = prev_count * (1 - fraction_elapsed_in_current_window) + curr_count
allow if estimated < limit
```

> [!note] claude: your formula is correct
> `(1 - fraction_elapsed)` *is* the overlap percentage: if you are 30% into the current window, the rolling window still covers the last 70% of the previous one. Only fix was the `limito` typo. On allow, increment `curr_count`.
>
> **Example**: limit 7 req/min, windows are whole minutes.
> - previous minute (1:00-2:00) had 5 reqs, current minute (2:00-3:00) has 3 so far
> - new req arrives at 2:18, so `fraction_elapsed = 18/60 = 0.3`
> - `estimated = 5 * (1 - 0.3) + 3 = 3.5 + 3 = 6.5`
> - 6.5 < 7, so allow, `curr_count` becomes 4
> - another req at 2:18: `5 * 0.7 + 4 = 7.5`, not < 7, reject
> - at 2:48: `5 * 0.2 + 4 = 5`, allowed again. The previous window's weight decays as time passes.
>
> **pros**
> - smooths out the fixed window edge burst
> - O(1) memory per key: just two counters (Cloudflare runs this at their scale)
> - accurate enough: Cloudflare measured only 0.003% of requests wrongly allowed or limited over 400M requests
>
> **cons**
> - approximation: assumes requests in the previous window were evenly spread. If all 5 came at 1:59, the real rolling count is higher than the estimate.
> - only works for "look-back" windows; not great when you need strict guarantees (billing, hard quotas)

### Algorithm cheat sheet
| algo | memory/key | bursts | accuracy | use when |
|---|---|---|---|---|
| token bucket | 2 numbers | allowed up to bucket size | exact for its model | general API limits (Stripe, AWS) |
| leaky bucket (queue) | queue | smoothed out | exact | need constant outflow to a fragile downstream |
| fixed window | 1 counter | up to 2x at edges | rough | simple quotas, "N per day" |
| sliding log | O(limit) | none | exact | low limits, strict correctness |
| sliding counter | 2 counters | mostly prevented | approximate | high scale, good default |
| GCRA | 1 timestamp | configurable | exact | same as token bucket, less state |

--- 
## HLD 

![800](../Excalidraw/Design%20a%20Rate%20limiter%202026-10-17%2013.36.55.excalidraw.svg)

- the client sends a req to the rl middleware
- rl fetches the ctr from the corresponding bucket in redis  and checks if the limit is reached or not. 
- limit is reached => req is rejected 
- else ctr is incremented and saved back to redis and the req is forwarded to the api servers. 

> [!warning] claude: fetch-check-increment is a race
> "fetch, check, then save back" is a read-modify-write. Two servers can both read 4 (limit 5), both allow, both write 5. Interviewers love asking this. Fix: use an atomic op. `INCR` first and check the *returned* value (`if INCR(key) > limit: reject`), or wrap the whole check in a Lua script. See the race conditions section below.

--- 
## Design Deep Dive 

1. how are the rl rules created? Where are the rules stored?
2. how to handle reqs that are ratelimited. ?

![900](../Excalidraw/Design%20a%20Rate%20limiter%202026-10-17%2017.54.00.excalidraw.svg)

- rules are stored on the disk and are then stored into a centralised cache(s) by the workers for consistency. 
1. client sends the req 
2. req is received by the middleware. 
3. verifies the cached rules against the redis ctr. and then based on the outcome 
the request is either dropped or it is forwarded to the api servers after incrementing the ctr and saving it to redis. 

> [!note] claude: rules
> Rules are usually config files (YAML), versioned in git, pushed to the limiter. Example in Lyft's Envoy ratelimit format:
> ```yaml
> domain: messaging
> descriptors:
>   - key: message_type
>     value: marketing
>     rate_limit:
>       unit: day
>       requests_per_unit: 5
> ```
> Things to think about: hot reload without restarts, what happens on a bad rule push (validate + roll back), per-tier rules (free vs paid), and which key you limit on (user ID, API key, IP, IP + endpoint).

> [!note] claude: handling rate-limited requests (question 2)
> - return **HTTP 429 Too Many Requests**, not 503 (503 means *we* are broken, 429 means *you* are going too fast)
> - send headers so clients can self-pace:
>   - `X-Ratelimit-Limit`: allowed calls per window
>   - `X-Ratelimit-Remaining`: calls left in the window
>   - `Retry-After` (standard) / `X-Ratelimit-Retry-After`: seconds to wait
>   - IETF draft standardizes these as `RateLimit-Policy` and `RateLimit` headers
> - **drop vs queue**: GET-style requests can just be rejected. For important writes (e.g. orders) you can enqueue them and process later instead of dropping.
> - **hard vs soft limit**: hard = never exceed. Soft = may exceed briefly (Stripe's burst allowance), or log/alert only.
> - **dark launch / shadow mode**: log "would have blocked" before enforcing (Stripe does this).

--- 
## RL in a distributed environment 
Main issues when scaling the system to support multiple servers and concurrent threads. 
- race conditions (at a very basic level when incrementing the ctr)
- synchronization issue. 

**Race conditions**
Locks are the most obvious solution for solving race condition. However, locks will significantly slow down the system. Two strategies are commonly used to solve the problem: Lua script [13] and sorted sets data structure in Redis [8]. For readers interested in these strategies, refer to the corresponding reference materials [8] [13] 

> [!note] claude: Lua scripts
> Redis is single-threaded and runs a Lua script atomically: no other command executes in the middle. So you put the whole "read, decide, write" into one script and the race disappears without locks. It's also one network round trip instead of several. Fixed window example:
> ```lua
> -- KEYS[1] = counter key, ARGV[1] = limit, ARGV[2] = window seconds
> local count = redis.call('INCR', KEYS[1])
> if count == 1 then
>   redis.call('EXPIRE', KEYS[1], ARGV[2])
> end
> if count > tonumber(ARGV[1]) then
>   return 0  -- reject
> end
> return 1    -- allow
> ```
> Token bucket and GCRA are done the same way (read state, compute, write state, all in one script). Note: `INCR` then a separate `EXPIRE` from app code is NOT atomic; if the app crashes in between, the key never expires and that user is blocked forever.

> [!note] claude: sorted sets
> Used for sliding window log. Key = user, member = request ID, score = timestamp. Run inside a `MULTI`/`EXEC` transaction (or Lua):
> 1. `ZREMRANGEBYSCORE key 0 (now - window)` drop old entries
> 2. `ZADD key now req_id`
> 3. `ZCARD key` count
> 4. `EXPIRE key window`
>
> Gotcha: `MULTI` makes these run together, but you only see the count *after* adding. So you either always add and check afterwards (rejected requests count too, the book's "punishing" variant) or use Lua to check before adding.

**sync issues**
use a centralised cache like redis :d 
![561](../img/Pasted%20image%2020261017182742.png)

> [!note] claude
> Why sync is a problem at all: if each limiter node keeps counters in local memory, the LB sends user A to node 1 and node 2, and each sees only half the traffic. Options:
> - **sticky sessions**: route a user to the same limiter. Works, but doesn't scale and breaks when a node dies. Not recommended.
> - **centralized store (Redis)**: correct, but every request now pays a network hop, and Redis becomes a hot path and SPOF.
> - **local counters + periodic sync**: each node counts locally and pushes deltas every N ms. Fast, but can over-admit by up to `nodes x sync interval x rate`. Fine for soft limits.

--- 
## Performance Optimization 
- muilti-data center setup
- eventual consistency :d 

> [!note] claude: expand on these
> - **multi-DC / edge**: run limiters close to users (Cloudflare has edge servers worldwide) so latency stays low. Each region keeps its own counters.
> - **eventual consistency**: regions sync counters asynchronously. A user hitting two regions at once can briefly get up to ~2x their limit. Usually acceptable; say so explicitly in the interview.
> - **split the global limit per region**: 1000/min global = 500/min in each of 2 regions. No cross-region traffic at all, but unfair if a user's traffic is all in one region.
> - **Redis Cluster**: shard counters by key (user ID). Use hash tags `{user123}:minute` if a Lua script touches multiple keys, since Lua needs all keys on one shard.
> - **local cache for the rules**: rules change rarely, never fetch them per request.
> - the limiter should add **~1 ms or less** of latency. If Redis is far, that's the first thing to push back on.

---
## Things the book skips (claude)

### Fail open or fail closed?
What happens when Redis is down or slow?
- **fail open** (allow everything): API stays up, but you lose protection right when you might need it. Most public APIs choose this (Stripe built kill switches for the limiters).
- **fail closed** (reject everything): safe for abuse-sensitive endpoints like login / OTP / payments, but Redis becomes a hard dependency of the whole API.
- middle ground: fall back to a coarse **in-memory local limiter** per node.
- always set a tight **timeout** on the Redis call (e.g. 5-10 ms), otherwise a slow Redis slows every request.

### Rate limiting vs load shedding vs throttling vs backpressure
- **rate limiting**: per-client fairness ("you get N/s"). Decision based on the client's own usage.
- **load shedding**: protects the server ("I'm overloaded, drop low-priority work"). Decision based on system state. (see Stripe notes in [[Blogs]])
- **throttling**: often used to mean slowing down (delaying/queueing) instead of rejecting.
- **backpressure**: downstream signals upstream to slow down (TCP windows, bounded queues, gRPC flow control).

### Where can a rate limiter live?
- client side: unreliable (clients can be malicious or modified), but good clients should still self-limit
- L3/L4: `iptables` / firewall per-IP limits, cheap protection against floods
- edge / CDN / WAF: Cloudflare, AWS WAF. Good for DDoS and per-IP limits
- API gateway (Kong, Envoy, AWS API Gateway): per API key / per route. Most common answer
- in app code / middleware: when the limit needs business context (e.g. "5 password resets per account per hour")
- in front of a downstream dependency: protecting *your* DB or a third-party API with its own quota

### What do you limit on? (the key)
- **IP**: easy, but NAT / corporate proxies / mobile carriers put thousands of users behind one IP, and IPv6 gives attackers huge ranges (limit by /64 prefix, not single address). Also `X-Forwarded-For` can be spoofed; only trust it from your own proxies.
- **user ID / API key**: fair, but only works after auth. Unauthenticated endpoints (login) need IP or device fingerprint.
- **endpoint / cost based**: a search query costs more than a GET. Weight requests by cost (GitHub's GraphQL API uses a point budget).
- **combinations**: per user per endpoint, plus a global per-endpoint limit.

### Concurrency limits
Rate limits count requests over time; concurrency limits count requests *in flight*. Needed for slow/expensive endpoints. See the Stripe concurrent requests limiter in [[Blogs]].

### Clock issues
Window and timestamp algos depend on time. With many app servers, use **Redis server time** (`TIME` command inside the Lua script) instead of each app server's clock, so clock skew between servers doesn't matter.

### Monitoring (the book mentions this briefly)
- track allowed vs rejected per rule, per key tier
- too many rejections on legit traffic: rule too strict
- limiter useless during a flash sale: rule too loose, or wrong algorithm (maybe token bucket for bursts)
- alert on limiter latency and Redis errors
- top-N throttled keys tells you who is abusing or who needs a higher tier

### Client best practices
- cache responses so you don't call so often
- read the rate limit headers and slow down before hitting 429
- retry with **exponential backoff + jitter**, honoring `Retry-After`
- catch 429 gracefully, don't crash

---
## Interview prep (claude)

### Rough numbers to have ready
- Redis single node: ~100k ops/s, sub-ms latency in the same DC
- token bucket per key: ~2 numbers + key, call it ~50-100 bytes with Redis overhead. 10M active keys x 100 B ~ 1 GB, fits on one node
- so the bottleneck is usually **ops/s and network hops**, not memory. 1M req/s = ~10+ Redis shards

### Questions you should be able to answer
1. Why not just use a lock around the counter? (latency, contention, lock holder crashing)
2. Walk through the race in "get counter, compare, set counter". How does Lua / `INCR` fix it?
3. Token bucket vs leaky bucket: when would you pick each?
4. Show the fixed window edge problem with numbers. How does sliding window counter fix it, and what does it assume?
5. Redis goes down. What happens to your API? (fail open vs closed)
6. Redis adds latency to every request. How do you reduce that? (local counters, batching, edge)
7. How do you handle multiple data centers? What's the max a user can over-consume?
8. User is behind a corporate NAT with 5000 others. How do you avoid blocking all of them?
9. How does a client know when to retry? (429 + headers + backoff)
10. How do you change limits without a deploy? How do you roll out a new limit safely? (config + shadow mode)
11. How do you rate limit an unauthenticated endpoint like login? (IP + username, captcha after N failures)
12. Different limits for free vs paid tiers: where is that stored and looked up?
13. How would you limit concurrent requests instead of requests/sec?
14. How do you prevent a hot key (one huge customer) from overloading one Redis shard?
15. Rate limiter vs load shedder: what's the difference and do you need both?

### Common follow-ups / curveballs
- "design it as a library vs as a separate service": library = no extra hop, but every service in every language needs it; service = central, but adds a hop and is a new SPOF. Sidecar (Envoy) is the middle ground.
- "what if a request costs differently?": weighted tokens (`cost` param in token bucket / GCRA)
- "can the limiter itself be DDoSed?": yes, so cheap per-IP limits at the edge come first, the expensive per-user Redis check after.
- "how would you test it?": unit test the algo with a fake clock, load test the Redis path, shadow mode in prod.

### Real systems worth name-dropping
- Stripe: token bucket in Redis + load shedders ([[Blogs]])
- Cloudflare: sliding window counter at the edge
- GitHub: 5000 req/hr per user, points-based for GraphQL
- Envoy / Lyft `ratelimit`: gRPC rate limit service backed by Redis, YAML rules
- `redis-cell`: Redis module implementing GCRA in one command (`CL.THROTTLE`)

---
## References
- [8] Better Rate Limiting With Redis Sorted Sets (ClassDojo): https://engineering.classdojo.com/blog/2015/02/06/rolling-rate-limiter/
- [13] Scaling your API with rate limiters (Stripe, includes Redis/Lua code gist): https://stripe.com/blog/rate-limiters
- Redis docs, rate limiter pattern with `INCR`: https://redis.io/docs/latest/commands/incr/#pattern-rate-limiter
- Cloudflare, How we built rate limiting capable of scaling to millions of domains: https://blog.cloudflare.com/counting-things-a-lot-of-different-things/
- Brandur, Rate Limiting, Cells, and GCRA: https://brandur.org/rate-limiting
- Lyft Envoy ratelimit service: https://github.com/envoyproxy/ratelimit
- IETF draft, RateLimit header fields for HTTP: https://datatracker.ietf.org/doc/draft-ietf-httpapi-ratelimit-headers/
- Google SRE book, Handling Overload: https://sre.google/sre-book/handling-overload/
- Alex Xu, System Design Interview Vol 1, ch. 4
