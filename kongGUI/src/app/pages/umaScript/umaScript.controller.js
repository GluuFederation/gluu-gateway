(function () {
  'use strict';

  angular.module('KongGUI.pages.umaScript')
    .controller('UMAScriptController', UMAScriptController);

  /** @ngInject */
  function UMAScriptController($scope, $filter, $state, toastr, umaScriptService, $uibModal) {
    var vm = this;

    vm.scripts = [];

    vm.getScripts = getScripts;
    vm.openManageScript = openManageScript;

    init();

    function init() {
      vm.getScripts();
    }

    function openManageScript() {
      $uibModal.open({
        animation: true,
        templateUrl: 'app/pages/umaScript/umaScript.modal.html',
        size: 'lg',
        controller: 'UMAScriptManageController',
        controllerAs: '$ctrl',
        resolve: {
          scriptData: function () {
            return null;
          }
        }
      }).result.then(function (result) {
        vm.getScripts();
      });
    }

    function getScripts() {
      umaScriptService.getScript(onSuccess, onError);
      function onSuccess(response) {
       vm.scripts = response.data
      }

      function onError(error) {
        toastr.error(error.data.message, 'Plugin', {})
      }
    }
  }
})();
