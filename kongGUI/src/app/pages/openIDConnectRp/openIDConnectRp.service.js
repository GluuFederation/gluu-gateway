(function () {
  'use strict';

  angular.module('KongGUI.pages.openIDConnectRp')
    .factory('openIDConnectRpService', openIDConnectRpService);

  /** @ngInject */
  function openIDConnectRpService($http, urls) {
    var service = {
      addPlugin: addPlugin
    };

    function addPlugin(api_id, formData, onSuccess, onError) {
      return $http.post(urls.KONG_ADMIN_API + '/apis/' + api_id + '/plugins', formData).then(onSuccess).catch(onError);
    }

    return service;
  }
})();