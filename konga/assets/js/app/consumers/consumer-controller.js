/**
 * This file contains all necessary Angular controller definitions for 'frontend.admin.login-history' module.
 *
 * Note that this file should only contain controllers and nothing else.
 */
(function () {
  'use strict';

  angular.module('frontend.consumers')
    .controller('ConsumerController', [
      '_', '$scope', '$log', '$state', '_consumer', '$rootScope', 'Semver',
      function controller(_, $scope, $log, $state, _consumer, $rootScope, Semver) {

        $scope.consumer = _consumer.data;
        $state.current.data.pageName = "CONSUMER: " + ($scope.consumer.username || $scope.consumer.id)
        $scope.activeSection = 0;
        $scope.sections = [
          {
            id: 'details',
            name: 'Details',
            icon: 'mdi-information-outline'
          },
          {
            id: 'groups',
            name: 'Groups',
            icon: 'mdi-account-multiple-outline'
          },
          {
            id: 'plugins',
            name: 'Plugins',
            icon: 'mdi-power-plug'
          }
        ];

        $scope.onTabsSelected = function (index) {
          $scope.activeSection = index;
        };

        $scope.$on('user.node.updated', function (node) {
          $state.go('consumers');
        });
      }
    ])
}());
