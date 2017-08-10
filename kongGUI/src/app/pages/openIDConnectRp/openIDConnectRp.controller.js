(function () {
  'use strict';

  angular.module('KongGUI.pages.openIDConnectRp')
    .controller('OpenIDConnectRpController', OpenIDConnectRpController);

  /** @ngInject */
  function OpenIDConnectRpController($scope, $filter, $state, toastr, openIDConnectRpService, apiService) {
    var vm = this;
    vm.modelPlugin = {
      name: "kong-openid-rp",
      config: {}
    };
    vm.apis = [];

    //Export the modules for view.
    vm.addPlugin = addPlugin;
    vm.getAPI = getAPI;

    //init
    vm.getAPI();

    function addPlugin(isValid) {
      if (!isValid) {
        return false;
      }

      openIDConnectRpService.addPlugin(vm.api_id, vm.modelPlugin, onSuccess, onError);
      function onSuccess(response) {
        toastr.success('Saved successfully', 'Plugin', {});
        $state.go('api');
      }

      function onError(error) {
        toastr.error(error.data.message, 'Plugin', {})
      }
    }

    function getAPI() {
      apiService.getAPI(onSuccess, onError);
      function onSuccess(response) {
        if (response.data && response.data.total > 0) {
          vm.apis = response.data.data;
        }
      }

      function onError(error) {
        toastr.error(error.data.message, 'Plugin', {})
      }
    }

  }
})();
