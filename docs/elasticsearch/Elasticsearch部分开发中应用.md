映射参数代表的意思，[文档](https://www.elastic.co/guide/en/elasticsearch/reference/7.x/mapping-params.html "文档")上都有很清楚的。在这里就不做过多解释。
重点说下注意事项：
1. type为text时，不支持ignore_above属性
2. 一个字段可以指定多个字段属性，最常见搭配是keyword和text
3. date属性的字段要指定存入数据的格式

## mapping的使用

```php
{
  "mappings": {
    "properties": {
      "content":{
        "analyzer": "ik_max_word",
        "type": "text",
        "boost": 2
      },
      "title":{
        "type": "keyword",
        "ignore_above": 20,
        "fields": {
          "raw":{
            "type":"text",
            "analyzer":"ik_max_word"
          }
        }
        },
      "city":{
        "type": "keyword"
      },
      "release":{
        "type": "date",
        "format": "yyyy-MM-dd HH:mm:ss||yyyy-MM-dd||epoch_millis"
      }
      }
    }
}
```

<!--more-->

## 模糊搜索

最常见的是下面两种形式的搜索，单字段和多字段的匹配
```json
{
  "query": {
    "match": {
      "content": {
        "analyzer": "ik_smart",
        "query": "郑州"
      }
    }
  },
  "highlight": {
    "fields": {
      "content": {
        "pre_tags": ["<p color='read'><li>"],
        "post_tags": ["</li></p>"]
      }
    }
  }
}
```
```json
{
  "query": {
    "multi_match": {
      "query": "商丘市新冠肺炎",
      "fields": ["title", "content"],
      "analyzer": "ik_smart"
    }
  }
}
```
## 文档相似度计算

```json
{
  "took" : 3,
  "timed_out" : false,
  "_shards" : {
    "total" : 1,
    "successful" : 1,
    "skipped" : 0,
    "failed" : 0
  },
  "hits" : {
    "total" : {
      "value" : 4,
      "relation" : "eq"
    },
    "max_score" : 2.2596006,
    "hits" : [
      {
        "_index" : "news",
        "_type" : "_doc",
        "_id" : "nWAu53sB2FUxEjonthYP",
        "_score" : 2.2596006,
        "_source" : {
          "content" : "商丘市迅速加强新冠肺炎的管控力度，并进行全员核酸检测",
          "title" : "商丘市新冠防控",
          "city" : "商丘市",
          "release" : "2021-09-14 18:20:12"
        }
      },
      {
        "_index" : "news",
        "_type" : "_doc",
        "_id" : "L2Aq53sB2FUxEjonRxbv",
        "_score" : 1.8536104,
        "_source" : {
          "content" : "商丘市发现了，新冠肺炎确诊患者，密接者游某和郑某，并发布了两人的行程流调",
          "title" : "商丘市新冠肺炎",
          "city" : "商丘市",
          "release" : "2021-09-15"
        }
      },
      {
        "_index" : "news",
        "_type" : "_doc",
        "_id" : "t2Al53sB2FUxEjonWRWE",
        "_score" : 0.63216305,
        "_source" : {
          "content" : "福建省莆田市发生了新冠肺炎传播，防控形势很严峻，大家要保护好自己",
          "title" : "莆田市新冠肺炎",
          "city" : "莆田市",
          "release" : "2021-09-14 11:13:14"
        }
      },
      {
        "_index" : "news",
        "_type" : "_doc",
        "_id" : "ZWAs53sB2FUxEjondRbm",
        "_score" : 0.62111557,
        "_source" : {
          "content" : "郑州市，各个小区陆续加强了，新冠肺炎的防控力度，进小区开始要健康码了",
          "title" : "郑州市新冠防控",
          "city" : "郑州市",
          "release" : "2021-09-14 18:20:12"
        }
      }
    ]
  }
}
```
es检索出的文档都会有个max_score 的概念，文档的匹配的顺序是按照这个分数来倒序排的。即分数越大，匹配度越大，我们可以借助这个特性和php计算相识度（similar_text ）的函数来快速的是计算出文档的相似度。

## 筛选条件权重修改

检索结果文档的排序，是按照es的内部算法计算出的分数来排序的。我们如果想干预计算的分数怎么办，这个是可以实现的。一种是在筛选条件上加，boost属性，另外一种是使用分数计算函数（function_score ）来干预。示列如下：
```json
{
  "query": {
    "bool": {
      "should": [
        {
          "term": {
            "city": {
              "value": "商丘市",
              "boost": 2
            }
          }
        },
        {
          "term": {
            "city": {
              "value": "郑州市",
              "boost": 1
            }
          }
        }
      ]
    }
  }
}
```
以上筛选，商丘市会排在上面，如果boost的值都相等，增郑州会排在上面。
```json
{
  "query": {
    "function_score": {
      "query": {
        "term": {
          "city": {
            "value": "商丘市"
          }
        }
      }, 
      "functions": [
        {
          "filter": {
            "match":{
              "content":"郑某"
            }
          },
          "weight": 30
        },
        {
          "filter": {
            "match":{
              "content":"管控力度"
            }
          },
          "weight": 50
        }
      ]
    }
  }
}
```
