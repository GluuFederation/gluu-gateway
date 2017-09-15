(function () {
  'use strict';

  angular.module('KongGUI.pages.umaScript')
    .factory('umaScriptService', umaScriptService);

  /** @ngInject */
  function umaScriptService($http, urls) {
    var service = {
      addScript: addScript,
      getScript: getScript,
      deleteScript: deleteScript,
      updateScript: updateScript,
      getScope: getScope,
      addScope: addScope
    };

    function addScript(formData, onSuccess, onError) {
      return $http.post(urls.KONG_NODE_API + '/api/scripts', formData).then(onSuccess).catch(onError);
    }

    function updateScript(inum, formData, onSuccess, onError) {
      return $http.put(urls.KONG_NODE_API + '/api/scripts/' + inum, formData).then(onSuccess).catch(onError);
    }

    function getScript(onSuccess, onError) {
      return $http.get(urls.KONG_NODE_API + '/api/scripts').then(onSuccess).catch(onError);
    }

    function deleteScript(inum, onSuccess, onError) {
      return $http.delete(urls.KONG_NODE_API + '/api/scripts/' + inum).then(onSuccess).catch(onError);
    }

    function getScope(onSuccess, onError) {
      return $http.get(urls.KONG_NODE_API + '/api/scopes').then(onSuccess).catch(onError);
    }

    function addScope(formData, onSuccess, onError) {
      return $http.post(urls.KONG_NODE_API + '/api/scopes', formData).then(onSuccess).catch(onError);
    }

    return service;
  }
})();