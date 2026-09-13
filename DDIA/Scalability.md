**Scalability**: The term used to describe a system's ability to cope with an increased load. 

Some interesting questions? 
- If a system grows in a particular way, what are our options for coping with the growth? 
- How can we add computing resources to handle the additional load? 
- based on the current growth, when will we hit the limits of our current architecture?

**load**: is often measured in terms of throughput. Can also be measured by ratio of db reads and writes, cache hit rate  etc. 
- this largely depends on the application. 

- If doubling the resources gives twice the performance, this is called *linear scalability*. This is considered a *good thing*. 
- occasionally it is possible to handle twice the load with less than double the resources, because of economies of scale or a better distribution at peak load. 

## Shared Memory, Shared Disk and Shared Nothing Architectures 
- vertical scaling 
- **shared memory architecture**: Parallelism on a single machine by using multiple threads and process. 
	- problem is cost grows faster than linearly. 
	- a highend machine with double the capacity of the current would cost way more. 
	- and cos of bottlenecks, it would likely not be able to handle the load
- **shared disk architecture**: NAS and SAN 
	- used for on premises data warehousing workloads. 
	- contention overhead and overhead of locking limit the scalability. 
- **shared nothing architecture**: distributed system with multiple nodes 
	- easier to scale and more fault tolerant 
	- requires sharding and incurs all complexity of the distrubuted systrems 


![](./img/Pasted%20image%2020260914004047.png)