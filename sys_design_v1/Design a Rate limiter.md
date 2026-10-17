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

## Algorithms 
### Token Bucket 
![511](../img/Pasted%20image%2020261017094845.png)

- bucket size: max no of tokens allowed in the bucket. 
- refill rate: number of tokens put into the bucket every second. 

-> a bucket size will be allocated and then those many tokens can be used (like 1 req consumes one token). and the tokens are refilled at the refill rate. 
-> like if we doing ip throttling. each ip will have its bucket 
-> in prod these buckets are created on demand and refilled also on demand. 
`tokens_refill = (Instant::now() - bucket.last_filled) * refill_rate` 

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

### Fixed Window Counter
- timeline is divided into fixed windows and a counter is assigned to each of those. 
- each req in that window increments the counter. 
- once the reqs reach the threshold no more reqs are processed in that window 

![](../img/Pasted%20image%2020261017102240.png)

- one main problem witrh this is traffic burts at the edge could cause more reqs than the allowed. 

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

### Sliding window counter 
- combines fixed window counter and sliding window log. 

![570](../img/Pasted%20image%2020261017131446.png)

- no of reqs in the rolling window is calculated using the formula 
`reqs in cur window + req in the prev window * overlap percentage of the rolling window and the prev window`

//claude plis correct the above formula and add an example for my understanding 
//and also add pros and cons 

--- 
## HLD 

![800](../Excalidraw/Design%20a%20Rate%20limiter%202026-10-17%2013.36.55.excalidraw.svg)

- the client sends a req to the rl middleware
- rl fetches the ctr from the corresponding bucket in redis  and checks if the limit is reached or not. 
- limit is reached => req is rejected 
- else ctr is incremented and saved back to redis and the req is forwarded to the api servers. 

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

--- 
## RL in a distributed environment 
Main issues when scaling the system to support multiple servers and concurrent threads. 
- race conditions (at a very basic level when incrementing the ctr)
- synchronization issue. 

**Race conditions**
Locks are the most obvious solution for solving race condition. However, locks will significantly slow down the system. Two strategies are commonly used to solve the problem: Lua script [13] and sorted sets data structure in Redis [8]. For readers interested in these strategies, refer to the corresponding reference materials [8] [13] (claude add a short note on these and then refernce materials/papers at the end)

**sync issues**
use a centralised cache like redis :d 
![561](../img/Pasted%20image%2020261017182742.png)

--- 
## Performance Optimization 
- muilti-data center setup
- eventual consistency :d 
