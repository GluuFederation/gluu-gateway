/**
 * This file contains all necessary Angular controller definitions for 'frontend.login-history' module.
 *
 * Note that this file should only contain controllers and nothing else.
 */
(function () {
  'use strict';

  angular.module('frontend.upstreams')
    .controller('AddUpstreamModalController', [
      '$scope', '$rootScope', '$log', '$state', 'SettingsService',
      '$uibModalInstance', 'Upstream', 'MessageService',
      function controller($scope, $rootScope, $log, $state, SettingsService,
                          $uibModalInstance, Upstream, MessageService) {

        $scope.upstream = {
          slots: 1000,
          hash_on: 'none',
          hash_fallback: 'none'
        };

        $scope.close = function () {
          $uibModalInstance.dismiss()
        };

        $scope.submit = function () {
          $scope.busy = true;
          var data = angular.copy($scope.upstream);

          // Fix non numeric arrays
          var arr = ["active.healthy", "active.unhealthy", "passive.healthy", "passive.unhealthy"];
          arr.forEach(function (item) {
            if (_.get(data, 'healthchecks.' + item + '.http_statuses')) {
              _.update(data, 'healthchecks.' + item + '.http_statuses', function (statuses) {
                return _.map(statuses, function (status) {
                  try {
                    return parseInt(status);
                  } catch (e) {
                    return status;
                  }
                })
              })
            }
          });

          delete data.token;
          $log.debug("data", data);
          Upstream.create(data)
            .then(
              function onSuccess(result) {
                $log.debug("AddUpstreamModalController:created upstream", result);
                MessageService.success('New upstream created successfully');
                $scope.busy = false;
                $rootScope.$broadcast('kong.upstream.created', result.data);
                $uibModalInstance.dismiss();
                $scope.errors = null;
              }, function (err) {
                $log.error("AddUpstreamModalController:created upstream error", err);
                $scope.busy = false;
                Upstream.handleError($scope, err)
              }
            )
        }
      }
    ]);
}());
