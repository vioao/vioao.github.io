hexo.extend.filter.register('post_permalink', function(data){
  if(!data.seo_title) {
    data.seo_title = data.title
  }
}, 0);