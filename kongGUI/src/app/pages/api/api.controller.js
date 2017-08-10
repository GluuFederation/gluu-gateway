(function () {
  'use strict';

  angular.module('KongGUI.pages.api')
    .controller('APIController', APIController);

  /** @ngInject */
  function APIController($scope, $filter, toastr, apiService, $uibModal, urls) {
    var vm = this;
    vm.apis = vm.displayedCollection = undefined;

    //Export the modules for view.
    vm.removeAPI = removeAPI;
    vm.getAPI = getAPI;
    vm.openAPIModal = openAPIModal;
    vm.openPluginModal = openPluginModal;
    // init
    vm.getAPI();

    function getAPI() {
      apiService.getAPI(onSuccess, onError);
      function onSuccess(response) {
        if (response.data && response.data.total > 0) {
          vm.apis = response.data.data;
          vm.displayedCollection = angular.copy(vm.apis);
        }
      }

      function onError(error) {
        toastr.error(error.data.message, 'APIs', {})
      }
    }

    function openAPIModal(APIData) {
      vm.APIModal = $uibModal.open({
        animation: true,
        templateUrl: 'app/pages/api/api.manage.modal.html',
        size: 'md',
        controller: ['$uibModalInstance', 'APIData', 'apiService', createAPIController],
        controllerAs: '$ctrl',
        resolve: {
          APIData: function () {
            return APIData;
          }
        }
      });

      vm.APIModal.result.then(function (newAPI) {
        var index = _.findIndex(vm.apis, {id: newAPI.id});
        if (index >= 0) {
          vm.apis[index] = newAPI;
        } else {
          if (vm.apis === undefined) {
            vm.apis = vm.displayedCollection = [];
          }
          vm.apis.push(newAPI);
        }

        vm.displayedCollection = angular.copy(vm.apis);
      });
    }

    function createAPIController($uibModalInstance, APIData, apiService) {
      var vm = this;
      vm.modalAPI = {};
      if (APIData) {
        vm.modalAPI.id = APIData.id;
        vm.modalAPI.name = APIData.name;
        vm.modalAPI.upstream_url = APIData.upstream_url;
        vm.modalAPI.hosts = APIData.hosts.join(",");
        vm.modalAPI.created_at = APIData.created_at;
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
          toastr.success('Saved successfully', 'API', {});
          if (response.data) {
            $uibModalInstance.close(response.data);
          }
        }

        function onError(error) {
          toastr.error(error.data.message, 'API', {})
        }
      }

      function stateChanged() {
        vm.cities = vm.stateCityList[vm.modalAPI.state];
      }

      vm.pushAPI = pushAPI;
      vm.stateChanged = stateChanged;
    }

    function openPluginModal(APIData) {
      vm.APIModal = $uibModal.open({
        animation: true,
        templateUrl: 'app/pages/api/plugin.modal.html',
        size: 'md',
        controller: ['$uibModalInstance', 'APIData', 'apiService', pluginController],
        controllerAs: '$ctrl',
        resolve: {
          APIData: function () {
            return APIData;
          }
        }
      });
    }

    function pluginController($uibModalInstance, APIData, apiService) {
      var vm = this;
      vm.plugins = [];
      vm.getPlugins = getPlugins;

      //init
      vm.getPlugins();

      function getPlugins() {
        apiService.getPlugins(APIData.id, onSuccess, onError);

        function onSuccess(response) {
          vm.plugins = response.data.data;
        }

        function onError(error) {
          toastr.error(error.data.message, 'API', {})
        }
      }
    }

    function removeAPI(oAPI) {
      if (!confirm('Are you sure you want to remove this API?')) {
        return null;
      }
      apiService.removeAPI(oAPI.id, onSuccess, onError);

      function onSuccess(response) {
        _.remove(vm.apis, {id: oAPI.id});
        vm.displayedCollection = angular.copy(vm.apis);
        toastr.success('Removed successfully', 'API', {});
      }

      function onError(error) {
        toastr.error(error.data.message, 'API', {});
      }
    }
  }
})();
