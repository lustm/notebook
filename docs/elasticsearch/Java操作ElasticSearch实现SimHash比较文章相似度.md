最近工作中要求实现相似文本查询的功能，我于是决定用SimHash实现。

常规思路通常分为以下四步：

1、实现SimHash算法。

2、保存文章时，同时保存SimHash为倒排索引。

3、入库时或使用定时任务，在倒排索引中找到碰撞的SimHash，保存为结果表。

4、需要查询一篇文章的相似文章时，根据文章ID，查询结果表，找到相似文章。

<!-- more -->

不过这里有个小问题，如果一篇多次入库的文章的SimHash发生变化，或者文章被删除啥的，结果表可能很难及时更新。

同时ES刚好很擅长查询与维护倒排索引，所以我想能不能直接交给ES帮我维护SimHash的倒排索引，从而跳过使用结果表呢？

那么以上逻辑会简化到3步：

1、实现SimHash算法。

2、保存文章时，同时在ES中保存SimHash字段（和正文其它字段一起）。

3、需要查询一篇文章的相似文章时，根据文章ID查到SimHash值，再去ES查询匹配的其它文章ID，不过这里**需要在服务层做个汉明距离的过滤**。

 

说干就干，以下是我的实现代码，基于网上已有的算法进行了一些修改，总之给大家抛砖引玉了，如果有做的不好的地方还请大家指出。

 

首先添加依赖，使用HanLP分词，Jsoup提供正文HTML标签去除服务。

```xml
<dependency>
    <groupId>com.hankcs</groupId>
    <artifactId>hanlp</artifactId>
    <version>portable-1.8.1</version>
</dependency>

<dependency>
    <groupId>org.jsoup</groupId>
    <artifactId>jsoup</artifactId>
    <version>1.13.1</version>
</dependency>
```

接下来是SimHash的核心类，我这里直接写死了64位SimHash，判重阈值为3：

```java
package com.springboot.text;

import com.hankcs.hanlp.HanLP;
import com.hankcs.hanlp.dictionary.stopword.CoreStopWordDictionary;
import com.hankcs.hanlp.seg.common.Term;
import com.springboot.commonUtil.StringUtils;

import java.math.BigInteger;
import java.util.List;

/**
 * 提供SimHash相关的计算服务
 */
public class SimHashService {

    public static final BigInteger BIGINT_0 = BigInteger.valueOf(0);
    public static final BigInteger BIGINT_1 = BigInteger.valueOf(1);
    public static final BigInteger BIGINT_2 = BigInteger.valueOf(2);
    public static final BigInteger BIGINT_1000003 = BigInteger.valueOf(1000003);
    public static final BigInteger BIGINT_2E64M1 = BIGINT_2.pow(64).subtract(BIGINT_1);

    /**
     * 计算一段正文的simHash
     * 警告：修改该方法，修改HanLp分词结果（如新增停用词），会导致计算出的SimHash发生变化。
     *
     * @param text 需要计算的文本
     * @return 返回simHash，64位的0-1字符串。如果文本过短则返回null。
     */
    public static String get(String text) {
        if (text == null) {
            return null;
        }
        text = StringUtils.removeHtml(text); // return Jsoup.parse(text).text();
        int sumWeight = 0;
        int maxWeight = 0;
        int[] bits = new int[64];
        List<Term> termList = HanLP.segment(text);
        for (Term term : termList) {
            String word = term.word;
            String nature = term.nature.toString();
            if (nature.startsWith("w") || CoreStopWordDictionary.contains(word)) {
                // 去除标点符号和停用词
                continue;
            }
            BigInteger wordHash = getWordHash(word);
            int wordWeight = getWordWeight(word);
            if (wordWeight == 0) {
                continue;
            }
            sumWeight += wordWeight;
            if (maxWeight < wordWeight) {
                maxWeight = wordWeight;
            }
            // 逐位将计算好的词哈希乘以权重，记录到保存用的数组上。
            // 如果该位哈希为1，则加上对应的权重，反之减去对应的权重。
            for (int i = 0; i < 64; i++) {
                BigInteger bitMask = BIGINT_1.shiftLeft(63 - i);
                if (wordHash.and(bitMask).signum() != 0) {
                    bits[i] += wordWeight;
                } else {
                    bits[i] -= wordWeight;
                }
            }
        }
        if (3 * maxWeight >= sumWeight || sumWeight < 20) {
            // 文本太短导致哈希不充分，拒绝返回结果（否则可能会有太多碰撞的文档，导致查询性能低下）
            // 暂时定为至少需要凑齐3个大词才允许返回结果
            return null;
        }

        // 将保存的位统计结果降维，处理成0/1字符串并返回
        StringBuilder simHashBuilder = new StringBuilder();
        for (int i = 0; i < 64; i++) {
            if (bits[i] > 0) {
                simHashBuilder.append("1");
            } else {
                simHashBuilder.append("0");
            }
        }
        return simHashBuilder.toString();
    }

    /**
     * 获取一个单词的哈希值
     * 警告：修改该方法会导致计算出的SimHash发生变化。
     *
     * @param word 输入的单词
     * @return 返回哈希
     */
    private static BigInteger getWordHash(String word) {
        if (StringUtils.isBlank(word)) {
            return BIGINT_0;
        }
        char[] sourceArray = word.toCharArray();
        // 经过调优，发现左移位数为11-12左右最优
        // 在哈希词语主要为长度2的中文词时，可以避免高位哈希出现明显偏向
        // 反之，如果左移位数太大，则低位哈希将只和词语最后一个字相关
        BigInteger hash = BigInteger.valueOf(((long) sourceArray[0]) << 12);
        for (char ch : sourceArray) {
            BigInteger chInt = BigInteger.valueOf(ch);
            hash = hash.multiply(BIGINT_1000003).xor(chInt).and(BIGINT_2E64M1);
        }
        hash = hash.xor(BigInteger.valueOf(word.length()));
        return hash;
    }

    /**
     * 获取一个单词的权重。
     * 警告：修改该方法会导致计算出的SimHash发生变化。
     *
     * @param word 输入单词
     * @return 输出权重
     */
    private static int getWordWeight(String word) {
        if (StringUtils.isBlank(word)) {
            return 0;
        }
        int length = word.length();
        if (length == 1) {
            // 只有长度为1的词，哈希后位数不够（40位左右），所以权重必须很低，否则容易导致高位哈希全部为0。
            return 1;
        } else if (word.charAt(0) >= 0x3040) {
            if (length == 2) {
                return 8;
            } else {
                return 16;
            }
        } else {
            if (length == 2) {
                return 2;
            } else {
                return 4;
            }
        }
    }

    /**
     * 截取SimHash的一部分，转换为short对象
     *
     * @param simHash 原始SimHash字符串，64位0/1字符
     * @param part    需要截取的部分编号
     * @return 返回Short值
     */
    public static Short toShort(String simHash, int part) {
        if (simHash == null || part < 0 || part > 3) {
            return null;
        }
        int startBit = part * 16;
        int endBit = (part + 1) * 16;
        return Integer.valueOf(simHash.substring(startBit, endBit), 2).shortValue();
    }

    /**
     * 将四段Short格式的SimHash拼接成字符串
     *
     * @param simHashA simHashA，最高位
     * @param simHashB simHashB
     * @param simHashC simHashC
     * @param simHashD simHashD，最低位
     * @return 返回64位0/1格式的SimHash
     */
    public static String toSimHash(Short simHashA, Short simHashB, Short simHashC, Short simHashD) {
        return toSimHash(simHashA) + toSimHash(simHashB) + toSimHash(simHashC) + toSimHash(simHashD);
    }

    /**
     * 将一段Short格式的SimHash拼接成字符串
     *
     * @param simHashX 需要转换的Short格式SimHash
     * @return 返回16位0/1格式的SimHash
     */
    public static String toSimHash(Short simHashX) {
        StringBuilder simHashBuilder = new StringBuilder(Integer.toString(simHashX & 65535, 2));
        int fill0Count = 16 - simHashBuilder.length();
        for (int i = 0; i < fill0Count; i++) {
            simHashBuilder.insert(0, "0");
        }
        return simHashBuilder.toString();
    }

    /**
     * 比较两组SimHash（一组为64位0/1字符串，一组为四组Short），计算汉明距离
     *
     * @param simHash  待比较的SimHash（X），64位0/1字符串
     * @param simHashA 待比较的SimHash（Y），Short格式，最高位
     * @param simHashB 待比较的SimHash（Y），Short格式
     * @param simHashC 待比较的SimHash（Y），Short格式
     * @param simHashD 待比较的SimHash（Y），Short格式，最低位
     * @return 返回汉明距离
     */
    public static int hammingDistance(String simHash, Short simHashA, Short simHashB, Short simHashC, Short simHashD) {
        if (simHash == null || simHashA == null || simHashB == null || simHashC == null || simHashD == null) {
            return -1;
        }
        int hammingDistance = 0;
        for (int part = 0; part < 4; part++) {
            Short simHashX = toShort(simHash, part);
            Short simHashY = null;
            switch (part) {
                case 0:
                    simHashY = simHashA;
                    break;
                case 1:
                    simHashY = simHashB;
                    break;
                case 2:
                    simHashY = simHashC;
                    break;
                case 3:
                    simHashY = simHashD;
                    break;
            }
            hammingDistance += hammingDistance(simHashX, simHashY);
        }
        return hammingDistance;
    }

    /**
     * 比较两个Short格式的SimHash的汉明距离
     *
     * @param simHashX 待比较的SimHashX
     * @param simHashY 待比较的SimHashY
     * @return 返回汉明距离
     */
    public static int hammingDistance(Short simHashX, Short simHashY) {
        if (simHashX == null || simHashY == null) {
            return -1;
        }
        int hammingDistance = 0;
        int xorResult = (simHashX ^ simHashY) & 65535;

        while (xorResult != 0) {
            xorResult = xorResult & (xorResult - 1);
            hammingDistance += 1;
        }
        return hammingDistance;
    }

}
```

ES索引中需要新增4个SimHash相关的字段：

```json
{
    "simHashA":{
        "type":"short"
    },
    "simHashB":{
        "type":"short"
    },
    "simHashC":{
        "type":"short"
    },
    "simHashD":{
        "type":"short"
    }
}
```

最后是ES查询逻辑，根据传入的SimHash，先使用ES找到至少一组SimHash相等的文档，然后在Java代码中比较剩下三组是否满足要求。

```java
/**
     * 根据SimHash，查询相似的文章。
     *
     * @param indexNames 需要查询的索引名称（允许多个）
     * @param simHashA   simHashA的值
     * @param simHashB   simHashB的值
     * @param simHashC   simHashC的值
     * @param simHashD   simHashD的值
     * @return 返回相似文章RowKey列表。
     */
    public List<String> searchBySimHash(String indexNames, Short simHashA, short simHashB, short simHashC, short simHashD) {
        String simHash = SimHashService.toSimHash(simHashA, simHashB, simHashC, simHashD);
        return searchBySimHash(indexNames, simHash);
    }

    /**
     * 根据SimHash，查询相似的文章。
     *
     * @param indexNames 需要查询的索引名称（允许多个）
     * @param simHash    需要查询的SimHash (格式：64位二进制字符串)
     * @return 返回相似文章RowKey列表。
     */
    public List<String> searchBySimHash(String indexNames, String simHash) {
        List<String> resultList = new ArrayList<>();
        if (simHash == null) {
            return resultList;
        }
        try {
            String scrollId = "";
            while (true) {
                if (scrollId == null) {
                    break;
                }
                SearchResponse response = null;
                if (scrollId.isEmpty()) {
                    // 首次请求，正常查询
                    SearchRequest request = new SearchRequest(indexNames.split(","));
                    BoolQueryBuilder bqBuilder = QueryBuilders.boolQuery();
                    bqBuilder.should(QueryBuilders.termQuery("simHashA", SimHashService.toShort(simHash, 0)));
                    bqBuilder.should(QueryBuilders.termQuery("simHashB", SimHashService.toShort(simHash, 1)));
                    bqBuilder.should(QueryBuilders.termQuery("simHashC", SimHashService.toShort(simHash, 2)));
                    bqBuilder.should(QueryBuilders.termQuery("simHashD", SimHashService.toShort(simHash, 3)));
                    SearchSourceBuilder sourceBuilder = new SearchSourceBuilder().size(10000);
                    sourceBuilder.query(bqBuilder);
                    sourceBuilder.from(0);
                    sourceBuilder.size(10000);
                    sourceBuilder.timeout(TimeValue.timeValueSeconds(60));
                    sourceBuilder.fetchSource(new String[]{"hId", "simHashA", "simHashB", "simHashC", "simHashD"}, new String[]{});
                    sourceBuilder.sort("publishDate", SortOrder.DESC);
                    request.source(sourceBuilder);
                    request.scroll(TimeValue.timeValueSeconds(60));
                    response = client.search(request, RequestOptions.DEFAULT);
                } else {
                    // 之后请求，走游标查询
                    SearchScrollRequest searchScrollRequest = new SearchScrollRequest(scrollId).scroll(TimeValue.timeValueMinutes(10));
                    response = client.scroll(searchScrollRequest, RequestOptions.DEFAULT);
                }
                if (response != null && response.getHits().getHits().length > 0) {
                    // 查到的记录必然有一组simHashX与输入相同，但需要合并确认总数是否小于阈值
                    // 很可能有几万的命中，但最终过滤完只剩下几条数据，最终留下ID
                    for (SearchHit hit : response.getHits().getHits()) {
                        Map<String, Object> sourceAsMap = hit.getSourceAsMap();
                        String hId = String.valueOf(sourceAsMap.get("hId"));
                        Short simHashA = Short.parseShort(sourceAsMap.get("simHashA").toString());
                        Short simHashB = Short.parseShort(sourceAsMap.get("simHashB").toString());
                        Short simHashC = Short.parseShort(sourceAsMap.get("simHashC").toString());
                        Short simHashD = Short.parseShort(sourceAsMap.get("simHashD").toString());
                        int hammingDistance = SimHashService.hammingDistance(simHash, simHashA, simHashB, simHashC, simHashD);
                        if (hammingDistance < 4) {
                            System.out.println(hammingDistance + "\t" + hId);
                            resultList.add(sourceAsMap.get("hId").toString());
                        }
                    }
                    scrollId = response.getScrollId();
                } else {
                    break;
                }
            }
        } catch (IOException e) {
            e.printStackTrace();
        }
        return resultList;
    }
```
