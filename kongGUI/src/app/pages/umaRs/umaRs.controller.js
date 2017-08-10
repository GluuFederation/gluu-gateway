(function () {
  'use strict';

  angular.module('KongGUI.pages.umaRs')
    .controller('UMARsController', UMARsController);

  /** @ngInject */
  function UMARsController($scope, $filter, $state, toastr, umaRsService, apiService) {
    var vm = this;
    vm.modelPlugin = {
      name: "kong-uma-rs",
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

      umaRsService.addPlugin(vm.api_id, vm.modelPlugin, onSuccess, onError);
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
