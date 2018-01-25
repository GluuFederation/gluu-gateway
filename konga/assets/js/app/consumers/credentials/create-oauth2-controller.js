/**
 * This file contains all necessary Angular controller definitions for 'frontend.admin.login-history' module.
 *
 * Note that this file should only contain controllers and nothing else.
 */
(function () {
  'use strict';

  angular.module('frontend.consumers')
    .controller('CreateOAuth2Controller', [
      '_', '$scope', '$rootScope', '$log', 'ConsumerService', 'MessageService', '$uibModalInstance', '_consumer', '$localStorage', '$uibModal',
      function controller(_, $scope, $rootScope, $log, ConsumerService, MessageService, $uibModalInstance, _consumer, $localStorage, $uibModal) {

        $scope.globalInfo = $localStorage.credentials.user;

        $scope.consumer = _consumer;
        $scope.create = create;
        $scope.data = {
          op_host: $scope.globalInfo.opHost,
          oxd_http_url: $scope.globalInfo.oxdWeb
        };

        $scope.close = function () {
          $uibModalInstance.dismiss()
        };

        $scope.jwt = {
          key: '',
          algorithm: 'HS256',
          rsa_public_key: '',
          secret: ''
        };

        $scope.token_endpoint_auth_method = [
          'client_secret_basic',
          'client_secret_post',
          'client_secret_jwt',
          'private_key_jwt',
          'access_token',
          'none'
        ];

        $scope.token_endpoint_auth_signing_alg = [
          'HS256',
          'HS384',
          'HS512',
          'RS256',
          'RS384',
          'RS512',
          'ES256',
          'ES384',
          'ES512',
          'none'
        ];

        function create() {
          ConsumerService.addCredential($scope.consumer.id, 'gluu-oauth2-client-auth', $scope.data).then(function (resp) {
            $log.debug('OAuth2 generated', resp);
            $rootScope.$broadcast('consumer.oauth2.created');
            $uibModalInstance.dismiss();
            prompt(resp.data.client_id, resp.data.oxd_id, resp.data.client_secret);
          }).catch(function (err) {
            $log.error(err)
            $scope.errors = err.data.body || err.data.customMessage || {}
          })
        }

        function prompt(client_id, oxd_id, client_secret) {
          var modalInstance = $uibModal.open({
            animation: true,
            ariaLabelledBy: 'modal-title',
            ariaDescribedBy: 'modal-body',
            windowClass: 'dialog',
            template: '' +
            '<div class="modal-header dialog no-margin">' +
            '<h5 class="modal-title">Client Registration Success</h5>' +
            '</div>' +
            '<div class="modal-body">' +
            '<table class="table table-bordered">' +
            '<tbody>' +
            '<tr>' +
            '<td>OXD Id</td>' +
            '<td>' + oxd_id + ' </td>' +
            '</tr>' +
            '<tr>' +
            '<td>Client ID</td>' +
            '<td>' + client_id + '</td>' +
            '</tr>' +
            '<tr>' +
            '<td>Client Secret</td>' +
            '<td>' + client_secret + '</td>' +
            '</tr>' +
            '</tbody>' +
            '</table>' +
            '<label class="label label-danger"> * Write this down because there is no other way to recover the client secret! </label>' +
            '</div>' +
            '<div class="modal-footer dialog">' +
            '<button class="btn btn-success btn-link" data-ng-click="accept()">OK</button>' +
            '</div>',
            controller: function ($scope, $uibModalInstance) {
              $scope.accept = function () {
                $uibModalInstance.dismiss()
              }
            },
            size: 'md'
          });
        }
      }
    ])
}());
