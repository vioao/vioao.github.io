<div class="powered-by" >
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

{% if theme.social_in_footer %}
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


