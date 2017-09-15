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
    vm.deleteScript = deleteScript;
    vm.showScript = showScript;
    vm.addToScope = addToScope;

    init();

    function init() {
      vm.getScripts();
    }

    function showScript(o) {
      $uibModal.open({
        animation: true,
        templateUrl: 'app/pages/umaScript/showScript.modal.html',
        size: 'lg',
        controller: ['$uibModalInstance', 'scriptData', ShowScriptController],
        controllerAs: '$ctrl',
        resolve: {
          scriptData: function () {
            return o;
          }
        }
      }).result.then(function (result) {
      });
    }

    function ShowScriptController($uibModalInstance, scriptData) {
      var vm = this;
      vm.script = scriptData
    }

    function addToScope(o) {
      $uibModal.open({
        animation: true,
        templateUrl: 'app/pages/umaScript/scope.modal.html',
        size: 'lg',
        controller: ['$uibModalInstance', 'scriptData', 'umaScriptService', 'toastr', ScopeController],
        controllerAs: '$ctrl',
        resolve: {
          scriptData: function () {
            return o;
          }
        }
      }).result.then(function (result) {
      });
    }

    function ScopeController($uibModalInstance, scriptData, umaScriptService, toastr) {
      var vm = this;
      vm.scopes = [];
      vm.selectedScope = [];

      vm.addScope = addScope;

      getScopes();

      function getScopes() {
        umaScriptService.getScope(onSuccess, onError);
        function onSuccess(response) {
          vm.scopes = response.data
        }

        function onError(error) {
          toastr.error(error.data.message, 'Scope', {})
        }
      }

      function addScope() {
        umaScriptService.addScope({scopeInums: vm.selectedScope, scriptInum: scriptData.inum}, onSuccess, onError);
        function onSuccess(response) {
          toastr.success('Added Successfully', 'Scope', {});
          $uibModalInstance.close(response.data);
        }

        function onError(error) {
          toastr.error(error.data.message, 'Scope', {});
        }
      }
    }

    function openManageScript(o) {
      $uibModal.open({
        animation: true,
        templateUrl: 'app/pages/umaScript/umaScript.modal.html',
        size: 'lg',
        controller: 'UMAScriptManageController',
        controllerAs: '$ctrl',
        resolve: {
          scriptData: function () {
            return o;
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
        toastr.error(error.data.message, 'Script', {})
      }
    }

    function deleteScript(inum) {
      if (!confirm("Are sure want to delete script?")) {
        return false;
      }

      umaScriptService.deleteScript(inum, onSuccess, onError);
      function onSuccess(response) {
        if (response.data.result) {
          toastr.success('Deleted Successfullu', 'Script', {});
          vm.getScripts();
        } else {
          toastr.error('Failed', 'Script', {})
        }
      }

      function onError(error) {
        toastr.error('Failed', 'Script', {})
      }
    }
  }
})();
