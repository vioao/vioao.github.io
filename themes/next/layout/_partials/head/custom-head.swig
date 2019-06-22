{#
Custom head.
#}

{% if theme.google_adsense !== '' %}
<script async src="https://pagead2.googlesyndication.com/pagead/js/adsbygoogle.js"></script>
<script>
  (adsbygoogle = window.adsbygoogle || []).push({
    google_ad_client: "{{ theme.google_adsense }}",
    enable_page_level_ads: true
  });
</script>
{% endif %}
