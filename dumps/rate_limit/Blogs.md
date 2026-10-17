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

![Blog > Rate limiters > Graph 2](https://images.stripeassets.com/fzn2n1nzq965/6n0cFumdlNxMYdkfdz0JRu/24c589e3516573fb72068d8d35a7f3ef/image.png?w=1620&q=80)

3. **fleet usage load shedder**
- reserve a particular percentage of compute only for critical endpoints say 20%. 
and if any non critical endpoints ka reqs consume more than 80% cpu. they are capped. 

again this implementation mein we would still need to combine this with other rl ig. cos even the split traffic should be further spaced right?? 
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

