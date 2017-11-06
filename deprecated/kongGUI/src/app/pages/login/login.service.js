(function () {
  'use strict';

  angular.module('KongGUI.pages.login')
    .factory('loginService', loginService);

  /** @ngInject */
  function loginService($http, urls) {
    var service = {
      getAuthorizeURL: getAuthorizeURL,
      login: login
    };

    function getAuthorizeURL(onSuccess, onError) {
      return $http.get(urls.KONG_NODE_API + '/login').then(onSuccess).catch(onError);
    }

    function login(data, onSuccess, onError) {
      return $http.get(urls.KONG_NODE_API + '/login?code=' + data.code + '&state=' + data.state).then(onSuccess).catch(onError);
    }

    return service;
  }
})();
