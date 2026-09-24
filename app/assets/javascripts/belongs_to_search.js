/* eslint-disable */
// belongs_to form with auto-preload on focus
$(function () {
  $('.field-unit--belongs-to-search select').each(
    function initializeSelectize(index, element) {
      var $element = $(element);
      var rawUrl = $element.data('url') || '';
      var separator = rawUrl.indexOf('?') === -1 ? '?search=' : '&search=';
      var searchUrl = rawUrl + separator;

      $element.selectize({
        valueField: 'id',
        labelField: 'dashboard_display_name',
        searchField: 'dashboard_display_name',
        create: false,
        preload: 'focus',
        searchUrl: searchUrl,

        load: function (query, callback) {
          var url = this.settings.searchUrl + encodeURIComponent(query || '');
          $.ajax({
            url: url,
            type: 'GET',
            dataType: 'json',
            error: function () {
              callback();
            },
            success: function (res) {
              callback(res.resources || []);
            },
          });
        },
      });
    }
  );
});
