{% if theme.footer.ci_cd %}
  <div class="powered-by">CI/CD by
    <a class="theme-link theme-link-bottom" target="_blank" href="http://drone.vioao.site">Vioao's Drone</a>
  </div>
{% endif %}

{% if theme.footer.social_in_footer %}
  <span> | </span>
  <div class="powered-by">Social:
    {% for name, link in theme.social %}
        <a class="theme-link theme-link-bottom" href="{{ link }}" target="_blank" title="{{ name }}" >
          {{ name }}
        </a>
        <div style="margin-left: 5px; display: inline-block"> </div>
    {% endfor %}
  </div>
{% endif %}
