/**
 * This file contains all necessary Angular controller definitions for 'frontend.admin.login-history' module.
 *
 * Note that this file should only contain controllers and nothing else.
 */
(function () {
  'use strict';

  angular.module('frontend.upstreams')
    .controller('UpstreamsController', [
      '_', '$scope', '$rootScope', '$q', '$log', 'UserModel',
      'SocketHelperService', 'UserService', 'SettingsService', 'MessageService',
      '$state', '$uibModal', 'DialogService', 'Upstream', '$localStorage',
      'ListConfig',
      function controller(_, $scope, $rootScope, $q, $log, UserModel,
                          SocketHelperService, UserService, SettingsService, MessageService,
                          $state, $uibModal, DialogService, Upstream, $localStorage,
                          ListConfig) {


        Upstream.setScope($scope, false, 'items', 'itemCount');
        $scope = angular.extend($scope, angular.copy(ListConfig.getConfig('upstream', Upstream)));
        $scope.user = UserService.user();


        $scope.openCreateItemModal = function () {
          if ($scope.openingModal) return;

          $scope.openingModal = true;
          setTimeout(function () {
            $scope.openingModal = false;
          }, 1000);

          $uibModal.open({
            animation: true,
            ariaLabelledBy: 'modal-title',
            ariaDescribedBy: 'modal-body',
            templateUrl: 'js/app/upstreams/add-upstream-modal.html?v=' + $rootScope.konga_version,
            controller: 'AddUpstreamModalController',
            controllerAs: '$ctrl',
            //size: 'lg',
          });
        };


        function _fetchData() {
          $scope.loading = true;

          Upstream.load({
            size: $scope.itemsFetchSize
          }).then(function (response) {
            $scope.items = response;
            $scope.loading = false;
          });
        }


        // Listeners
        $scope.$on('kong.upstream.created', function (ev, data) {
          _fetchData();
        });


        $scope.$on('user.node.updated', function (ev, node) {
          if (UserService.user().node.kong_version == '0-9-x') {
            $state.go('dashboard')
          } else {
            _fetchData()
          }

        });

        _fetchData()

      }
    ]);
}());