## Scaling api with rl 
[stripe](https://stripe.com/blog/rate-limiters)
- **load shedding**: in case any service is not behaving as efficiently, some low priority reqs can be dropped. 
- a load shedder makes its decisions based on the entire state of the systems. 

when to use a rate limiter? 
	- if the users can afford to change the pace at which they hit the api endpoints without affecting the outcome of their requests. 

Stripe operates **4 types** of rl in prod. 
1. **request rate limiter** 
- limit users to max N reqs per sec. 
- after analyzing traffic, they added the ability to briefly burst abov ethe cap for sudden spikes in usage during real time events. 

2. **Concurrent Requests Limiter**
- Instead of “You can use our API 1000 times a second”, this rate limiter says “You can only have 20 API requests in progress at the same time”.
- useful for compute intensive endpoints. 

hmm how would i go on about implementing this? 
1. store the reqs in queues(bounded) and then allow reqs only  when the queue isnt full. 
2. ye i think that is the most optimal solution i can think of but then that would require us to create a queue for every user no? any other solutions? 

> [!note] claude: no queue needed, just count what's in flight
> A concurrency limit is a semaphore per user. You don't hold the requests, you only count them.
> - request starts: `INCR inflight:{user}`. If result > 20, `DECR` and return 429.
> - request finishes (success OR error): `DECR inflight:{user}`
>
> Problem: if a server crashes mid-request the `DECR` never runs and the counter leaks; the user is slowly locked out. Fix (what Stripe does): use a **sorted set** instead. Member = request ID, score = start timestamp. On each new request, first `ZREMRANGEBYSCORE` entries older than the request timeout (they're dead), then `ZCARD` to count, then `ZADD` if under the limit. Remove your own ID on completion. Stale entries clean themselves up. All of it in one Lua script so it's atomic.
>
> A queue per user is what you'd do if you wanted to *wait* instead of reject (leaky bucket style). That's valid too, but costs memory and adds latency.

![Blog > Rate limiters > Graph 2](https://images.stripeassets.com/fzn2n1nzq965/6n0cFumdlNxMYdkfdz0JRu/24c589e3516573fb72068d8d35a7f3ef/image.png?w=1620&q=80)

3. **fleet usage load shedder**
- reserve a particular percentage of compute only for critical endpoints say 20%. 
and if any non critical endpoints ka reqs consume more than 80% cpu. they are capped. 

again this implementation mein we would still need to combine this with other rl ig. cos even the split traffic should be further spaced right?? 

> [!note] claude: yes, they're layered
> Small correction: Stripe's 20% is reserved *fleet capacity* (workers/servers), not CPU specifically. And yes, you still need the per-user limiters. They solve different problems:
> - **request rate + concurrency limiters**: fairness *between users*. One user can't hog the API.
> - **fleet usage load shedder**: protects *critical traffic* from non-critical traffic as a whole. Even if every user is under their own limit, the sum can still overload you.
>
> A request passes through all of them in order. Stripe says the request rate limiter is by far the one that triggers most often; the load shedders are a safety net.
![Blog > Rate limiters > Graph 3](https://images.stripeassets.com/fzn2n1nzq965/70nvphdGeNMKHRsoJIsFFq/889af231f8ec95f95b640baaa629b455/image.png?w=1620&q=80)

4. **worker utilization load shredder**
Most API services use a set of workers to independently respond to incoming requests in a parallel fashion. This load shedder is the final line of defense. If your workers start getting backed up with requests, then this will shed lower-priority traffic.

This one gets triggered very rarely, only during major incidents.

We divide our traffic into 4 categories:
- Critical methods
- POSTs
- GETs
- Test mode traffic

If a box is too busy to handle reqs, it slowly starts shredding less critical reqs starting from test traffic. 

![Blog > Rate limiters > Graph 4](https://images.stripeassets.com/fzn2n1nzq965/5dU2JWBEVCh1kXHlKWakqw/3413cd572b53d2af0ae432dcc90e9585/image.png?w=1620&q=80)

### Building rl in practice
- they use token bucket algo and redis. 

Imp things to consider when implementing rls 
- hook the rl  to your middleware stack safely 
-  show clear exceptions to users
- build safeguards so that you can turn off the limiters. 
- Dark launch each rate limiter to watch the traffic they would block

--- 
## Rate Limiting, Cells, and GCRA 
[brandur](https://brandur.org/rate-limiting#footnote-1)

**Time bucketed**
- normal token buckets

some more cons
- faulty script can block the user for an entire amount of time. 
- malicious actors can keep sending bursts and the system would have to maintain it in memory. 

**leaky bucket**
normal normal 

cons: if any worker goes down or fails to drain the buckets at a not sufficient enough rate. It be a pain. 

**GCRA** - Generic Cell Rate Algorithm 

- works by tracking remaining limit through ao time called the *theoretical arrival time(TAT)* 
- this is seeded on the first req by adding a duration repping its cost to the current time. 

### The idea

Imagine each client has a **schedule**: a timestamp saying “the earliest time this client would be at rest if requests were spaced perfectly evenly”. Each request pushes that timestamp forward. If the timestamp gets too far ahead of the current time, the client is going too fast and gets rejected. The only state is that one timestamp.

### The terms

|Symbol|Name|Meaning|How to calculate|
|---|---|---|---|
|**GCRA**|Generic Cell Rate Algorithm|The algorithm itself. “Cell” is from ATM networking, where data was sent in fixed-size cells. For us, a cell = a request.||
|**T**|Emission interval|The ideal gap between requests|`period / limit`. For 10 req/s, T = 1s/10 = 100ms|
|**B**|Burst size|How many requests may arrive back to back from idle|You choose it, e.g. 5|
|**τ** (tau)|Burst tolerance|How far ahead of schedule the client may run|`(B - 1) × T`. For B = 5, τ = 400ms|
|**TAT**|Theoretical Arrival Time|The stored timestamp, when the next request would arrive if the client were perfectly paced|Updated on each allowed request (below)|
|**now**|Current time||From a single clock source|

### The algorithm

On each request at time `now`:

```
TAT = max(TAT, now)            # if the client was idle, the schedule resets to now
if now < TAT - τ:              # too far ahead of schedule
    reject  (retry after TAT - τ - now)
else:
    TAT = TAT + T              # (T × cost, for weighted requests)
    allow
```

The `max` handles idle clients. If the client waited past its TAT, the bucket is empty again and the full burst is available.

### Worked example

T = 100ms, B = 5, so τ = 400ms. A new client sends 6 requests at t = 0, then more later. Times in ms, TAT starts at 0.

|Request|now|TAT - τ|Allowed?|New TAT|
|---|---|---|---|---|
|1|0|-400|yes|100|
|2|0|-300|yes|200|
|3|0|-200|yes|300|
|4|0|-100|yes|400|
|5|0|0|yes (0 < 0 is false)|500|
|6|0|100|**no** (0 < 100)|500|
|7|100|100|yes|600|

Five requests pass instantly, which is the burst. The sixth is rejected with retry-after = 100 - 0 = 100ms. At t = 100 one request fits again, then one every 100ms, which is the steady rate of 10/s.



--- 
Some more
1. **Cloudflare, “Counting things, a lot of different things”**: [https://blog.cloudflare.com/counting-things-a-lot-of-different-things/](https://blog.cloudflare.com/counting-things-a-lot-of-different-things/)  
    The sliding window counter approximation and why it works at scale.
2. **Google SRE Book, “Handling Overload”**: [https://sre.google/sre-book/handling-overload/](https://sre.google/sre-book/handling-overload/)  
    Puts rate limiting in the wider context of overload and load shedding.
















































