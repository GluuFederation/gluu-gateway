/**
 * This file contains all necessary Angular controller definitions for 'frontend.admin.login-history' module.
 *
 * Note that this file should only contain controllers and nothing else.
 */
(function () {
  'use strict';

  angular.module('frontend.consumers')
    .controller('CreateJWTController', [
      '_', '$scope', '$rootScope', '$log', 'ConsumerService', 'MessageService', '$uibModalInstance', '_consumer', '_cred',
      function controller(_, $scope, $rootScope, $log, ConsumerService, MessageService, $uibModalInstance, _consumer, _cred) {

        $scope.consumer = _consumer;
        $scope.manage = manage;
        $scope.close = function () {
          $uibModalInstance.dismiss()
        };

        if (_cred) {
          $scope.jwt = angular.copy(_cred);
        } else {
          $scope.jwt = {
            key: '',
            algorithm: 'HS256',
            rsa_public_key: '',
            secret: ''
          }
        }

        function cleanJWT(jwt) {
          var jwtClone = _.clone(jwt);

          for (var key in jwtClone) {
            if (!jwtClone[key] || jwtClone[key] == '') {
              delete jwtClone[key]
            }
          }

          return jwtClone
        }

        function manage() {
          if (_cred) {
            return update()
          } else {
            return create()
          }
        }

        function create() {
          ConsumerService.addCredential($scope.consumer.id, 'jwt', cleanJWT($scope.jwt)).then(function (resp) {
            $log.debug("JWT generated", resp);
            $rootScope.$broadcast('consumer.jwt.created');
            $uibModalInstance.dismiss()
          }).catch(function (err) {
            $log.error(err);
            $scope.errors = err.data.body || err.data.customMessage || {}
          })
        }

        function update() {
          ConsumerService.updateCredential($scope.consumer.id, 'jwt', _cred.id, cleanJWT($scope.jwt)).then(function (resp) {
            $log.debug("JWT updated", resp);
            $rootScope.$broadcast('consumer.jwt.created');
            $uibModalInstance.dismiss()
          }).catch(function (err) {
            $log.error(err);
            $scope.errors = err.data.body || err.data.customMessage || {}
          })
        }
      }
    ])
}());
