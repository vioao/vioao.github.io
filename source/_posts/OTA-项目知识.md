---
title: OTA 项目知识

date: 2019-07-10 09:54:30
tags: [OTA]
categories: [工作记录]
---

### 名词解释

- [OTA](https://baike.baidu.com/item/%E5%9C%A8%E7%BA%BF%E6%97%85%E6%B8%B8/4657971?fromtitle=OTA&fromid=13871690)  
  Online Travel Agency：在线旅游（OTA，全称为Online Travel Agency），是旅游电子商务行业的专业词语。
  指“旅游消费者通过网络向旅游服务提供商预定旅游产品或服务，并通过网上支付或者线下付费，即各旅游主体可以通过网络进行产品营销或产品销售”。

- [LCC](https://zh.wikipedia.org/wiki/%E4%BD%8E%E6%88%90%E6%9C%AC%E8%88%AA%E7%A9%BA%E5%85%AC%E5%8F%B8)  
   Low-cost carrier：低成本航空公司(廉航)  
   [List of LCC](https://en.wikipedia.org/wiki/List_of_low-cost_airlines)

- [PNR](https://baike.baidu.com/item/PNR)  
   Passenger Name Record：旅客订座记录，它反映了旅客的航程，航班座位占用的数量，及旅客信息。适用民航订座系统

- [GDS](https://baike.baidu.com/item/GDS/16824?fr=aladdin)  
   Global Distribution System: 全球分销系统，是应用于民用航空运输及整个旅游业的大型计算机信息服务系统。
   通过GDS，遍及全球的旅游销售机构可以及时地从航空公司、旅馆、租车公司、旅游公司获取大量的与旅游相关的信息，从而为顾客提供快捷、便利、可靠的服务。
   目前主要的 GDS。1A-Amadeus、1B-Sabre/Abacus、1E-TravelSky(中航信)、1G-伽利略。
   <!-- more -->
   {% asset_img gds.png GDS %}

- [CRS](https://wenku.baidu.com/view/6a67bda2ad02de80d5d8401a.html)  
  Computer Reservation System，即计算机分销系统。CRS 主要功能是为代理人提供航班可利用情况查询、航段销售、订座记录、电子客票预订，旅游产品等服务。

- [ICS](https://wenku.baidu.com/view/6a67bda2ad02de80d5d8401a.html)  
  Inventory Control System，即航空公司人员使用的航空公司订座系统。ICS 是一个集中式、多航空公司的系统。每个航空公司享有自己独立的数据库、
  独立的用户群、独立的控制和管理方式，各种操作均可以加以个性化，包括航班班期、座位控制、运价及收益管理、航空联盟、销售控制参数等信息和一整套完备的订座功能引擎。

- [DCS](https://wenku.baidu.com/view/6a67bda2ad02de80d5d8401a.html)  
  Departure Control System，即机场人员使用的离港控制系统。DCS 是为机场提供旅客值机、配载平衡、航班数据控制、登机控制联程值机等信息服务，
  可以满足值机控制、装载控制、登机控制以及信息交换等机场旅客服务。

- [PCC/OID](https://hoteliers.zendesk.com/hc/en-gb/articles/209534685-What-is-the-Office-ID-Pseudo-City-Code-)  
   PCC：Pseudo City Code  
   OID：Office ID  
   The Pseudo City Code (PCC) or Office ID (OID) is an alpha-numeric identifier for a corporate user of the GDS, 
   typically a travel agency. Example of a PCC/OID: "AMSX1234P"

- [IATA](https://zh.wikipedia.org/wiki/%E5%9C%8B%E9%9A%9B%E8%88%AA%E7%A9%BA%E9%81%8B%E8%BC%B8%E5%8D%94%E6%9C%83)  
  International Air Transport Association：国际航空运输协会

- [PTC](https://support.travelport.com/webhelp/uapi/Content/Air/Shared_Air_Topics/Passenger_Type_Codes.htm)  
  Passenger Type Codes (PTCs)：乘客类型代码，可以表明乘客的年龄、国籍等。常用的 PTCs：  
  ADT：Adult  
  CHD：Child  
  INF：Infant without a seat  
  INS：Infant with a seat  
  UNN：Unaccompanied Child  

- [PTL](https://aerocrs.zendesk.com/hc/en-us/articles/205222985-PTL-and-TTL)  
  Payment Time Limit

- [TTL](https://aerocrs.zendesk.com/hc/en-us/articles/205222985-PTL-and-TTL)  
  Ticketing Time Limit
  
- [L2B Ratio](https://whatis.techtarget.com/definition/look-to-book-ratio)  
  Look To Book Ratio：查看数和实际下单数的比例

- [TST](https://servicehub.amadeus.com/c/portal/view-solution/780102/en_US/transitional-stored-ticket-tst-overview)  
  Transitional Stored Ticket，记录了讴一个 PNR 的所有费用信息。
  
- [ATPCO](https://www.atpco.net/about?utm_source=ATPCO_home&utm_medium=Carousel&utm_campaign=who_we_are_CTA_Home_Carousel)  
  Airline Tariff Publishing Company，对 GDS 及其相关机构提供数据及技术服务

- [NDC](https://www.iata.org/whatwedo/airline-distribution/ndc/Pages/default.aspx)  
  New Distribution Capability，由 IATA 创建的新分销能力 (NDC) 是一种基于 XML 的数据传输标准（对旅游行业持有重大承诺），
  能够使旅游公司（从航空公司到旅游销售商）在旅行分销与营销方面不断发展。
  
- [CSD](https://www.iata.org/whatwedo/cargo/security/Pages/csd.aspx)   
  The Consignment Security Declaration (CSD) provides regulators with an audit trail of how, when and by whom cargo has 
been secured along the supply chain. 

----
### 核心流程

- 下单流程
   {% asset_img booking.png Booking Funnel %}
