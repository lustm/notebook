## 前言

前面的案例使用standard、english分词器，是英文原生的分词器，对中文分词支持不太好。中文作为全球最优美、最复杂的语言，目前中文分词器较多，ik-analyzer、结巴中文分词、THULAC、NLPIR和阿里的aliws都是非常优秀的，我们以ik-analyzer作为讲解的重点，其它分词器可以举一反三。

## 概要

本篇主要介绍中文分词器ik-analyzer的安装使用、自定义词库以及热更新方案。

## 分词器插件安装

我们Elasticsearch 6.3.1版本为例，集成IK分词器，其他的分词器过程也类似，在ES的bin目录下执行插件安装命令即可：

`./elasticsearch-plugin install https://github.com/medcl/elasticsearch-analysis-ik/releases/download/v6.3.1/elasticsearch-analysis-ik-6.3.1.zip`

其中install后面的那个的地址是 [elasticsearch-analysis-ik](medcl/elasticsearch-analysis-ik) 的github release对应ES版本的下载地址。

插件的版本最好与Elasticsearch版本保持一致，如果Elasticsearch为别的版本，下载对应版本的ik-analyzer插件即可。

安装成功后，ES启动日志就能看到如下信息：

`[2019-11-27T12:17:15,255][INFO ][o.e.p.PluginsService] [node-1] loaded plugin [analysis-ik]`



## 基础知识

IK分词器包含两种analyzer，一般用ik_max_word

ik_max_word：会将文本做最细粒度的拆分

ik_smart：会做最粗粒度的拆分

测试分词效果

```json
// ik_max_word分词测试
GET /_analyze
{
	"text": "您好祖国",
	"analyzer": "ik_smart"
}

// 响应如下：
{
	"tokens": [ 
		{
            "token": "您好",
            "start_offset": 0,
            "end_offset": 2,
            "type": "CN_WORD",
            "position": 0
		},
        {
            "token": "祖国",
            "start_offset": 2,
            "end_offset": 4,
            "type": "CN_WORD",
            "position": 1
        }
	]
}
```

```json
// ik_max_word分词测试
GET /_analyze
{
    "text": "我和我的祖国",
    "analyzer": "ik_max_word"
}

// 响应如下：
{
    "tokens": [
        {
            "token": "我",
            "start_offset": 0,
            "end_offset": 1,
            "type": "CN_CHAR",
            "position": 0
        },
        {
            "token": "和我",
            "start_offset": 1,
            "end_offset": 3,
            "type": "CN_WORD",
            "position": 1
        },
        {
            "token": "的",
            "start_offset": 3,
            "end_offset": 4,
            "type": "CN_CHAR",
            "position": 2
        },
        {
            "token": "祖国",
            "start_offset": 4,
            "end_offset": 6,
            "type": "CN_WORD",
            "position": 3
        }
    ]
}

```

## 配置文件

ik插件安装完成后，可以在`elasticsearch-6.3.1/config/analysis-ik`看到ik的配置文件IKAnalyzer.cfg.xml

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE properties SYSTEM "http://java.sun.com/dtd/properties.dtd">

<properties>
    <comment>IK Analyzer 扩展配置</comment>
    <!--用户可以在这里配置自己的扩展字典 -->
    <entry key="ext_dict"></entry>
    <!--用户可以在这里配置自己的扩展停止词字典-->
    <entry key="ext_stopwords"></entry>
    <!--用户可以在这里配置远程扩展字典 -->
    <!-- <entry key="remote_ext_dict">words_location</entry> -->
    <!--用户可以在这里配置远程扩展停止词字典-->
    <!-- <entry key="remote_ext_stopwords">words_location</entry> -->
</properties>
```

该目录下带有许多文件，含义如下：

- main.dic ik 原生内置的中文词库，里面有275909条现成的词语

- quantifier.dic 量词和单位名称，如个，斤，克，米之类的

- suffix.dic 常见后缀词，如江，村，省，市，局等

- surname.dic 中国姓氏

- stopword.dic 停用词，目前默认的是写的几个英文单词，如and, a, the等

- preposition.dic 副词、语气助词，连接词等无实际含义的词语，如却，也，是，否则之类的

6.3.1版本的IK分词器还提供了额外的词库补充文件，extra开头的那几个就是，如extra_main.dic，共收录398716条现有的词语，默认没有使用，有需要可以在配置文件IKAnalyzer.cfg.xml上添加，其他类似。

最重要的是main.dic和stopword.dic。stopword(停用词)，分词时会直接被干掉，不会建立在倒排索引中。

## 自定义词库

1）创建自定义词库文件mydic.dic，并在IKAnalyzer.cfg.xml的ext_dict属性里加上该文件名，可以在mydic.dic文件里补充自己的词汇，如网络流行词：跪族篮孩。

添加前的分词效果：

```json
GET /forum/_analyze
{
    "text": "跪族篮孩",
    "analyzer": "ik_max_word"
}

响应结果：
{
    "tokens": [
        {
            "token": "跪",
            "start_offset": 0,
            "end_offset": 1,
            "type": "CN_WORD",
            "position": 0
        },
        {
            "token": "族",
            "start_offset": 1,
            "end_offset": 2,
            "type": "CN_CHAR",
            "position": 1
        },
        {
            "token": "篮",
            "start_offset": 2,
            "end_offset": 3,
            "type": "CN_WORD",
            "position": 2
        },
        {
            "token": "孩",
            "start_offset": 3,
            "end_offset": 4,
            "type": "CN_CHAR",
            "position": 3
        }
    ]
}
```

添加词库后：

```json
{
    "tokens": [
        {
            "token": "跪族篮孩",
            "start_offset": 0,
            "end_offset": 4,
            "type": "CN_WORD",
            "position": 0
        },
        {
            "token": "跪",
            "start_offset": 0,
            "end_offset": 1,
            "type": "CN_WORD",
            "position": 1
        },
        {
            "token": "族",
            "start_offset": 1,
            "end_offset": 2,
            "type": "CN_CHAR",
            "position": 2
        },
        {
            "token": "篮",
            "start_offset": 2,
            "end_offset": 3,
            "type": "CN_WORD",
            "position": 3
        },
        {
            "token": "孩",
            "start_offset": 3,
            "end_offset": 4,
            "type": "CN_CHAR",
            "position": 4
        }
    ]
}
```

能看到完整的“跪族篮孩”，能看到完整的语词出现。

2）自己建立停用词库，如了，的，哈，啥，这几个字不想去建立索引

在配置文件IKAnalyzer.cfg.xml下ext_stopwords标签添加：extra_stopword.dic，并加几个词，修改后同样要重启es。

例：加一个"啥"字在ext_stopword中

修改前：

```json
GET /forum/_analyze
{
    "text": "啥都好",
    "analyzer": "ik_max_word"
}

响应结果：
{
    "tokens": [
        {
            "token": "啥",
            "start_offset": 0,
            "end_offset": 1,
            "type": "CN_WORD",
            "position": 0
        },
        {
            "token": "都好",
            "start_offset": 1,
            "end_offset": 3,
            "type": "CN_WORD",
            "position": 1
        }
    ]
}
```

添加停用词后:

```json
{
    "tokens": [
        {
            "token": "都好",
            "start_offset": 1,
            "end_offset": 3,
            "type": "CN_WORD",
            "position": 0
        }
    ]
}
```

那个啥字直接没有了，结果符合预期。

## 热更新方案

上面自定义词库有一个致命问题：必须要重启ES，新增的词库才能生效。

研发、测试环境自己玩玩无所谓，多半是自己使用，节点又少，重启就重启，关系不大。但想想生产环境能随便让你重启吗？动辄几百个ES实例，重启的事就别想了，另外找办法。

由此引出现在的热更新需求，让ES不停机能立即加载新增的词库。

热更新的方案

1. 基于id分词器原生支持的更新方案，部署一个web服务器，提供一个http接口，通过modified和try两个http响应头，来提供词语的热更新操作。

2. 修改ik分词器源码，然后手动支持从mysql中每隔一定时间，自动加载新的词库。

推荐方案二，方案一虽是官方提供的，但操作起来比较麻烦，还需要部署http服务器。



方案步骤:

1）下载源码

git clone medcl/elasticsearch-analysis-ik

git checkout tags/v6.3.1

该工程是Maven项目工程，将代码导入IDEA或Eclipse。

2）修改点

`org.wltea.analyzer.dic.Dictionary`

主要思路是在这个类的initial()方法内增加一个入口，反复去调用reLoadMainDict()方法，此方法如下：

```java
public void reLoadMainDict() {
    logger.info("重新加载词典...");
    // 新开一个实例加载词典，减少加载过程对当前词典使用的影响
    Dictionary tmpDict = new Dictionary(configuration);
    tmpDict.configuration = getSingleton().configuration;
    tmpDict.loadMainDict();
    tmpDict.loadStopWordDict();
    _MainDict = tmpDict._MainDict;
    _StopWords = tmpDict._StopWords;
    logger.info("重新加载词典完毕...");
}
```

这个方法就是重新加载词库的，然后修改loadMainDict()和loadStopWordDict()方法，在这两个方法最后加上读取数据库获取最新的数据记录的逻辑即可。数据库的表结构自己定义两张表，满足数据库表设计规范即可。

3）IDE上mvn package打包

可以直接用target/releases/目录下的elasticsearch-analysis-ik-6.3.1.zip

4）解压zip包，加上jdbc的配置，该修改的修改，重启ES，看日志

5）在数据库里加几个字段，在线尝试是否生效。



##### 方案延伸

该方案使用数据库轮询的方法，简单有效，但比较浪费资源，毕竟生产上修改词库的动作是按需求发生的，可以考虑由定时轮询改成MQ消息通知，这样就可以做到按需更新，而不用浪费太多的资源做词典更新。

## 小结

本篇对中文分词器IK作了简单的讲解，市面上流行的中文分词器很多，如果我们遇到有中文分词的需求，货比三家是永远不过时的道理，调研可能要花费一些时间，但能挑到适合自己项目的分词器，还是划算的。
