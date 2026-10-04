Let's assume we creating smth like X. 
- users make 500M posts per day  (5.8k posts per sec).
- ocassionally, it spikes to 150k posts per sec.
- avg user follows 200  people and has 200 followers 

Just read the book. 

refs 
---
## Interview Notes
Classic "design Twitter home timeline" question. Core trade-off: do work at write time or at read time.
- **Fan-out on read (pull)**: store posts once; on timeline load, query everyone you follow and merge. Cheap writes, expensive reads.
- **Fan-out on write (push)**: on each post, insert it into every follower's timeline cache. Expensive writes, cheap reads. Timelines are a *materialized view*.
- **Math**: 5.8k posts/s × 200 followers ≈ 1.2M timeline writes/s on average. During the 150k posts/s spike, that is ≈ 30M writes/s. Reads (timeline loads) far outnumber posts, which is why push still wins for most users.
- **Celebrity problem**: one post from an account with 100M followers = 100M writes. Fix: **hybrid**. Push for normal users; pull celebrity posts at read time and merge them in.
- Follower counts are heavily skewed (power law), so "average 200" hides the hard cases. Always ask about the distribution, not only the mean.
- Store post IDs in the timeline cache (e.g. Redis lists, capped to ~800 entries), not full posts. Fetch post bodies separately, so edits and deletes don't require rewriting millions of timelines.
- Skip fan-out to inactive users. Rebuild their timeline on demand when they return.

## Questions to Ponder
- How do you handle a deleted post or an unfollow under fan-out on write?
- Where do you put the push/pull threshold, and should it be static?
- What happens to timeline delivery during the 150k posts/s spike? (Queue the fan-out work. The timeline being a few seconds stale is acceptable.)

## Further Reading
- *Timelines at Scale* — Raffi Krikorian, QCon 2012 (Twitter's actual design)
- *TAO: Facebook's Distributed Data Store for the Social Graph* — USENIX ATC 2013
- *Feeding Frenzy: Selectively Materializing Users' Event Feeds* — Silberstein et al., SIGMOD 2010 (when to push vs pull, formally)
