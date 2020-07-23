---
title: 关于我
date: 2017-05-19 20:59:45
---

<!-- <center> <h3>Java软件工程师</h3> </centrt> -->


> 假如我今天死掉，恐怕就不能像维特根斯坦一样说道：我度过了美好的一生，也不能像斯汤达一样说：活过，爱过，写过。
我很怕落到什么都说不出的结果，所以正在努力工作。  
众生皆苦，求而不得。  
Anyway，前进吧。
<p align="right"> Vioao </p>

<div class="links-of-author motion-element" style="display: inline-block; opacity: 1; margin-top: 0">
{% if theme.social %}
  {% for name, link in theme.social %}
    <span class="links-of-author-item">
      <a href="{{ link }}" target="_blank" title="{{ name }}">
        {% if theme.social_icons.enable %}
          <i class="fa fa-fw fa-{{ theme.social_icons[name] | default('globe') | lower }}"></i>
        {% endif %}
        {{ name }}
      </a>
    </span>
  {% endfor %}
{% endif %}
</div>