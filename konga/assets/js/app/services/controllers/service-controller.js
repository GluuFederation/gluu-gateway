/**
 * This file contains all necessary Angular controller definitions for 'frontend.login-history' module.
 *
 * Note that this file should only contain controllers and nothing else.
 */
(function () {
  'use strict';

  angular.module('frontend.services')
    .controller('ServiceController', [
      '$scope', '$rootScope', '$state', 'SettingsService', '$log', '_service',
      function controller($scope, $rootScope, $state, SettingsService, $log, _service) {

        $scope.service = _service.data;

        // Fix empty object properties
        fixProperties();

        $state.current.data.pageName = "Service " + ( $scope.service.name || $scope.service.id );
        $scope.activeSection = 0;
        $scope.sections = [
          {
            name: 'Service Details',
            icon: 'mdi mdi-information-outline',
            isVisible: true
          },
          {
            name: 'Routes',
            icon: 'mdi mdi-directions-fork',
            isVisible: true
          },
          {
            name: 'Plugins',
            icon: 'mdi mdi-power-plug',
            isVisible: true
          },
          {
            name: 'Eligible consumers',
            icon: 'mdi mdi-account-multiple-outline',
            isVisible: true
          },
        ];


        $scope.showSection = function (index) {
          $scope.activeSection = index
        };

        function fixProperties() {
          var problematicProperties = ['uris', 'hosts', 'methods'];
          problematicProperties.forEach(function (property) {
            if ($scope.service[property] && isObject($scope.service[property]) && !Object.keys($scope.service[property]).length) {
              $scope.service[property] = ""
            }
          })
        }

        function isObject(obj) {
          return obj === Object(obj);
        }

        $scope.$on('user.node.updated', function (node) {
          $state.go('services')
        });
      }
    ]);
}());
