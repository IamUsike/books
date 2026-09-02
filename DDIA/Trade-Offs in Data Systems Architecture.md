
## Types of applications 
- **Data intensive**: We worry about storing and processing of data, managing changes, ensuring consistency and concurrency. 
- **Compute intensive**

Many Applications need to do the following:
- Store data, so that they can find it later (db)
- Remember the results of expensive ops to make reads quicker(cache)
- Allow users to search by a keyword and filters (search indexes)
- Handle events and data changes as soon as they occue (Stream Processing)
- Periodically crunch a large amount of data (batch processing)

> No Approach is fundamentally better than others; Everything has pros and cons. 

-> One of the key challenges with data is that dift people need to do dift things with the data

## Operational Vs Analytical Systems 
Generally 3 kinds of people in the org would need access to data
- Backend engineers 
- Business Analysts 
- data scientists 

Business analysts and data scientists generally do not modify the data. Altho they might create data that is derived from the origial data. 

- **Operational Systems**: Consists of backend services and data infra where data is created. Eg: By serving other users. 
- **Analytical Systems**: Serve the needs of business analysts and data scientists. They contain a read only copy and are optimized for the types of data processing that are needed for analytics. 
### Characterizing Transaction Processing and Analytics 
Transaction: A group of reads and writes that form a logical unit.  

- **Online Transaction Processing(OLTP)**: An operational system typically looks up a small no. of records by a key. Records CRUD based on user's input. 
- **Online Analytical Processing(OLAP)**: Aggergate over a large no of data. 

### Data Warehousing 
*Data warehouse* is a seperate db that that is used to run analytical queries. 

- A large OLTP system might have multiple db's for multiple services + not a good idea to run analytical custom queries on prod db. So a seperate db was created ie: *data warehouse*.
- Data warehouse Untitledcontains a readonly copy of data from various OLTP systems transformed into an analyst friendly schema.  
- This process of getting data is known an *extract transform lead* (ETL)

**Data lake**: Contains files without imposing any particular file format, model or schema. 
	- analysts need data for *feature engineering* or *nlp* which requires data to be in certain format that requries custom code, which is harder in sql. (data warehouse are relational) 

### Systems of Record and Derived Data 
**Systems of Record**: 
- holds the authoritative or canonical version of data 
- each fact is repped exactly once 
- when a new data comes in, it is first written here(not always true)
**Derived data systems**: 
- eg cache 

--- 
## Cloud vs Self Hosting 
![[Pasted image 20260902154406.png]]

- if you have exp settins os and load is predictable it's often cheaper to setup your own machines and infra 
- if you need a system that you dont already know how to deploy and operate, adopting a cloud service is often quicker and easier to operate. 
### Cloud native System Arcchitecture 
The term *cloud native* is used to describe an architecture that is designed to take advantage of cloud services. 

- in principle, almost any sfw that is self hosted can also be hosted on the cloud. 
- Systems that have been designed from ground up to be cloud native have shown better performance of the same hardware, quicker scalability, fault tolearnce, recovery etc.

The key idea, of cloud native services is not to only use the resources managed by your OS, but also to build upon your lower-level cloud services to create higher leverl services.
#### Seperation of storage and compute 
- traditional computing; to tolerate failiures *RAID*(Redundant Array of Independent Disks)
- VMs might also have local disks attached but generally these are treated as ephemeral caches cos local disk becomes inaccesible if the instance fails or if the instance is replaced with a bigger or smaller one to adapt to the load 
- as An alternative, cloud services offer virtual disks, that are detached from one instance and attached to a dift one. (EBS)
- the use of virtual disks are sensitive to network glitches since every I/O is basically a network call. 

- to address this issue, cloud native services generally avoid usign virtual disks and instead build on dedicated storage devices that are built for dedicated work loads. 
- Eg: s3 for long term storage. 

> Capacity planning becomes financial planning and performance optimizations become cost optimisations. 

--- 
## Distributed vs Single Node Systems 
**Distributed System**: A system that involves several machines communicating via a network. 

use case reasons might be 
- Inherent Distribution 
- Requests Between cloud services
- fault tolerance/high availability 
- scalability 
- latency (edge servers )
- elasticity 
- specialized hardware 
- legal compliance 

### Problems with Distributed Systems 
- Every req that travels the network needs to deal with  the possibility of failiure. 
- Operating with large vols of data: rather that bringing it to a machine to process that data, it is beneficial to process in the system that the data is in. 
- troubleshooting is hard. (multiple nodes )
- Need to maintain consistecy accross different services (if they have their own db)
