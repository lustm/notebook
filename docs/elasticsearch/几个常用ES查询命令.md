## 查看ES版本

> curl -XGET -u "username:password" -H "Content-Type: application/json" ip:port
## 查看索引列表

> curl -XGET -u "username:password" -H "Content-Type: application/json" ip:port/_cat/indices
## 查看settings配置

> curl -XGET -u "username:password" -H "Content-Type: application/json" ip:port/index_name/_settings
## 查看mapping结构

> curl -XGET -u "username:password" -H "Content-Type: application/json" ip:port/index_name
## 查询索引数据 _source代表查询的字段

> curl -XGET -u "username:password" -H "Content-Type: application/json" ip:port/index_name/_search -d
```json
'{
    "query":{
        "bool":{
            "should":[
                {
                    "term":{
                        "employee_ldap":{
                            "value":"guilhermepacheco1"
                        }
                    }
                }
            ]
        }
    },
    "from":0,
    "size":20,
    "_source":[
        "_id",
        "data_source",
        "mdata_create_time",
        "employee_ldap",
        "hr_status",
        "employee_name",
        "employee_ldap"
    ]
}'
```
## 清空索引里的所有数据

> curl -XPOST -u "username:password" -H "Content-Type:application/json" ip:port/index_name/_delete_by_query -d 
```json
'{
    "query":{
        "match_all":{
        }
    }
}'
```
## 删除索引

> curl -XDELETE ip:port/index_name