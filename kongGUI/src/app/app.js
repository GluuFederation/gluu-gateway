'use strict';

angular.module('KongGUI', [
  'angular-loading-bar',
  'ngAnimate',
  'ui.bootstrap',
  'ui.sortable',
  'ui.router',
  'ngTouch',
  'toastr',
  'smart-table',
  "xeditable",
  'ui.slimscroll',
  'ngJsTree',
  'angular-progress-button-styles',

  'KongGUI.theme',
  'KongGUI.pages'
]).constant('urls', {
  KONG_ADMIN_API: 'https://gluu.local.org:8444',
  KONG_NODE_API: 'http://gluu.local.org:4040'
}).filter('unique', function() {
  return function (arr, field) {
    var o = {}, i, l = !!arr ? arr.length : 0, r = [];
    for(i=0; i<l;i+=1) {
      o[arr[i][field]] = arr[i];
    }
    for(i in o) {
      r.push(o[i]);
    }
    return r;
  };
});