## 概述

  在生产业务常有将 [MySQL](https://cloud.tencent.com/product/cdb?from=10680) 数据同步到 ES 的需求，如果需要很高的定制化，往往需要开发同步程序用于处理数据。但没有特殊业务需求，官方提供的Logstash 就很有优势了。  在使用 Logstash 我们应先了解其特性，再决定是否使用：

- 无需开发，仅需安装配置 Logstash 即可；
- 凡是 SQL 可以实现的 Logstash 均可以实现（本就是通过 sql 查询数据）
- 支持每次全量同步或按照特定字段（如递增ID、修改时间）增量同步；
- 同步频率可控，最快同步频率每分钟一次（如果对实效性要求较高，慎用）；
- 不支持被物理删除的数据同步物理删除ES中的数据（可在表设计中增加逻辑删除字段 IsDelete 标识数据删除）。

# 安装

  前往官网下载 Logstash，下载地址https://www.elastic.co/downloads/logstash，zip压缩包大约160M（如果下载速度太慢可以选用这个代理地址下载：http://mirror.azk8s.cn/elastic/logstash/）；

  程序目录：

- 【windows】G:\ELK\logstash-6.5.4；               
- 【linux】/tomcat/logstash/logstash-6.5.4。 下文统一以【程序目录】表示不同环境的安装目录。

<!-- more -->

# 配置

## 新建目录存放配置文件及mysql依赖包

  在【程序目录】目录（\bin同级）新建mysql目录，将下载好的mysql-connector-java-5.1.34.jar放入此目录；  在【程序目录】\mysql目录新建jdbc.conf文件，此文件将配置[数据库](https://cloud.tencent.com/solution/database?from=10680)连接信息、查询数据sql、分页信息、同步频率等核心信息。  注意事项请查看注释信息。

## 单表同步配置 

```javascript
input {
	stdin {}
	jdbc {
		type => "jdbc"
		 # 数据库连接地址
		jdbc_connection_string => "jdbc:mysql://192.168.1.1:3306/TestDB?characterEncoding=UTF-8&autoReconnect=true""
		 # 数据库连接账号密码；
		jdbc_user => "username"
		jdbc_password => "pwd"
		 # MySQL依赖包路径；
		jdbc_driver_library => "mysql/mysql-connector-java-5.1.34.jar"
		 # the name of the driver class for mysql
		jdbc_driver_class => "com.mysql.jdbc.Driver"
		 # 数据库重连尝试次数
		connection_retry_attempts => "3"
		 # 判断数据库连接是否可用，默认false不开启
		jdbc_validate_connection => "true"
		 # 数据库连接可用校验超时时间，默认3600S
		jdbc_validation_timeout => "3600"
		 # 开启分页查询（默认false不开启）；
		jdbc_paging_enabled => "true"
		 # 单次分页查询条数（默认100000,若字段较多且更新频率较高，建议调低此值）；
		jdbc_page_size => "500"
		 # statement为查询数据sql，如果sql较复杂，建议配通过statement_filepath配置sql文件的存放路径；
		 # sql_last_value为内置的变量，存放上次查询结果中最后一条数据tracking_column的值，此处即为ModifyTime；
		 # statement_filepath => "mysql/jdbc.sql"
		statement => "SELECT KeyId,TradeTime,OrderUserName,ModifyTime FROM `DetailTab` WHERE ModifyTime>= :sql_last_value order by ModifyTime asc"
		 # 是否将字段名转换为小写，默认true（如果有数据序列化、反序列化需求，建议改为false）；
		lowercase_column_names => false
		 # Value can be any of: fatal,error,warn,info,debug，默认info；
		sql_log_level => warn
		 #
		 # 是否记录上次执行结果，true表示会将上次执行结果的tracking_column字段的值保存到last_run_metadata_path指定的文件中；
		record_last_run => true
		 # 需要记录查询结果某字段的值时，此字段为true，否则默认tracking_column为timestamp的值；
		use_column_value => true
		 # 需要记录的字段，用于增量同步，需是数据库字段
		tracking_column => "ModifyTime"
		 # Value can be any of: numeric,timestamp，Default value is "numeric"
		tracking_column_type => timestamp
		 # record_last_run上次数据存放位置；
		last_run_metadata_path => "mysql/last_id.txt"
		 # 是否清除last_run_metadata_path的记录，需要增量同步时此字段必须为false；
		clean_run => false
		 #
		 # 同步频率(分 时 天 月 年)，默认每分钟同步一次；
		schedule => "* * * * *"
	}
}

filter {
	json {
		source => "message"
		remove_field => ["message"]
	}
	# convert 字段类型转换，将字段TotalMoney数据类型改为float；
	mutate {
		convert => {
			"TotalMoney" => "float"
		}
	}
}
output {
	elasticsearch {
		 # host => "192.168.1.1"
		 # port => "9200"
		 # 配置ES集群地址
		hosts => ["192.168.1.1:9200", "192.168.1.2:9200", "192.168.1.3:9200"]
		 # 索引名字，必须小写
		index => "consumption"
		 # 数据唯一索引（建议使用数据库KeyID）
		document_id => "%{KeyId}"
	}
	stdout {
		codec => json_lines
	}
}
```

## 多表同步 

  多表配置和单表配置的区别在于input模块的jdbc模块有几个type，output模块就需对应有几个type；

```javascript
input {
	stdin {}
	jdbc {
		 # 多表同步时，表类型区分，建议命名为“库名_表名”，每个jdbc模块需对应一个type；
		type => "TestDB_DetailTab"
		
		 # 其他配置此处省略，参考单表配置
		 # ...
		 # ...
		 # record_last_run上次数据存放位置；
		last_run_metadata_path => "mysql\last_id.txt"
		 # 是否清除last_run_metadata_path的记录，需要增量同步时此字段必须为false；
		clean_run => false
		 #
		 # 同步频率(分 时 天 月 年)，默认每分钟同步一次；
		schedule => "* * * * *"
	}
	jdbc {
		 # 多表同步时，表类型区分，建议命名为“库名_表名”，每个jdbc模块需对应一个type；
		type => "TestDB_Tab2"
		# 多表同步时，last_run_metadata_path配置的路径应不一致，避免有影响；
		 # 其他配置此处省略
		 # ...
		 # ...
	}
}

filter {
	json {
		source => "message"
		remove_field => ["message"]
	}
}

output {
	# output模块的type需和jdbc模块的type一致
	if [type] == "TestDB_DetailTab" {
		elasticsearch {
			 # host => "192.168.1.1"
			 # port => "9200"
			 # 配置ES集群地址
			hosts => ["192.168.1.1:9200", "192.168.1.2:9200", "192.168.1.3:9200"]
			 # 索引名字，必须小写
			index => "detailtab1"
			 # 数据唯一索引（建议使用数据库KeyID）
			document_id => "%{KeyId}"
		}
	}
	if [type] == "TestDB_Tab2" {
		elasticsearch {
			# host => "192.168.1.1"
			# port => "9200"
			# 配置ES集群地址
			hosts => ["192.168.1.1:9200", "192.168.1.2:9200", "192.168.1.3:9200"]
			# 索引名字，必须小写
			index => "detailtab2"
			# 数据唯一索引（建议使用数据库KeyID）
			document_id => "%{KeyId}"
		}
	}
	stdout {
		codec => json_lines
	}
}
```

# 启动运行

  在【程序目录】目录执行以下命令启动：

```javascript
【windows】
bin\logstash.bat -f mysql\jdbc.conf
【linux】
nohup ./bin/logstash -f mysql/jdbc_jx_moretable.conf &
```

  可新建脚本配置好启动命令，后期直接运行即可。  在【程序目录】\logs目录会有**运行日志**。

**Note：**  5.x/6.X/7.x版本需要jdk8支持，如果默认jdk版本不是jdk8，那么需要在logstash或logstash.lib.sh的行首位置添加两个环境变量：

```javascript
export JAVA_CMD="/usr/tools/jdk1.8.0_162/bin"
export JAVA_HOME="/usr/tools/jdk1.8.0_162/"
```

**开机自启动：**

- windows开机自启：
  - 方案1：使用windows自带的任务计划；
  - 方案2：nssm注册windows服务，https://blog.csdn.net/u010887744/article/details/53957713

# 问题及解决方案

## 数据同步后，ES没有数据

  output.elasticsearch模块的index必须是全小写；

## 增量同步后last_run_metadata_path文件内容不改变

  如果lowercase_column_names配置的不是false，那么tracking_column字段配置的必须是全小写。

## 提示找不到jdbc_driver_library 

```javascript
2032 com.mysql.jdbc.Driver not loaded.
Are you sure you've included the correct jdbc driver in :jdbc_driver_library?
```

  检测配置的地址是否正确，如果是linux环境，注意路径分隔符是“/”，而不是“\”。

## 数据丢失 

  statement配置的sql中，如果比较字段使用的是大于“>”，可能存在数据丢失。  假设当同步完成后last_run_metadata_path存放的时间为2019-01-30 20:45:30，而这时候新入库一条数据的更新时间也为2019-01-30 20:45:30，那么这条数据将无法同步。  解决方案：将比较字段使用 大于等于“>=”。

## 数据重复更新 

  上一个问题“数据丢失”提供的解决方案是比较字段使用“大于等于”，但这时又会产生新的问题。  假设当同步完成后last_run_metadata_path存放的时间为2019-01-30 20:45:30，而数据库中更新时间最大值也为2019-01-30 20:45:30，那么这些数据将重复更新，直到有更新时间更大的数据出现。  当上述特殊数据很多，且长期没有新的数据更新时，会导致大量的数据重复同步到ES。  何时会出现以上情况呢：①比较字段非“自增”；②比较字段是程序生成插入。 **解决方案：**

- ①比较字段自增保证不重复或重复概率极小（比如使用自增ID或者数据库的timestamp），这样就能避免大部分异常情况了；
- ②如果确实存在大量程序插入的数据，其更新时间相同，且可能长期无数据更新，可考虑定期更新数据库中的一条测试数据，避免最大值有大量数据。

## 容灾

  logstash本身无法集群，我们常使用的组合ELK是通过kafka集群变相实现集群的。  可供选择的处理方式：①使用任务程序推送数据到kafaka，由kafka同步数据到ES，但任务程序本身也需要容灾，并需要考虑重复推送的问题；②将logstash加入守护程序，并辅以第三方监控其运行状态。  具体如何选择，需要结合自身的应用场景了。

## 海量数据同步

  为什么会慢？logstash分页查询使用临时表分页，每条分页SQL都是将全集查询出来当作临时表，再在临时表上分页查询。这样导致每次分页查询都要对主表进行一次全表扫描。

```javascript
SELECT * FROM (SELECT * FROM `ImageCN1`
 WHERE ModifyTime>= '1970-01-01 08:00:00'
 order by ModifyTime asc) AS `t1`
 LIMIT 5000 OFFSET 10000000;
```

  数据量太大，首次同步如何安全过渡同步？  可考虑在statement对应的sql中加上分页条件，比如ID在什么范围，修改时间在什么区间，将单词同步的数据总量减少。先少量数据同步测试验证，再根据测试情况修改区间条件启动logstash完成同步。比如将SQL修改为：

```javascript
SELECT
	*
FROM
	`ImageCN1` 
WHERE
	ModifyTime < '2018-10-10 10:10:10' AND ModifyTime >= '1970-01-01 08:00:00' 
ORDER BY
	ModifyTime ASC
```

  当同步完ModifyTime<'2018-10-10 10:10:10'区间的数据在修改SQL同步剩余区间的数据。  这样需要每次同步后就修改sql，线上运营比较繁琐，是否可以不修改sql，同时保证同步效率呢？SQL我们可以再修改下：

```javascript
SELECT
	*
FROM
	`ImageCN1` 
WHERE
	ModifyTime >= '1970-01-01 08:00:00' 
ORDER BY
	ModifyTime ASC 
	LIMIT 100000
```

  这样就能保证每次子查询的数据量不超过10W条，实际测试发现，数据量很大时效果很明显。

```javascript
[SQL]USE XXXDataDB;
受影响的行: 0
时间: 0.001s

[SQL]
SELECT
	*
FROM
	( SELECT * FROM `ImageCN1` WHERE ModifyTime >= '1970-01-01 08:00:00' ORDER BY ModifyTime ASC ) AS `t1` 
	LIMIT 5000 OFFSET 900000;
受影响的行: 0
时间: 7.229s

[SQL]
SELECT
	*
FROM
	( SELECT * FROM `ImageCN1` WHERE ModifyTime >= '2018-07-18 19:35:10' ORDER BY ModifyTime ASC LIMIT 100000 ) AS `t1` 
	LIMIT 5000 OFFSET 90000
受影响的行: 0
时间: 1.778s
```

  测试可以看出，SQL不加limit 10W时，越往后分页查询越慢，耗时达到8S，而**加了limit条件的SQL耗时稳定在2S以内**。
