(function () {
  'use strict';

  angular.module('KongGUI.pages.api')
    .factory('apiService', apiService);

  /** @ngInject */
  function apiService($http, urls) {
    var service = {
      addAPI: addAPI,
      updateAPI: updateAPI,
      removeAPI: removeAPI,
      getAPI: getAPI,
      getPlugins: getPlugins
    };

    function getAPI(onSuccess, onError) {
      return $http.get(urls.KONG_NODE_API + '/api/apis').then(onSuccess).catch(onError);
    }

    function addAPI(formData, onSuccess, onError) {
      return $http.post(urls.KONG_NODE_API + '/api/apis', formData).then(onSuccess).catch(onError);
    }

    function updateAPI(formData, onSuccess, onError) {
      return $http.put(urls.KONG_NODE_API + '/api/apis', formData).then(onSuccess).catch(onError);
    }

    function removeAPI(id, onSuccess, onError) {
      return $http.delete(urls.KONG_NODE_API + '/api/apis/' + id).then(onSuccess).catch(onError);
    }

    function getPlugins(api_id, onSuccess, onError) {
      return $http.get(urls.KONG_NODE_API + '/api/apis/' + api_id + '/plugins').then(onSuccess).catch(onError);
    }

    return service;
  }
})();
