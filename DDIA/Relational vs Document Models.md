- *declarative languages*

**Relational model** - data is organized into relations, where each relation is an unordered collection of tuples. 
**Document Model** - json shi (mongodb)

-> NoSQL systems  scale better ?
**Where the myth comes from**
NoSQL systems (Cassandra, DynamoDB, MongoDB) were designed with horizontal scaling as a first-class goal. They gave up some things to get it: joins, multi-row transactions, flexible ad-hoc queries. SQL databases like Postgres and MySQL were designed around a single powerful node with strong guarantees, so scaling out was bolted on later and felt painful.

**What actually differs**
- **Horizontal write scaling:** NoSQL stores that are partitioned by key (Cassandra, DynamoDB) make this the default. You pick a partition key, data spreads across nodes, and throughput grows roughly linearly. With SQL you have to shard manually or use something like Vitess or Citus.
- **Read scaling:** both do it well. Read replicas and caching work for either.
- **Query flexibility:** SQL wins. NoSQL scales well _because_ it restricts you to access patterns you designed up front. Need a query you didn't plan for, and you're in trouble.
- **Consistency:** many NoSQL systems default to eventual consistency, which is part of how they scale. SQL gives you ACID by default, and that coordination is what costs you at scale.

**The part people miss**
- A single well-tuned Postgres node handles far more than most people assume: tens of thousands of transactions per second and terabytes of data. Most applications never outgrow it.
- NewSQL systems (CockroachDB, Spanner, TiDB, YugabyteDB) give you SQL and ACID with horizontal scaling, which blurs the line entirely.
- Big companies run huge SQL deployments (Instagram on sharded Postgres, Shopify on sharded MySQL).
- NoSQL doesn't scale automatically either. A bad partition key creates hot partitions and you hit a wall just as with SQL.

**Rule of thumb**
Pick based on your access patterns and consistency needs, not scale in the abstract. If you have relational data and varied queries, start with SQL. If you have a massive, predictable key-value or time-series workload with high write volume, NoSQL fits well. Scale is rarely the deciding factor until you're well past the point where most systems ever get.

*^why?* 

--- 
## Object Relational Mismatch 
- in OOP need a translation layer between db and the language - *impedance mismatch*
- **ORM** -> look into N+1 queries 

### one to many relationships 
![433](Pasted%20image%2020261004130551.png)


- document model provides better locality. 
- how would the queries look in these models to fetch a user profile?

--- 
## Normalization, Denormalizaion and Joins 
- Normalization reduces inconsistencies(we store references to a central obj)
- downside is that we need to perform additional lookups for each query. 

- Document models can store both normalized and denormalized but the latter is preferred patly cos: 
	- weak support for joins (in monogodb possible to perform joins using *aggregate pipelines*)
	- easy to store denormalized data. 

#### Trade-offs of normalization 
- updating is easier in normalization 

as a general principle 
> Normalized data is faster to write but slower to query. Denormalized is ulta (fewer joins and to update anything we need to find and update all the records containing that element ) 

what about when both reads and updates need to be fast? 

- **data warehouses**: snowflake schema, dimensional modelling. 
some more stuff, not very interesting, 

### When to use which model ?
- document model provides schema flexibility (schema on read). 
- document model provides data locality for reads and writes. 
- query languages for documents and convergence of doc and relational dbs. 



































---
## Answers to Inline Questions
- **Why is scale rarely the deciding factor?** Most apps never exceed what one Postgres node (plus replicas and a cache) can handle. Data shape and query patterns hurt you much earlier than raw scale does.
- **Fetching a user profile**: relational needs several queries or a multi-way join (users + positions + education + contact info). Document model: one read of one document, stored together on disk (locality).
- **N+1 queries**: ORM loads N parent rows with 1 query, then runs 1 query per row for children. Fix with eager loading / a JOIN / batching (`WHERE id IN (...)`).
- **Both reads and writes fast?** Keep the normalized data as system of record and build denormalized derived views from it: materialized views, caches, search indexes, read models via CDC or events (CQRS). Writes stay simple; reads hit the precomputed shape.

## Interview Notes
- **Relationship shape decides the model**: one-to-many tree = document fits; many-to-one / many-to-many = relational (or graph) fits. Data tends to become more interconnected over time.
- **Schema-on-read vs schema-on-write** is like dynamic vs static typing. "Schemaless" still has an implicit schema; your app code enforces it.
- Document locality only helps if you usually need the *whole* document. Large documents that get partially updated are rewritten in full.
- Convergence: Postgres has `JSONB` with indexes; MongoDB has `$lookup` joins and multi-document transactions.
- DB choice checklist for interviews: access patterns, consistency needs, relationship shape, read/write ratio, data size and growth, team familiarity.

## Questions to Ponder
- A LinkedIn profile references a company by ID vs. storing the company name as text. What breaks with each?
- When would you put a `JSONB` column inside a relational table instead of using a separate document DB?
- How do you migrate a schema in a document DB with millions of old-format documents?

## Further Reading
- *A Relational Model of Data for Large Shared Data Banks* — E.F. Codd, 1970
- *What Goes Around Comes Around* — Stonebraker & Hellerstein, 2005, and *...And Around* — Stonebraker & Pavlo, 2024 (history of data models; every "new" model gets reinvented)
- *Dynamo: Amazon's Highly Available Key-value Store* — SOSP 2007
- *Bigtable: A Distributed Storage System for Structured Data* — OSDI 2006
