(function () {
  'use strict';

  angular.module('KongGUI.pages.oxdWeb')
    .controller('OXDWebController', OXDWebController);

  /** @ngInject */
  function OXDWebController($scope, $filter, toastr, oxdWebService, $uibModal, urls) {
    var vm = this;

    //Export the modules for view.
    vm.checkConnection = checkConnection;

    // definitions
    function checkConnection() {
      oxdWebService.checkConnection({url: vm.oxdweb + '/health-check'}, onSuccess, onError);

      function onSuccess(response) {
        toastr.success('Connected successfully', 'OXD-Web', {});
      }

      function onError(error) {
        toastr.error('Failed to connect', 'OXD-Web', {});
      }
    }
  }
})();
