```json
{
    "query": {
        "bool": {
            "must": [
                {"term": {"color": "red"}}
            ],
            # 当must存在的时候，should中的条件是可有可无的，就是must条件满足就行，should的一个都不用满足也可以
            # 当must不存在的时候，should中的条件至少要满足一个
            "should": {
                {"term": {"size": 33}},
                {"term": {"size": 55}}
            },
            # 所以当must存在，又想让should的条件至少满足一个地加这个参数
            # 也可以再must>term统计再加一个bool>must>should
            "minimum_should_match":1
        }
    }
}
```

