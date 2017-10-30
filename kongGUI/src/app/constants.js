(function () {
  'use strict';

  angular.module('KongGUI')
    .constant('urls', {
      AUTH_URL: 'https://localhost:3000/login.html',
      KONG_NODE_API: 'https://gluu.local.org:4040'
    });
})();