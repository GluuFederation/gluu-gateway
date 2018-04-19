/**
 * This file contains all necessary Angular controller definitions for 'frontend.admin.login-history' module.
 *
 * Note that this file should only contain controllers and nothing else.
 */
(function () {
  'use strict';

  angular.module('frontend.consumers')
    .controller('RestrictAPIController', [
      '_', '$scope', '$rootScope', '$log', 'ConsumerService', 'MessageService', '$uibModalInstance', '_apis', '_selected_api', '$localStorage', '$uibModal',
      function controller(_, $scope, $rootScope, $log, ConsumerService, MessageService, $uibModalInstance, _apis, _selected_api, $localStorage, $uibModal) {
        $scope.apis = _apis.data;
        $scope.orApis = angular.copy($scope.apis);
        $scope.create = create;
        $scope.searchText = "";
        $scope.searchAPI = searchAPI;

        $scope.selected_apis = _selected_api || [];

        $scope.close = function () {
          $uibModalInstance.dismiss()
        };

        function create() {
          $uibModalInstance.close($scope.selected_apis);
        }

        function searchAPI() {
          $scope.apis = $scope.orApis.filter(function (o) {
            return o.name.includes($scope.searchText);
          })
        }
      }
    ])
}());
