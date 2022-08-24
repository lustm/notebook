## 关于横向扩容

```json
PUT /test_index
{
   "settings" : {
      "number_of_shards" : 3,
      "number_of_replicas" : 1
   }
}
```

- primary&replica自动负载均衡，6个shard，3 primary，3 replica
- 每个node有更少的shard，IO/CPU/Memory资源给每个shard分配更多，每个shard性能更好
- 扩容的极限，6个shard（3 primary，3 replica），最多扩容到6台机器，每个shard可以占用单台服务器的所有资源，性能最好
- 超出扩容极限，动态修改replica数量，9个shard（3primary，6 replica），扩容到9台机器，比3台机器时，拥有3倍的读吞吐量
- 3台机器下，9个shard（3 primary，6 replica），资源更少，但是容错性更好，最多容纳2台机器宕机，6个shard只能容纳1台机器宕机

<font color=Red>在3台机器下，6个shard的只能容纳1台机器宕机容错性分析：</font>

![IMG](https://raw.githubusercontent.com/lustm/IMG/main/images/616011-20190109112734231-1661512252.png)

## 关于Master节点

- master节点不会承载所有的请求，所以不会是一个单点瓶颈

- master节点管理es集群的元数据：比如说索引的创建和删除，维护索引的元数据，节点的增加和移除，维护集群的元数据

- 默认情况下，会自动选择出一台节点，作为master节点

<font color=Red>容错性分析: </font>

![IMG](https://raw.githubusercontent.com/lustm/IMG/main/images/616011-20190109114535438-1911620532.png)

## 关于纵向扩容

扩容方案：重新购置两台性能更加强大，替换原先旧的2台服务器，但是，服务器的性能越强，成本将会是成倍增加，此方案不推荐，一般用横向扩容。

