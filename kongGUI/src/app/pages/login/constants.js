(function () {
  'use strict';

  angular.module('KongGUI.pages.login')
    .constant('urls', {
      BASE: 'https://localhost:3000',
      AUTH_URL: 'https://localhost:3000/login.html',
      KONG_NODE_API: 'https://gluu.local.org:4040'
    });
})();