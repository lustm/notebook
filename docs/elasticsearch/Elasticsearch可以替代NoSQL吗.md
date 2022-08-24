   &nbsp;&nbsp; 首先，ES从发布第一个版本到现在只有短短几年时间，在很多方面还不成熟，开发的主力也只是一个很小规模的创业公司（[Elastic · Revealing Insights from Data (Formerly Elasticsearch)](https://link.zhihu.com/?target=https%3A//www.elastic.co/)）。而NoSQL是一个很宽泛的概念，无论是学术界还是工业界都已经讨论了很多年，也有很多成熟的产品（包括MongoDB），背后有诸多大公司及无数开发者。使用哪种产品作为[数据仓库](https://www.zhihu.com/search?q=数据仓库&search_source=Entity&hybrid_search_source=Entity&hybrid_search_extra={"sourceType"%3A"answer"%2C"sourceId"%3A55132709})完全取决于具体的应用场景，如果信息获取及分析的能力是你的首要需求，那么无疑ES是一个好的选择。但是即使是将来，ES也无法完全替代NoSQL的其他产品，因为ES在设计上为了优化搜索性能，是做出了其他很多方面的牺牲的。

> 1. 硬件资源
&nbsp;&nbsp;&nbsp;ES是基于Lucene开发的，它的许多局限从根本上都是由Lucene引入的。例如，为了提高性能，Lucene会将同一个term重复地index到各种不同的数据结构中，以支持不同目的的搜索，基于你选用的分析器，最终index数倍于原本的数据大小是有可能的。内存方面，ES的排序和聚合（Aggregation）操作会把几乎所有相关不相关的文档都加载到内存中，一个Query就可以很神奇地吃光所有内存，现在新的Lucene版本优化了基于硬盘的排序，但也仅当你使用SSD的情况下，才不会牺牲过多的搜索性能。其他的问题还包括，大量的增量写操作会导致大量的后台Merge，CPU和硬盘读写都会很容易达到瓶颈。ES确实在横向Scale方面做的很出色，但前提是有足够的预算买硬件。

> 2. 实时性
&nbsp;&nbsp;&nbsp;就在不久前，ES把官网主页上的Near Real-Time Search改成了Real-Time Search，或许是为了更好地宣传，但这不能改变其Near的本质。有多Near呢？默认的设置是1秒，也就是说文档从Index请求到对外可见能够被搜到，最少要1秒钟，强制的，你的网络和CPU再快也不行。这么做是Lucene为了提高写操作的吞吐量而做出的延迟牺牲，当然这个设置是可以手动调整的，但是并不建议你去动它，会极大地影响搜索性能。不同的应用对[实时性](https://www.zhihu.com/search?q=实时性&search_source=Entity&hybrid_search_source=Entity&hybrid_search_extra={"sourceType"%3A"answer"%2C"sourceId"%3A55132709})的定义并不一样，这取决于你的需求。

> 3. 可靠性
&nbsp;&nbsp;&nbsp;当数据量达到一定规模之后，你将面临许多在开发阶段无法被暴露出来的问题。例如，在ES的GitHub主页上有30多个Open Issue都是关于Out of Memory的，当然前期充分的压力测试某种程度上可以缓解这个问题，但也可能无限期地推迟产品上线的时间。

> 4. 安全性
&nbsp;&nbsp;&nbsp;这个是ES公司为了挣钱故意的，他们将安全相关的功能单独做成了一个叫做Shield的收费插件，如果你的老板是土豪或者不关心安全那就没有任何问题了，否则，聪明能干的你就需要加班了，不是不能解决，就是麻烦点，能有多安全就不好说了。

可不可以将ES作为主要的或唯一的数据仓库？如果对可靠性的要求不高，答案是可以的。然而，更推荐的做法（也是ES对自己的定位）是将其建立在其他独立的（优化过可靠性一致性正确性的）数据库之上，专门做它擅长的数据分析，处理，以便获取。说到最后又回到预算的问题上了，取决于这个项目的搂钱能力值不值得为了可靠性付出额外的费用，老板没钱的话，那就加班咯，聪明能干的你总能找到解决办法的。以上是我所了解的ES现阶段存在的问题，希望能有帮助。