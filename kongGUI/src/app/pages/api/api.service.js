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
      var auth = $http.defaults.headers.common.Authorization;
      delete $http.defaults.headers.common.Authorization;
      return $http.get(urls.KONG_ADMIN_API + '/apis', {headers: {}}).then(onSuccess).catch(onError);
      $http.defaults.headers.common.Authorization = auth;
    }

    function addAPI(formData, onSuccess, onError) {
      var auth = $http.defaults.headers.common.Authorization;
      delete $http.defaults.headers.common.Authorization;
      return $http.post(urls.KONG_ADMIN_API + '/apis', formData).then(onSuccess).catch(onError);
      $http.defaults.headers.common.Authorization = auth;
    }

    function updateAPI(formData, onSuccess, onError) {
      var auth = $http.defaults.headers.common.Authorization;
      delete $http.defaults.headers.common.Authorization;
      return $http.put(urls.KONG_ADMIN_API + '/apis', formData).then(onSuccess).catch(onError);
      $http.defaults.headers.common.Authorization = auth;
    }

    function removeAPI(id, onSuccess, onError) {
      var auth = $http.defaults.headers.common.Authorization;
      delete $http.defaults.headers.common.Authorization;
      return $http.delete(urls.KONG_ADMIN_API + '/apis/' + id).then(onSuccess).catch(onError);
      $http.defaults.headers.common.Authorization = auth;
    }

    function getPlugins(api_id, onSuccess, onError) {
      var auth = $http.defaults.headers.common.Authorization;
      delete $http.defaults.headers.common.Authorization;
      return $http.get(urls.KONG_ADMIN_API + '/apis/' + api_id + '/plugins').then(onSuccess).catch(onError);
      $http.defaults.headers.common.Authorization = auth;
    }

    return service;
  }
})();
