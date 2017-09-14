(function () {
  'use strict';

  angular.module('KongGUI.pages.umaScript')
    .factory('umaScriptService', umaScriptService);

  /** @ngInject */
  function umaScriptService($http, urls) {
    var service = {
      addScript: addScript,
      getScript: getScript
    };

    function addScript(formData, onSuccess, onError) {
      return $http.post(urls.KONG_NODE_API + '/api/scripts', formData).then(onSuccess).catch(onError);
    }

    function getScript(onSuccess, onError) {
      return $http.get(urls.KONG_NODE_API + '/api/scripts').then(onSuccess).catch(onError);
    }

    return service;
  }
})();