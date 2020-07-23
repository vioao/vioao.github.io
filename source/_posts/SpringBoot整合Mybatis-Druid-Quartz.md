---
title: SpringBoot 整合Mybatis/Druid/Quartz
date: 2017-11-12 11:43:24
tags: [SpringBoot,Quartz,Druid,H2,Mybatis]
categories: [工作记录]

---

由于项目中定时任务逐渐增多，对系统的压力也慢慢增加。故打算将系统中的定时任务抽离出来。初步决定使用SpringBoot+mybatis+quartz的整合方式进行快速开发。
整个整合会包含如下任务:
1. 整合Mybatis(包括通用Mapper和分页插件)
2. 整合Quartz实现动态定时任务管理
3. 整合Spring AOP编程(定时任务中的AOP也会生效)
4. 整合Druid
5. Spring单元测试集成H2数据库


<!-- more -->

---
## 整合MyBatis

### 添加依赖
```
        <!--mybatis-->
        <dependency>
            <groupId>org.mybatis.spring.boot</groupId>
            <artifactId>mybatis-spring-boot-starter</artifactId>
            <version>${mybatis-spring-boot-starter.version}</version>
        </dependency>

        <!-- mysql -->
        <dependency>
            <groupId>mysql</groupId>
            <artifactId>mysql-connector-java</artifactId>
            <scope>runtime</scope>
        </dependency>
```

### 添加application.properties配置
主要添加数据库连接配置和mybatis的mapper的xml配置文件路径以及实体类的包。还有一些mybatis的相关配置:[mybatis相关配置参数参考](http://www.mybatis.org/mybatis-3/zh/configuration.html)

```properties
# 配置数据库连接
spring.datasource.driver-class-name = com.mysql.jdbc.Driver
spring.datasource.url = jdbc:mysql://localhost:3306/taskmgr?useUnicode=true&characterEncoding=utf-8&useSSL=false
spring.datasource.username = root
spring.datasource.password = 123456

#mybatis
mybatis.type-aliases-package=com.pingan.wechat.app.entity
mybatis.mapper-locations=classpath:mapper/*.xml

#more configuration about mybatis : http://www.mybatis.org/mybatis-3/zh/configuration.html
mybatis.configuration.map-underscore-to-camel-case=true
mybatis.configuration.auto-mapping-unknown-column-behavior=warning
mybatis.configuration.use-generated-keys=true
```
---

## 整合通用Mapper和分页插件
使用原始的Mybatis有个问题就是,每个实体类的通用CURD操作等都需要自己写xml配置文件或者在对应的Mapper文件中写对应的@Select/@Insert 等注解来实现对应的功能。这是个特别耗时的重复工作。
解决这个问题有两种方式:
1. 使用Mybatis Generator自动生成对应的xml文件
2.  集成通用Mapper。

个人觉得集成通用Mapper相对简单，所以选择了该中方式。通用Mapper的作者本身也有写两种方式的对比。[MyBatis通用Mapper3文档](https://gitee.com/free/Mapper)
另外，为了方便使用支持物理分页,也需要集成分页插件[Mybatis_PageHelper](https://gitee.com/free/Mybatis_PageHelper)。

### 添加依赖
```
        <!--mapper-->
        <dependency>
            <groupId>tk.mybatis</groupId>
            <artifactId>mapper-spring-boot-starter</artifactId>
            <version>${mapper-spring-boot-starter.version}</version>
        </dependency>
        <!--pagehelper-->
        <dependency>
            <groupId>com.github.pagehelper</groupId>
            <artifactId>pagehelper-spring-boot-starter</artifactId>
            <version>${pagehelper-spring-boot-starter.version}</version>
        </dependency>
```

### 编写CommonMapper接口
编写基本的CommonMapper接口，继承通用Mapper的接口 `Mapper<T>`, `MySqlMapper<T>`, `SelectByIdsMapper<T>`, `DeleteByIdsMapper<T> `;其中有些接口只适用于特定的数据库，需要根据实际情况做调整。 其他的业务相关的Mapper则需要继承这个`CommonMapper<T>`接口。
对应service层基本Service接口和实现则根据自身需要考虑是否需要。

```
import tk.mybatis.mapper.common.Mapper;
import tk.mybatis.mapper.common.MySqlMapper;
import tk.mybatis.mapper.common.ids.DeleteByIdsMapper;
import tk.mybatis.mapper.common.ids.SelectByIdsMapper;

/**
 * 支持单表CURD和批量(MYSQL)操作的通用Mapper
 * Created by Vio on 2017/11/6.
 */
public interface CommonMapper<T> extends Mapper<T>, MySqlMapper<T>, SelectByIdsMapper<T>, DeleteByIdsMapper<T> {

}

```

### 添加application.properties配置
```
# 这里配置自己写的基本的CommonMapper
mapper.mappers=com.xx.xxx.app.mapper.CommonMapper
mapper.not-empty=false
mapper.identity=MYSQL

#pagehelper插件配置
pagehelper.helperDialect=mysql
pagehelper.reasonable=true
pagehelper.supportMethodsArguments=true
pagehelper.params=count=countSql
```
---

## 整合Quartz
整合Quartz时最主要会遇到两个问题:
1. 实现了Job接口的Quartz任务类中无法注入使用Spring管理的bean
2. 使用Spring AOP编程在实现了Job接口的Quartz任务类中无效(**quartz aop 失效**)

其实上面两个问题的根本都是因为Job的实例的创建和管理没有交给Spring来管理。下面给出可以解决上述两个问题的整合方式:

### 添加依赖
```
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-aop</artifactId>
        </dependency>

        <!-- quartz -->
        <dependency>
            <groupId>org.quartz-scheduler</groupId>
            <artifactId>quartz</artifactId>
            <version>${quartz.version}</version>
        </dependency>
        <dependency>
            <groupId>org.quartz-scheduler</groupId>
            <artifactId>quartz-jobs</artifactId>
            <version>${quartz.version}</version>
        </dependency>
```

### 编写自定义配置类和自定义JobFactory
`JobFactoy`是Quartz提供的一个接口，其作用是用于创建`Job`实例，对应的在Spring Quartz中的实现类有`AdaptableJobFactory`和`SpringBeanJobFactory`;其中`AdaptableJobFactory`继承于`SpringBeanJobFactory`,我们看下其源码
```
public interface JobFactory {
    Job newJob(TriggerFiredBundle bundle, Scheduler scheduler) throws SchedulerException;
}


public class AdaptableJobFactory implements JobFactory {

	@Override
	public Job newJob(TriggerFiredBundle bundle, Scheduler scheduler) throws SchedulerException {
		try {
		    // 创建Job实例
			Object jobObject = createJobInstance(bundle);
			return adaptJob(jobObject);
		}
		catch (Exception ex) {
			throw new SchedulerException("Job instantiation failed", ex);
		}
	}

    // 这里可以看到,Job实例的创建都是通过getJobClass().newInstance()来创建的，并没有对应的代理类的创建
    // 所以使用Spring AOP编程的时候所有需要被代理的Job任务实际上都不会有代理类生成，是无法使用Spring AOP编程的
	protected Object createJobInstance(TriggerFiredBundle bundle) throws Exception {
		return bundle.getJobDetail().getJobClass().newInstance();
	}


	protected Job adaptJob(Object jobObject) throws Exception {
		if (jobObject instanceof Job) {
			return (Job) jobObject;
		}
		else if (jobObject instanceof Runnable) {
			return new DelegatingJob((Runnable) jobObject);
		}
		else {
			throw new IllegalArgumentException("Unable to execute job class [" + jobObject.getClass().getName() +
					"]: only [org.quartz.Job] and [java.lang.Runnable] supported.");
		}
	}
}



public class SpringBeanJobFactory extends AdaptableJobFactory implements SchedulerContextAware {

    //此处省略部分代码 ...


	@Override
	protected Object createJobInstance(TriggerFiredBundle bundle) throws Exception {
		 // 可以看到SpringBeanJobFactory中是使用父类AdaptableJobFactory的方法来创建Job实例的,所以也不会有代理类的创建
		Object job = super.createJobInstance(bundle);
		if (isEligibleForPropertyPopulation(job)) {
			BeanWrapper bw = PropertyAccessorFactory.forBeanPropertyAccess(job);
			MutablePropertyValues pvs = new MutablePropertyValues();
			if (this.schedulerContext != null) {
				pvs.addPropertyValues(this.schedulerContext);
			}
			pvs.addPropertyValues(bundle.getJobDetail().getJobDataMap());
			pvs.addPropertyValues(bundle.getTrigger().getJobDataMap());
			if (this.ignoredUnknownProperties != null) {
				for (String propName : this.ignoredUnknownProperties) {
					if (pvs.contains(propName) && !bw.isWritableProperty(propName)) {
						pvs.removePropertyValue(propName);
					}
				}
				bw.setPropertyValues(pvs);
			}
			else {
				bw.setPropertyValues(pvs, true);
			}
		}
		return job;
	}

	 //此处省略部分代码 ...

}

```

可以发现现有的Spring中对`JobFactory`的实现类都无法实现我们的AOP编程需求,所以就需要自定义一个`JobFactory`实现类了。如下

 - 自定义`JobFactory`实现类
```
/**
 - 自定义JobFactory,将创建Job实例的操作交给Spring管理
 - Created by Vio on 2017/11/8.
 */
public class MySpringBeanJobFactory extends AdaptableJobFactory {
    @Autowired
    private AutowireCapableBeanFactory beanFactory;

    @Override
    protected Object createJobInstance(TriggerFiredBundle bundle) throws Exception {
        Object jobInstance;
        Class<? extends Job> jobClass = bundle.getJobDetail().getJobClass();

        // 这里将Job的实例创建喝管理交给Spring，使用Spring的beanFactory去获取Job实例，
        // 获取不到的话就交由Spring的beanFactory自动创建一个,并根据名称自动注入和检查依赖关系
        // 这样的话Job中就可以实现自动注入和实现AOP编程
        try {
            jobInstance = beanFactory.getBean(jobClass);
        } catch (Exception e) {
            jobInstance = beanFactory.createBean(jobClass, AutowireCapableBeanFactory.AUTOWIRE_BY_NAME, true);
        }
        return jobInstance;
    }
}
```


 - 自定义Quartz配置

```
/**
 * Quartz配置类
 * Created by Vio on 2017/11/2.
 */
@Configuration
public class QuartzConfiguration {
    private static final String QUARTZ_CONFIG = "quartz.properties";

    @Bean
    public MySpringBeanJobFactory mySpringBeanJobFactory(){
        return new MySpringBeanJobFactory();
    }

    @Bean
    public SchedulerFactoryBean schedulerFactoryBean() {
        SchedulerFactoryBean schedulerFactoryBean = new SchedulerFactoryBean();

        // 配置使用自定义的JobFactory
        schedulerFactoryBean.setJobFactory(mySpringBeanJobFactory());
        schedulerFactoryBean.setAutoStartup(true);
        // 设置quartz配置文件路径
        schedulerFactoryBean.setConfigLocation(new ClassPathResource(QUARTZ_CONFIG));
        return schedulerFactoryBean;
    }

    @Bean
    public Scheduler scheduler() {
        return schedulerFactoryBean().getScheduler();
    }
}
```

### 动态定时任务（根据数据库的配置动态调整）
动态任务的实现其实只需要从数据库中读取相关的数据，然后使用Scheduler的相关API重新设置对应的任务的调度即可。不过任务初始启动的时候需要将数据库中的任务取出来。加入到调度器中。(Spring启动完成后执行某任务)实现如下:
```
/**
 * 定时任务启动器:
 * 应用启动时启动所有有效的定时任务
 * Created by Vio on 2017/11/7.
 */
@Component
public class QuartzTaskStarter implements ApplicationListener<ContextRefreshedEvent> {
    private static final Logger LOGGER = LoggerFactory.getLogger(QuartzTaskStarter.class);

    @Autowired
    private TaskSchedule taskSchedule;
    @Autowired
    private QuartzTaskService quartzTaskService;

    @Override
    public void onApplicationEvent(ContextRefreshedEvent event) {
        try {
            List<QuartzTaskEntity> tasks = quartzTaskService.selectAllValidTask();
            for (QuartzTaskEntity task : tasks) {
                taskSchedule.scheduleTask(task);
            }
            taskSchedule.startSchedule();
        } catch (Exception e) {
            LOGGER.error("Start all valid task fail.", e);
        }
    }
}


/**
 * 定时任务调度器
 * Created by Vio on 2017/11/2.
 */
@Component
public class TaskSchedule {
    private static final Logger LOGGER = LoggerFactory.getLogger(TaskSchedule.class);

    @Autowired
    private Scheduler scheduler;

    @Autowired
    private QuartzTaskService quartzTaskService;

    public ApiResult scheduleTask(QuartzTaskEntity task) {
        boolean scheduled = false;
        String msg = "Schedule Success!";
        try {
            Class<?> jobClass = Class.forName(task.getTaskClass());
            if (Job.class.isAssignableFrom(jobClass)) {
                JobDetail jobDetail = buildJobDetail(task, (Class<? extends Job>) jobClass);
                Trigger trigger = buildTrigger(task);

                scheduler.scheduleJob(jobDetail, trigger);
                scheduled = true;
                LOGGER.info(msg + "");
            }
        } catch (ClassNotFoundException e) {
            msg = "Schedule Fail! Class not found!";
            LOGGER.error(msg + "Task: " + task);
        } catch (SchedulerException e) {
            msg = "Schedule Fail! " + e.getMessage();
            LOGGER.error(msg + "Task: " + task, e);
        }
        return ApiResult.build(scheduled, msg, task);
    }

    // 此处省略部分代码...

    public ApiResult rescheduleTask(QuartzTaskEntity task) {
        boolean flag = false;
        String msg = "Reschedule task Success!";
        try {
            CronTrigger oldTrigger = (CronTrigger) scheduler.getTrigger(getTriggerKey(task));
            if (!oldTrigger.getCronExpression().equalsIgnoreCase(task.getCron())) {
                Trigger newTrigger = buildTrigger(task);
                scheduler.rescheduleJob(getTriggerKey(task), newTrigger);
            }
            flag = true;
        } catch (SchedulerException e) {
            msg = "Reschedule task Fail! " + e.getMessage();
            LOGGER.error(msg + "Task: " + task, e);
        }
        return ApiResult.build(flag, msg, task);
    }

    public synchronized void startSchedule() {
        try {
            if (scheduler.isShutdown()) {
                scheduler.start();
            }
        } catch (SchedulerException e) {
            LOGGER.error("Start scheduler fail.", e);
        }
    }

    // 此处省略部分代码...

    private JobDetail buildJobDetail(QuartzTaskEntity task, Class<? extends Job> clazz) {
        return JobBuilder.newJob(clazz).withIdentity(getTaskName(task), getTaskGroup(task)).build();
    }

    private Trigger buildTrigger(QuartzTaskEntity task) {
        return TriggerBuilder.newTrigger().withIdentity(getTaskName(task), getTaskGroup(task)).startNow().withSchedule(CronScheduleBuilder.cronSchedule(task.getCron())).build();
    }

    private JobKey getJobKey(QuartzTaskEntity task) {
        return JobKey.jobKey(getTaskName(task), getTaskGroup(task));
    }

    private TriggerKey getTriggerKey(QuartzTaskEntity task) {
        return TriggerKey.triggerKey(getTaskName(task), getTaskGroup(task));
    }

    private String getTaskName(QuartzTaskEntity task) {
        return StringUtils.isEmpty(task.getTaskName()) ? task.getTaskClass() : task.getTaskName();
    }

    private String getTaskGroup(QuartzTaskEntity task) {
        return StringUtils.isEmpty(task.getTaskGroup()) ? Scheduler.DEFAULT_GROUP : task.getTaskGroup();
    }
}

```

### 添加quartz.properties配置文件
```
# 简单实用内存类存储任务状态
# 更多配置使用请访问Quartz官网http://www.quartz-scheduler.org/documentation/quartz-2.2.x/configuration/ConfigMain.html
org.quartz.scheduler.instanceName = MyScheduler
org.quartz.threadPool.threadCount = 3
org.quartz.jobStore.class = org.quartz.simpl.RAMJobStore
```

---
## 整合Druid
现在Druid官方已经给出了一个starter的依赖。整合Druid已经非常简单了，只需要添加对应的依赖和配置即可

### 添加Druid依赖
```
        <!-- mysql -->
        <dependency>
            <groupId>mysql</groupId>
            <artifactId>mysql-connector-java</artifactId>
            <scope>runtime</scope>
        </dependency>
        <dependency>
            <groupId>com.alibaba</groupId>
            <artifactId>druid-spring-boot-starter</artifactId>
            <version>${druid-spring-boot-starter.version}</version>
        </dependency>
```

### 添加application.properties配置
```
spring.datasource.type=com.alibaba.druid.pool.DruidDataSource

# druid
# see more config about druid: https://github.com/alibaba/druid/tree/master/druid-spring-boot-starter
spring.datasource.druid.initial-size=5
spring.datasource.druid.max-active=20
spring.datasource.druid.min-idle=5
spring.datasource.druid.pool-prepared-statements=true
spring.datasource.druid.max-pool-prepared-statement-per-connection-size=20

spring.datasource.druid.max-wait=60000
spring.datasource.druid.time-between-eviction-runs-millis=60000
spring.datasource.druid.min-evictable-idle-time-millis=300000

spring.datasource.druid.validation-query=SELECT 1 FROM DUAL
spring.datasource.druid.test-on-borrow=false
spring.datasource.druid.test-on-return=false
spring.datasource.druid.test-while-idle=true

spring.datasource.druid.filters= stat,wall,slf4j
spring.datasource.druid.filter.stat.slow-sql-millis= 5000
```

---
## Spring单元测试集成H2数据库
在编写Dao的测试用例的时候，会对数据库中的数据进行操作。但是一般我们不想测试用例的运行对我们的开发库/测试服务库中的数据造成污染。那么可以考虑集成H2数据库来运行测试用例。集成如下:

### 添加依赖
```
        <!-- test -->
        <dependency>
            <groupId>com.h2database</groupId>
            <artifactId>h2</artifactId>
            <scope>test</scope>
        </dependency>
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-test</artifactId>
            <scope>test</scope>
        </dependency>
```

### 添加application.properties配置
此处的application.properties文件是**test**目录下的配置文件。

```
# 数据源连接
spring.datasource.driver-class-name=org.h2.Driver
spring.datasource.url=jdbc:h2:mem:test
spring.datasource.username=root
spring.datasource.password=

# 设置测试启动时执行的创建schema的脚本文件
spring.datasource.schema=classpath:db/schema.sql

# 设置测试启动时执行的插入数据的脚本文件
spring.datasource.data=classpath:db/data.sql
```

sql脚本文件需要自己创建并写入sql语句。其余的测试用例的编写和Spring 官方说明一致。

### 编写测试用例
```
/**
 * 定时任务实体服务测试类
 * Created by Vio on 2017/11/7.
 */
@RunWith(SpringRunner.class)
@SpringBootTest
public class QuartzServiceTest {
    @Autowired
    QuartzTaskService quartzTaskService;

    @Test
    public void testTaskExist() {
        QuartzTaskEntity quartzTaskEntity = new QuartzTaskEntity();
        quartzTaskEntity.setTaskClass("TestTask2");
        quartzTaskEntity.setState(0);
        int inserted = quartzTaskService.insert(quartzTaskEntity);
        Assert.assertEquals(1, inserted);

        Assert.assertEquals(true, quartzTaskService.taskExist(quartzTaskEntity));
    }
}
```

Done。大功告成。