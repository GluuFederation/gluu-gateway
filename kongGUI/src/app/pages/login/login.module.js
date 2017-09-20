(function () {
  'use strict';

  angular.module('KongGUI.pages.login', [
    'angular-loading-bar',
    'ngAnimate',
    'ui.bootstrap',
    'ngStorage',
    'toastr'
  ]).config(function ($locationProvider) {
    $locationProvider.html5Mode({
      enabled: true,
      requireBase: false,
      rewriteLinks: true
    });
  }).constant('urls', {
    BASE: 'https://localhost:3000',
    AUTH_URL: 'https://localhost:3000/login.html',
    KONG_ADMIN_API: 'https://gluu.local.org:8444',
    KONG_NODE_API: 'https://gluu.local.org:4040'
  });
})();