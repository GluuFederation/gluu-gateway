/**
 * This file contains all necessary Angular controller definitions for 'frontend.admin.login-history' module.
 *
 * Note that this file should only contain controllers and nothing else.
 */
(function () {
  'use strict';

  angular.module('frontend.consumers')
    .controller('CreateOAuth2Controller', [
      '_', '$scope', '$rootScope', '$log', 'ConsumerService', 'MessageService', '$uibModalInstance', '_consumer', '_cred',
      function controller(_, $scope, $rootScope, $log, ConsumerService, MessageService, $uibModalInstance, _consumer, _cred) {

        $scope.consumer = _consumer;
        $scope.manage = manage;
        $scope.close = function () {
          $uibModalInstance.dismiss()
        };

        if (_cred) {
          $scope.data = angular.copy(_cred);
        } else {
          $scope.jwt = {}
        }

        function manage() {
          if (_cred) {
            return update()
          } else {
            return create()
          }
        }

        function create() {
          ConsumerService.addCredential($scope.consumer.id, 'oauth2', $scope.data).then(function (resp) {
            $log.debug("OAuth2 generated", resp);
            $rootScope.$broadcast('consumer.oauth2.created');
            $uibModalInstance.dismiss()
          }).catch(function (err) {
            $log.error(err);
            $scope.errors = err.data.body || err.data.customMessage || {}
          })
        }

        function update() {
          ConsumerService.addCredential($scope.consumer.id, 'oauth2', _cred.id, $scope.data).then(function (resp) {
            $log.debug("OAuth2 updated", resp);
            $rootScope.$broadcast('consumer.oauth2.created');
            $uibModalInstance.dismiss()
          }).catch(function (err) {
            $log.error(err);
            $scope.errors = err.data.body || err.data.customMessage || {}
          })
        }
      }
    ])
}());
