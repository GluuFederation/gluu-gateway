(function () {
  'use strict';

  angular.module('KongGUI.pages.oxdWeb')
    .factory('oxdWebService', oxdWebService);

  /** @ngInject */
  function oxdWebService($http, urls) {
    var service = {
      checkConnection: checkConnection,
    };

    function checkConnection(data, onSuccess, onError) {
      return $http.post(urls.KONG_NODE_API + '/api/health-check', data).then(onSuccess).catch(onError);
    }

    return service;
  }
})();
