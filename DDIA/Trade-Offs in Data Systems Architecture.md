
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

- A large OLTP system might have multiple db's for multiple services + not a good idea to run analytical custom queries on prod db. So a seperate db was created 