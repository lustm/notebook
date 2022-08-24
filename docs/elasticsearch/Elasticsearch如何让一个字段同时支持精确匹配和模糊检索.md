需求：如何让ES的某个字段既能支持精确匹配查找，也能支持模糊检索？
方法：将字段的mapping设置为如下这种即可：

```json
{
    "properties":{
        "name":{
            "type":"text",
            "fields":{
                "keyword":{
                    "type":"keyword",
                    "ignore_above":256
                }
            }
        }
    }
}
```
<!-- more -->

解释：
ElasticSearch 5.0以后，string字段被拆分成两种新的数据类型:
Text：会分词，然后根据分词后的内容建立倒排索引（反向索引）
不支持聚合
keyword：不进行分词，直接直接根据字符串内容建立倒排索引（反向索引）
支持聚合

ElasticSearch字符串将默认被同时映射成text和keyword类型，将会自动创建上面的动态映射(dynamic mappings)，比如上面的name字段，不做任何配置ES就会默认给他映射成两个类型。

但是如果要对text类型做其他配置，比如加入中文分词器，该如何做呢？若你是使用Spring-data-Elasticsearch，那么有两种办法可以实现这个需求：

一、对改字段使用@MultiField注释

```java
@MultiField(mainField = @Field(type = FieldType.Text, analyzer = "ik_max_word", searchAnalyzer = "ik_smart"), otherFields = {
            @InnerField(type = FieldType.Keyword, suffix = "keyword") })
```

Spring-data-elasticsearch的API文档见：https://docs.spring.io/spring-data/elasticsearch/docs/3.1.5.RELEASE/api/

二、使用@Mapping注解为Document自定义生成mapping

```java
@Document(indexName = "student", type = "student")
@Mapping(mappingPath = "elasticSearch_mapping.json")
public class Student {
	@Id
	private String id;
	private String name;
}
```

在resource目录下，新建elasticSearch_mapping.json。内容如下：

```json
{
    "student":{
        "properties":{
            "id":{
                "type":"keyword"
            },
            "name":{
                "type":"text",
                "analyzer":"ik_max_word",
                "search_analyzer":"ik_smart",
                "fields":{
                    "keyword":{
                        "type":"keyword",
                        "ignore_above":256
                    }
                }
            }
        }
    }
}
```

删除原有的mapping后再次运行程序，新生成的mapping就是json文件中定义的配置，这种方式自由度较高，但对mapping的掌握要求也较高。
