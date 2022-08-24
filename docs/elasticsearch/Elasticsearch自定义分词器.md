# 1 索引的分析

索引分析: 就是把输入的文本块按照一定的策略进行分解, 并建立倒排索引的过程. 在Lucene的架构中, 这个过程由分析器(analyzer)完成.

## 1.1 分词器的组成

① 字符过滤器(character filter): 比如去除HTML标签、把`&`替换为`and`等.

② 分词器(tokenizer): 按照某种规律, 如根据空格、逗号等, 将文本块进行分解.

③ 标记过滤器(token filter): 所有被分词器分解的词都将经过token filters的处理, 它可以修改词(如小写化处理)、去掉词(根据某一规则去掉无意义的词, 如"a", "the", "的"等), 增加词(如同义词"jump"、"leap"等).

> 注意: 人们一般将分析器通称为分词器, 并不是相等的关系, 而是包含的关系.

<!-- more -->

## 1.2 倒排索引的核心原理-normalization

建立倒排索引时, 会执行`normalization`(正常化)操作 —— 将拆分的各个单词进行处理, 以提高搜索时命中关联的文档的概率.

**normalization的方式有: 时态转换, 单复数转换, 同义词转换, 大小写转换等.**

> 比如文档中包含`His mom likes small dogs`:
> ① 在建立索引的时候normalization会对文档进行时态、单复数、同义词等方面的处理;
> ② 然后用户通过近似的`mother liked little dog`, 也能搜索到相关的文档.

# 2 ES的默认分词器

(1) ES中的默认分词器: standard tokenizer, 是标准分词器, 它以单词为边界进行分词. 具有如下功能:

> ① standard token filter: 去掉无意义的标签, 如<>, &, - 等.
> ② lowercase token filter: 将所有字母转换为小写字母.
> ③ stop token filer(默认被禁用): 移除停用词, 比如"a"、"the"等.

(2) 测试默认分词器:

```json
GET _analyze			// ES引擎中已有standard分词器, 所以可以不指定index
{
    "analyzer": "standard", 
    "text": "There-is & a DOG<br/> in house"
}
```

可以发现, Elasticsearch对text文本进行了分析处理, 结果如下:

```json
{
  "tokens" : [
    {
      "token" : "there",      // 分词
      "start_offset" : 0,     // 起始偏移量
      "end_offset" : 5,       // 结束偏移量
      "type" : "<ALPHANUM>",  // 分词的类型
      "position" : 0          // 该分词在文本中的位置
    },
    {
      "token" : "is",
      "start_offset" : 6,
      "end_offset" : 8,
      "type" : "<ALPHANUM>",
      "position" : 1
    },
    {
      "token" : "a",
      "start_offset" : 11,
      "end_offset" : 12,
      "type" : "<ALPHANUM>",
      "position" : 2
    },
    // 省略其他4项
  ]
}
```

# 3 修改分词器

(1) 创建索引后可以添加新的分词器:

> 说明: **必须先关闭索引, 添加完成后, 再及时打开索引进行搜索等操作, 否则将出现错误.**

```json
// 关闭索引:
POST address/_close

// 启用English停用词token filter
PUT address/_settings
{
    "analysis": {
        "analyzer": {
            "my_token_filter": {        // 自定义的分词器名称
                "type": "standard",
                "stopwords": "_english_"
            }
        }
    }
}

// 打开索引:
POST address/_open
```

(2) 使用具有停词功能的分词器进行分词:

```json
GET address/_analyze      // 指定索引
{
    "analyzer": "my_token_filter",   // 指定要使用的分词器
    "text": "There-is & a DOG<br/> in house"
}
```

(3) 返回结果减少了停用词`there`, `is`, `&`, `a`, `in`等:

```json
{
  "tokens" : [
    {
      "token" : "dog",
      "start_offset" : 13,
      "end_offset" : 16,
      "type" : "<ALPHANUM>",
      "position" : 3
    },
    {
      "token" : "br",
      "start_offset" : 17,
      "end_offset" : 19,
      "type" : "<ALPHANUM>",
      "position" : 4
    },
    {
      "token" : "house",
      "start_offset" : 25,
      "end_offset" : 30,
      "type" : "<ALPHANUM>",
      "position" : 6
    }
  ]
}
```

# 4 定制分词器

## 4.1 向索引中添加自定义的分词器

> 同样的, 在添加新的分词器之前, 必须先关闭索引, 添加完成后, 再打开索引进行搜索等操作.

```json
PUT address/_settings
{
    "analysis": {
        "char_filter": {
            "&_to_and": {
                "type": "mapping",
                "mappings": ["& => and"]
            }
        },
        "filter": {
            "my_stopwords": {
                "type": "stop",
                "stopwords": ["the", "a"]
            }
        },
        "analyzer": {
            "my_analyzer": {    // 自定义的分析器名称
                "type": "custom",
                "char_filter": ["html_strip", "&_to_and"], // 跳过HTML标签, 将&符号转换为"and"
                "tokenizer": "standard",
                "filter": ["lowercase", "my_stopwords"]    // 转换为小写
            }
        }
    }
}
```

## 4.2 测试自定义分析器

```json
GET address/_analyze
{
    "analyzer": "my_analyzer",   // 上面定义的分析器名称
    "text": "There-is & a DOG<br/> in house"
}
```

可以发现, 返回的分析结果中已经对大写单词、HTML标签, 以及"&"做了处理.

```json
{
  "tokens" : [
    // there和is
    {
      "token" : "and",      // &被处理成了and
      "start_offset" : 9,
      "end_offset" : 10,
      "type" : "<ALPHANUM>",
      "position" : 2
    },
    // dog、in和house
  ]
}
```

## 4.3 向映射中添加自定义的分词器

```json
PUT address/_mapping/province
{
    "properties": {
        "content": {
            "type": "text",
            "analyzer": "my_analyzer"
        }
    }
}
```

此时查看mapping信息:

```json
GET address/_mapping
```

发现自定义的分析器已经配置到province上了:

```json
{
  "address": {
    "mappings": {
      "province": {
        "properties": {
          "area" : {
            "type" : "float"
          },
          "content" : {
            "type" : "text",
            "analyzer" : "my_analyzer"
          },
          "name" : {
            "type" : "text"
          }
        }
      }
    }
  }
}
```

## 4.4 常见自定义分词器

使用逗号分词进行查询，类似MySQL的FIND_IN_SET()函数

```json
{
  "analysis": {
    "analyzer": {
      "comma": {
        "type": "pattern",
        "pattern": ","
      }
    }
  }
}
```



# 5 常见问题

在修改索引之前, 没有关闭索引, 修改时发生如下错误:

```json
{
  "error": {
    "root_cause": [
      {
        "type": "illegal_argument_exception",
        "reason": "Can't update non dynamic settings [[index.analysis.analyzer.my_token_filter.type, index.analysis.analyzer.my_token_filter.stopwords]] for open indices [[address/Ci6MJV4sTyuoF4r9aLvVZg]]"
      }
    ],
    "type": "illegal_argument_exception",
    "reason": "Can't update non dynamic settings [[index.analysis.analyzer.my_token_filter.type, index.analysis.analyzer.my_token_filter.stopwords]] for open indices [[address/Ci6MJV4sTyuoF4r9aLvVZg]]"
  },
  "status": 400
}
```

查看本篇第[3]节的说明, 先关闭索引再执行修改操作.
