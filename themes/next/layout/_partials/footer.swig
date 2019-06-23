<div class="copyright" >
  {% set current = date(Date.now(), "YYYY") %}
  &copy; {% if theme.since and theme.since != current %} {{ theme.since }} - {% endif %}
  <span itemprop="copyrightYear">{{ current }}</span>
  <span class="with-love">
    <i class="fa fa-{{ theme.authoricon }}"></i>
  </span>
  <span class="author" itemprop="copyrightHolder">{{ config.author }}</span>
</div>

{% if theme.cd_by %}
  <div class="powered-by">CI/CD by
    <a class="theme-link" href="http://drone.vioao.site" style="font-weight: bold">Vioao's Drone</a>
  </div>
{% endif %}

{% if theme.hosted_by %}
  <div class="theme-info">Hosted by
    <a class="theme-link" href="https://coding.net/help/doc/pages/index.html" style="font-weight: bold">Coding Pages</a>
  </div>
{% endif %}

{% if theme.copyright %}
<div class="powered-by">
  {{ __('footer.powered', '<a class="theme-link" href="https://hexo.io">Hexo</a>') }}
</div>

<div class="theme-info">
  {{ __('footer.theme') }} -
  <a class="theme-link" href="https://github.com/iissnan/hexo-theme-next">
    NexT.{{ theme.scheme }}
  </a>
</div>
{% endif %}


