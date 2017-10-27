(function () {
  'use strict';

  angular.module('KongGUI.pages.api')
    .controller('ManageAPIController', ManageAPIController);

  /** @ngInject */
  function ManageAPIController($stateParams, $scope, $filter, toastr, apiService) {
    var vm = this;
    vm.modalAPI = $stateParams.oAPI || {};
    vm.pushAPI = pushAPI;
    if (!!vm.modalAPI.hosts) {
      vm.modalAPI.hosts = vm.modalAPI.hosts.join(",");
      setTimeout(function () {
        $('#hosts').tagsinput('add', vm.modalAPI.hosts);
      });
    }

    function pushAPI(isFormValid) {
      if (!isFormValid) {
        return false;
      }

      if (!!vm.modalAPI.id) {
        apiService.updateAPI(JSON.stringify(vm.modalAPI), onSuccess, onError);
      } else {
        apiService.addAPI(JSON.stringify(vm.modalAPI), onSuccess, onError);
      }

      function onSuccess(response) {
        debugger;
        vm.modalAPI = response.data
        toastr.success('Saved successfully', 'API', {});
      }

      function onError(error) {
        toastr.error(error.data.message, 'API', {})
      }
    }
  }
})();
