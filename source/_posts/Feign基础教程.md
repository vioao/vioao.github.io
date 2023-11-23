---
title: Feign基础教程
seo_title: feign-for-beginner
date: 2017-06-23 22:38:43
tags: [Feign,Http Client]
categories: [Java]

---

## 简介
[Feign](https://github.com/OpenFeign/feign)使得 `Java HTTP` 客户端编写更方便。`Feign` 灵感来源于[Retrofit](https://github.com/square/retrofit)、[JAXRS-2.0](https://jax-rs-spec.java.net/nonav/2.0/apidocs/index.html)和[WebSocket](http://www.oracle.com/technetwork/articles/java/jsr356-1937161.html)。`Feign` 最初是为了降低统一绑定[Denominator](https://github.com/Netflix/Denominator) 到 `HTTP API` 的复杂度，不区分是否支持 `Restful`。

Maven依赖:
```xml
<!-- https://mvnrepository.com/artifact/com.netflix.feign/feign-core -->
<dependency>
    <groupId>com.netflix.feign</groupId>
    <artifactId>feign-core</artifactId>
    <version>8.18.0</version>
    <scope>runtime</scope>
</dependency>
```

---

## 为什么选择Feign而不是其他
你可以使用 `Jersey` 和 `CXF` 这些来写一个 `Rest` 或 `SOAP` 服务的java客服端。你也可以直接使用 `Apache HttpClient` 来实现。但是 `Feign` 的目的是尽量的减少资源和代码来实现和 `HTTP API` 的连接。通过自定义的编码解码器以及错误处理，你可以编写任何基于文本的 `HTTP API`。

---

## Feign工作机制
Feign通过注解注入一个模板化请求进行工作。只需在发送之前关闭它，参数就可以被直接的运用到模板中。然而这也限制了Feign，只支持文本形式的API，它在响应请求等方面极大的简化了系统。同时，它也是十分容易进行单元测试的。

<!--more-->

---

## Feign使用简介

### 基本用法
基本的使用如下所示，一个对于[canonical Retrofit sample](https://github.com/square/retrofit/blob/master/samples/src/main/java/com/example/retrofit/SimpleService.java)的适配。
```java
interface GitHub {
  // RequestLine注解声明请求方法和请求地址,可以允许有查询参数
  @RequestLine("GET /repos/{owner}/{repo}/contributors")
  List<Contributor> contributors(@Param("owner") String owner, @Param("repo") String repo);
}

static class Contributor {
  String login;
  int contributions;
}

public static void main(String... args) {
  GitHub github = Feign.builder()
                       .decoder(new GsonDecoder())
                       .target(GitHub.class, "https://api.github.com");

  // Fetch and print a list of the contributors to this library.
  List<Contributor> contributors = github.contributors("OpenFeign", "feign");
  for (Contributor contributor : contributors) {
    System.out.println(contributor.login + " (" + contributor.contributions + ")");
  }
}
```

---

### 自定义
`Feign` 有许多可以自定义的方面。举个简单的例子，你可以使用 `Feign.builder()` 来构造一个拥有你自己组件的API接口。如下:
```java
interface Bank {
  @RequestLine("POST /account/{id}")
  Account getAccountInfo(@Param("id") String id);
}
...
// AccountDecoder() 是自己实现的一个Decoder
Bank bank = Feign.builder().decoder(new AccountDecoder()).target(Bank.class, "https://api.examplebank.com");
```

---

### 多种接口
`Feign`可以提供多种API接口，这些接口都被定义为 `Target<T>` (默认的实现是 `HardCodedTarget<T>`), 它允许在执行请求前动态发现和装饰该请求。
举个例子，下面的这个模式允许使用当前url和身份验证token来装饰每个发往身份验证中心服务的请求。
```java
CloudDNS cloudDNS = Feign.builder().target(new CloudIdentityTarget<CloudDNS>(user, apiKey));
```

---

### 示例
`Feign` 包含了  [GitHub](https://github.com/OpenFeign/feign/blob/master/example-github) 和 [Wikipedia](https://github.com/OpenFeign/feign/blob/master/example-wikipedia) 客户端的实现样例.相似的项目也同样在实践中运用了Feign。尤其是它的示例后台程序。

---

## Feign集成模块
`Feign` 可以和其他的开源工具集成工作。你可以将这些开源工具集成到 `Feign` 中来。目前已经有的一些模块如下:

### Gson
[Gson](https://github.com/OpenFeign/feign/blob/master/gson) 包含了一个编码器和一个解码器，这个可以被用于JSON格式的API。
添加 `GsonEncoder` 以及 `GsonDecoder` 到你的 `Feign.Builder` 中， 如下:
```java
GsonCodec codec = new GsonCodec();
GitHub github = Feign.builder()
                     .encoder(new GsonEncoder())
                     .decoder(new GsonDecoder())
                     .target(GitHub.class, "https://api.github.com");
```

Maven依赖:
```xml
<!-- https://mvnrepository.com/artifact/com.netflix.feign/feign-gson -->
<dependency>
    <groupId>com.netflix.feign</groupId>
    <artifactId>feign-gson</artifactId>
    <version>8.18.0</version>
</dependency>
```

### Jackson
[Jackson](https://github.com/OpenFeign/feign/blob/master/jackson) 包含了一个编码器和一个解码器，这个可以被用于JSON格式的API。
添加 `JacksonEncoder ` 以及 `JacksonDecoder ` 到你的 `Feign.Builder` 中， 如下:
```java
GitHub github = Feign.builder()
                     .encoder(new JacksonEncoder())
                     .decoder(new JacksonDecoder())
                     .target(GitHub.class, "https://api.github.com");
```

Maven依赖:
```xml
  <!-- https://mvnrepository.com/artifact/com.netflix.feign/feign-gson -->
  <dependency>
      <groupId>com.netflix.feign</groupId>
      <artifactId>feign-jackson</artifactId>
      <version>8.18.0</version>
  </dependency>
```

### Sax
[`SaxDecoder`](https://github.com/OpenFeign/feign/blob/master/sax) 用于解析XML,并兼容普通JVM和Android。下面是一个配置sax来解析响应的例子:
```java
api = Feign.builder()
           .decoder(SAXDecoder.builder()
                              .registerContentHandler(UserIdHandler.class)
                              .build())
           .target(Api.class, "https://apihost");
```

Maven依赖:
```xml
<dependency>
    <groupId>com.netflix.feign</groupId>
    <artifactId>feign-sax</artifactId>
    <version>8.18.0</version>
</dependency>
```

### JAXB
[JAXB](https://github.com/OpenFeign/feign/blob/master/jaxb) 包含了一个编码器和一个解码器，这个可以被用于XML格式的API。
添加 `JAXBEncoder` 以及 `JAXBDecoder` 到你的 `Feign.Builder` 中， 如下:
```java
api = Feign.builder()
           .encoder(new JAXBEncoder())
           .decoder(new JAXBDecoder())
           .target(Api.class, "https://apihost");
```

Maven依赖:
```xml
<!-- https://mvnrepository.com/artifact/com.netflix.feign/feign-gson -->
<dependency>
    <groupId>com.netflix.feign</groupId>
    <artifactId>feign-jaxb</artifactId>
    <version>8.18.0</version>
</dependency>
```

### JAX-RS
[`JAXRSContract`](https://github.com/OpenFeign/feign/blob/master/jaxrs) 使用 JAX-RS 规范重写覆盖了默认的注解处理。下面是一个使用 JAX-RS 的例子:

```java
interface GitHub {
  @GET @Path("/repos/{owner}/{repo}/contributors")
  List<Contributor> contributors(@PathParam("owner") String owner, @PathParam("repo") String repo);
}
// contract 方法配置注解处理器,注解处理器定义了哪些注解和值是可以作用于接口的
GitHub github = Feign.builder()
                     .contract(new JAXRSContract())
                     .target(GitHub.class, "https://api.github.com");
```

Maven依赖:
```xml
<!-- https://mvnrepository.com/artifact/com.netflix.feign/feign-gson -->
<dependency>
    <groupId>com.netflix.feign</groupId>
    <artifactId>feign-jaxrs</artifactId>
    <version>8.18.0</version>
</dependency>
```

### OkHttp
[OkHttpClient](https://github.com/OpenFeign/feign/blob/master/okhttp) 使用 `OkHttp` 来发送 `Feign` 的请求，`OkHttp` 支持 `SPDY` (SPDY是Google开发的基于TCP的传输层协议，用以最小化网络延迟，提升网络速度，优化用户的网络使用体验),并有更好的控制http请求。
要让 `Feign` 使用 `OkHttp` ，你需要将 `OkHttp` 加入到你的环境变量中区，然后配置 `Feign` 使用 `OkHttpClient`，如下:

```java
GitHub github = Feign.builder()
                     .client(new OkHttpClient())
                     .target(GitHub.class, "https://api.github.com");
```

Maven依赖:
```xml
<!-- https://mvnrepository.com/artifact/com.netflix.feign/feign-gson -->
<dependency>
    <groupId>com.netflix.feign</groupId>
    <artifactId>feign-okhttp</artifactId>
    <version>8.18.0</version>
</dependency>
```

### Ribbon
[`RibbonClient`](https://github.com/OpenFeign/feign/blob/master/ribbon) 重写了 `Feign` 客户端的对URL的处理，其添加了 智能路由以及一些其他由[Ribbon](https://github.com/Netflix/ribbon)提供的弹性功能。
集成Ribbon需要你将ribbon的客户端名称当做url的host部分来传递，如下：
```java
// myAppProd是你的ribbon client name
MyService api = Feign.builder().client(RibbonClient.create()).target(MyService.class, "https://myAppProd");
```

Maven依赖:
```xml
<!-- https://mvnrepository.com/artifact/com.netflix.feign/feign-gson -->
<dependency>
    <groupId>com.netflix.feign</groupId>
    <artifactId>feign-ribbon</artifactId>
    <version>8.18.0</version>
</dependency>
```

### Hystrix
[`HystrixFeign`](https://github.com/OpenFeign/feign/blob/master/hystrix) 配置了 `Hystrix` 提供的**熔断**机制。
要在 `Feign` 中使用 `Hystrix` ，你需要添加`Hystrix`模块到你的环境变量，然后使用 `HystrixFeign` 来构造你的API:
```java
MyService api = HystrixFeign.builder().target(MyService.class, "https://myAppProd");
```

Maven依赖:
```xml
<!-- https://mvnrepository.com/artifact/com.netflix.feign/feign-gson -->
<dependency>
    <groupId>com.netflix.feign</groupId>
    <artifactId>feign-hystrix</artifactId>
    <version>8.18.0</version>
</dependency>
```

### SLF4J
[SLF4JModule](https://github.com/OpenFeign/feign/blob/master/slf4j) 允许你使用 `SLF4J` 作为 `Feign` 的日志记录模块，这样你就可以轻松的使用 `Logback`, `Log4J` , 等 来记录你的日志.
要在 `Feign` 中使用 `SLF4J` ，你需要添加`SLF4J`模块和对应的日志记录实现模块(比如Log4J)到你的环境变量，然后配置 `Feign`使用`Slf4jLogger` :
```java
GitHub github = Feign.builder()
                     .logger(new Slf4jLogger())
                     .target(GitHub.class, "https://api.github.com");
```

Maven依赖:
```xml
<!-- https://mvnrepository.com/artifact/com.netflix.feign/feign-gson -->
<dependency>
    <groupId>com.netflix.feign</groupId>
    <artifactId>feign-slf4j</artifactId>
    <version>8.18.0</version>
</dependency>
```

---

## Feign 组成

### Decoders
`Feign.builder()` 允许你自定义一些额外的配置，比如说如何解码一个响应。假如有接口方法返回的消息不是 `Response`, `String`, `byte[]` 或者 `void` 类型的，那么你需要配置一个非默认的解码器。
下面是一个配置使用JSON解码器(使用的是feign-gson扩展)的例子:
```java
GitHub github = Feign.builder()
                     .decoder(new GsonDecoder())
                     .target(GitHub.class, "https://api.github.com");
```
假如你想在将响应传递给解码器处理前做一些额外的处理，那么你可以使用`mapAndDecode`方法。一个用例就是使用jsonp服务的时候:
```java
// 貌似1.8.0版本中沒有mapAndDecode这个方法。。。
JsonpApi jsonpApi = Feign.builder()
                         .mapAndDecode((response, type) -> jsopUnwrap(response, type), new GsonDecoder())
                         .target(JsonpApi.class, "https://some-jsonp-api.com");
```

### Encoders
发送一个Post请求最简单的方法就是传递一个 `String` 或者 `byte[]` 类型的参数了。你也许还需添加一个Content-Type请求头，如下:
```java
interface LoginClient {
  @RequestLine("POST /")
  @Headers("Content-Type: application/json")
  void login(String content);
}
...
client.login("{\"user_name\": \"denominator\", \"password\": \"secret\"}");
```

通过配置一个解码器，你可以发送一个安全类型的请求体，如下是一个使用 feign-gson 扩展的例子:
```java
static class Credentials {
  final String user_name;
  final String password;

  Credentials(String user_name, String password) {
    this.user_name = user_name;
    this.password = password;
  }
}

interface LoginClient {
  @RequestLine("POST /")
  void login(Credentials creds);
}
...
LoginClient client = Feign.builder()
                          .encoder(new GsonEncoder())
                          .target(LoginClient.class, "https://foo.com");

client.login(new Credentials("denominator", "secret"));
```

### @Body templates
`@Body`注解申明一个请求体模板，模板中可以带有参数，与方法中 `@Param` 注解申明的参数相匹配,使用方法如下:
 ```java
interface LoginClient {

  @RequestLine("POST /")
  @Headers("Content-Type: application/xml")
  @Body("<login \"user_name\"=\"{user_name}\" \"password\"=\"{password}\"/>")
  void xml(@Param("user_name") String user, @Param("password") String password);

  @RequestLine("POST /")
  @Headers("Content-Type: application/json")
  // json curly braces must be escaped!
  // 这里JSON格式需要的花括号居然需要转码，有点蛋疼了。
  @Body("%7B\"user_name\": \"{user_name}\", \"password\": \"{password}\"%7D")
  void json(@Param("user_name") String user, @Param("password") String password);
}
...
client.xml("denominator", "secret"); // <login "user_name"="denominator" "password"="secret"/>
client.json("denominator", "secret"); // {"user_name": "denominator", "password": "secret"}
```

### Headers
`Feign` 支持给请求的api设置或者请求的客户端设置请求头，如下:

#### 给API设置请求头
- 使用 `@Headers` 设置静态请求头
```java
// 给BaseApi中的所有方法设置Accept请求头
@Headers("Accept: application/json")
interface BaseApi<V> {
  // 单独给put方法设置Content-Type请求头
  @Headers("Content-Type: application/json")
  @RequestLine("PUT /api/{key}")
  void put(@Param("key") String, V value);
}
```

- 设置动态值的请求头
```java
@RequestLine("POST /")
@Headers("X-Ping: {token}")
void post(@Param("token") String token);
```

- 设置key和value都是动态的请求头
有些API需要根据调用时动态确定使用不同的请求头(e.g. custom metadata header fields such as "x-amz-meta-*" or "x-goog-meta-*"),
这时候可以使用 `@HeaderMap` 注解，如下:
```java
// @HeaderMap 注解设置的请求头优先于其他方式设置的
@RequestLine("POST /")
void post(@HeaderMap Map<String, Object> headerMap);
```

#### 给Target设置请求头
有时我们需要在一个API实现中根据不同的endpoint来传入不同的Header，这个时候我们可以使用自定义的RequestInterceptor 或 Target来实现.
通过自定义的 RequestInterceptor 来实现请查看 **Request Interceptors** 章节.
下面是一个通过自定义Target来实现给每个Target设置安全校验信息Header的例子:
```java
  static class DynamicAuthTokenTarget<T> implements Target<T> {
    public DynamicAuthTokenTarget(Class<T> clazz,
                                  UrlAndTokenProvider provider,
                                  ThreadLocal<String> requestIdProvider);
    ...
    @Override
    public Request apply(RequestTemplate input) {
      TokenIdAndPublicURL urlAndToken = provider.get();
      if (input.url().indexOf("http") != 0) {
        input.insert(0, urlAndToken.publicURL);
      }
      input.header("X-Auth-Token", urlAndToken.tokenId);
      input.header("X-Request-ID", requestIdProvider.get());

      return input.request();
    }
  }
  ...
  Bank bank = Feign.builder()
          .target(new DynamicAuthTokenTarget(Bank.class, provider, requestIdProvider));
```
这种方法的实现依赖于给`Feign` 客户端设置的自定义的RequestInterceptor 或 Target。可以被用来给一个客户端的所有api请求设置请求头。比如说可是被用来在header中设置身份校验信息。这些方法是在线程执行api请求的时候才会执行，所以是允许在运行时根据上下文来动态设置header的。
比如说可以根据线程本地存储(thread-local storage)来为不同的线程设置不同的请求头。

---

## 高级用法

### Base APIS
有些请求中的一些方法是通用的，但是可能会有不同的参数类型或者返回类型，这个时候可以这么用:
```java
// 通用API
interface BaseAPI {
  @RequestLine("GET /health")
  String health();

  @RequestLine("GET /all")
  List<Entity> all();
}

// 继承通用API
interface CustomAPI extends BaseAPI {
  @RequestLine("GET /custom")
  String custom();
}

// 各种类型有相同的表现形式，定义一个统一的API
@Headers("Accept: application/json")
interface BaseApi<V> {

  @RequestLine("GET /api/{key}")
  V get(@Param("key") String key);

  @RequestLine("GET /api")
  List<V> list();

  @Headers("Content-Type: application/json")
  @RequestLine("PUT /api/{key}")
  void put(@Param("key") String key, V value);
}

// 根据不同的类型来继承
interface FooApi extends BaseApi<Foo> { }

interface BarApi extends BaseApi<Bar> { }
```

### Logging
你可以通过设置一个 `Logger` 来记录http消息，如下:
```java
GitHub github = Feign.builder()
                     .decoder(new GsonDecoder())
                     .logger(new Logger.JavaLogger().appendToFile("logs/http.log"))
                     .logLevel(Logger.Level.FULL)
                     .target(GitHub.class, "https://api.github.com");
```
也可以参考上面的 **SLF4J** 章节的说明

### Request Interceptors
当你希望修改所有的的请求的时候，你可以使用Request Interceptors。比如说，你作为一个中介，你可能需要为每个请求设置 `X-Forwarded-For`
```java
static class ForwardedForInterceptor implements RequestInterceptor {
  @Override public void apply(RequestTemplate template) {
    template.header("X-Forwarded-For", "origin.host.com");
  }
}
...
Bank bank = Feign.builder()
                 .decoder(accountDecoder)
                 .requestInterceptor(new ForwardedForInterceptor())
                 .target(Bank.class, "https://api.examplebank.com");
```
或者，你可能需要实现Basic Auth，这里有一个内置的基础校验拦截器 `BasicAuthRequestInterceptor`
```java
Bank bank = Feign.builder()
                 .decoder(accountDecoder)
                 .requestInterceptor(new BasicAuthRequestInterceptor(username, password))
                 .target(Bank.class, "https://api.examplebank.com");
```

### Custom @Param Expansion
在使用 `@Param` 注解给模板中的参数设值的时候，默认的是使用的对象的 `toString()` 方法的值，通过声明 自定义的`Param.Expander`，用户可以控制其行为，比如说格式化 `Date` 类型的值:
```java
// 通过设置 @Param 的 expander 为 DateToMillis.class 可以定义Date类型的值
@RequestLine("GET /?since={date}")
Result list(@Param(value = "date", expander = DateToMillis.class) Date date);
```

### Dynamic Query Parameters
动态查询参数支持，通过使用 `@QueryMap` 可以允许动态传入请求参数,如下:
```java
@RequestLine("GET /find")
V find(@QueryMap Map<String, Object> queryMap);
```

### Static and Default Methods
如果你使用的是JDK 1.8+ 的话，那么你可以给接口设置统一的默认方法和静态方法,这个事JDK8的新特性，如下:
```java
interface GitHub {
  @RequestLine("GET /repos/{owner}/{repo}/contributors")
  List<Contributor> contributors(@Param("owner") String owner, @Param("repo") String repo);

  @RequestLine("GET /users/{username}/repos?sort={sort}")
  List<Repo> repos(@Param("username") String owner, @Param("sort") String sort);

  default List<Repo> repos(String owner) {
    return repos(owner, "full_name");
  }

  /**
   * Lists all contributors for all repos owned by a user.
   */
  default List<Contributor> contributors(String user) {
    MergingContributorList contributors = new MergingContributorList();
    for(Repo repo : this.repos(owner)) {
      contributors.addAll(this.contributors(user, repo.getName()));
    }
    return contributors.mergeResult();
  }

  static GitHub connect() {
    return Feign.builder()
                .decoder(new GsonDecoder())
                .target(GitHub.class, "https://api.github.com");
  }
}
```
