/**
 * This file contains all necessary Angular controller definitions for 'frontend.admin.login-history' module.
 *
 * Note that this file should only contain controllers and nothing else.
 */
(function () {
  'use strict';

  angular.module('frontend.consumers')
    .controller('CreateOAuth2Controller', [
      '_', '$scope', '$rootScope', '$log', 'ConsumerService', 'MessageService', 'ApiModel', '$uibModalInstance', '_consumer', '_cred', '$localStorage', '$uibModal',
      function controller(_, $scope, $rootScope, $log, ConsumerService, MessageService, ApiModel, $uibModalInstance, _consumer, _cred, $localStorage, $uibModal) {

        $scope.globalInfo = $localStorage.credentials.user;

        $scope.consumer = _consumer;
        $scope.manage = manage;
        $scope.restrictAPIModel = restrictAPIModel;
        $scope.edit_client_secret = null;

        if (_cred) {
          $scope.data = angular.copy(_cred);
          // $scope.data.scope = _cred.scope.split(",");
          $scope.data.restrict_api_list = _cred.restrict_api_list == "" ? [] : _cred.restrict_api_list.split(",");
        } else {
          $scope.data = {
            op_host: $scope.globalInfo.opHost,
            oxd_http_url: $scope.globalInfo.oxdWeb,
            uma_mode: false,
            mix_mode: false,
            oauth_mode: true,
            allow_unprotected_path: false,
            show_consumer_custom_id: true,
            restrict_api: false,
            restrict_api_list: [],
            allow_oauth_scope_expression: true
          }
        }

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

        function manage(valid) {
          if (!valid) {
            return
          }

          if (_cred) {
            return update()
          } else {
            return create()
          }
        }

        function create() {
          // $scope.data.scope = $scope.data.scope ? $scope.data.scope.join(",") : "";
          $scope.data.restrict_api_list = $scope.data.restrict_api_list ? $scope.data.restrict_api_list.join(",") : "";
          ConsumerService.addCredential($scope.consumer.id, 'gluu-oauth2-client-auth', $scope.data).then(function (resp) {
            $log.debug('OAuth2 generated', resp);
            $rootScope.$broadcast('consumer.oauth2.created');
            $uibModalInstance.dismiss();
            prompt(resp.data);
          }).catch(function (err) {
            $log.error(err)
            $scope.errors = err.data.message || err.data.customMessage || {};
            MessageService.error(err.data.body && err.data.body.message || err.data.customMessage || {});
          })
        }

        function update() {
          $scope.data.oauth_mode = $scope.data.oauth_mode || false;
          $scope.data.uma_mode = $scope.data.uma_mode || false;
          $scope.data.mix_mode = $scope.data.mix_mode || false;
          $scope.data.allow_unprotected_path = $scope.data.allow_unprotected_path || false;
          $scope.data.allow_oauth_scope_expression = $scope.data.allow_oauth_scope_expression || false;
          $scope.data.restrict_api = $scope.data.restrict_api || false;
          $scope.data.show_consumer_custom_id = $scope.data.show_consumer_custom_id || false;
          $scope.data.client_secret = $scope.edit_client_secret || $scope.data.client_secret;

          if (!$scope.data.oauth_mode && !$scope.data.uma_mode && !$scope.data.mix_mode) {
            MessageService.error("Please select atleast one mode");
            return
          }
          if ($scope.data.restrict_api) {
            if ($scope.data.restrict_api_list && $scope.data.restrict_api_list.length <= 0) {
              MessageService.error("Requires at least one restricted API");
              return
            }
          }
          // $scope.data.scope = $scope.data.scope ? $scope.data.scope.join(",") : "";
          $scope.data.restrict_api_list = $scope.data.restrict_api_list ? $scope.data.restrict_api_list.join(",") : "";
          ConsumerService.updateCredential($scope.consumer.id, 'gluu-oauth2-client-auth', _cred.id, $scope.data).then(function (resp) {
            $log.debug('OAuth2 updated', resp);
            MessageService.success("Updated successfully!")
            $rootScope.$broadcast('consumer.oauth2.created');
            $uibModalInstance.dismiss();
          }).catch(function (err) {
            $log.error(err)
            $scope.errors = err.data.message || err.data.customMessage || {};
            MessageService.error(err.data.body && err.data.body.message || err.data.customMessage || {});
          })
        }

        function prompt(data) {
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
            '<td>' + data.oxd_id + ' </td>' +
            '</tr>' +
            '<tr>' +
            '<td>Client Id of OXD Id</td>' +
            '<td>' + data.client_id_of_oxd_id + '</td>' +
            '</tr>' +
            '</tbody>' +
            '</table>' +
            '<table class="table table-bordered">' +
            '<tbody>' +
            '<tr>' +
            '<tr>' +
            '<tr>' +
            '<td>Setup client OXD Id</td>' +
            '<td>' + data.setup_client_oxd_id + ' </td>' +
            '</tr>' +
            '<td>Client Id</td>' +
            '<td>' + data.client_id + '</td>' +
            '</tr>' +
            '<tr>' +
            '<td>Client Secret</td>' +
            '<td>' + data.client_secret + '</td>' +
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
            size: 'lg'
          });
        }

        function restrictAPIModel() {
          $uibModal.open({
            animation: true,
            ariaLabelledBy: 'modal-title',
            ariaDescribedBy: 'modal-body',
            templateUrl: 'js/app/consumers/credentials/restrict_api/restrict-api.html',
            controller: 'RestrictAPIController',
            controllerAs: '$ctrl',
            size: 'lg',
            resolve: {
              _apis: function () {
                $scope.loading = true;
                return ApiModel.load().then(function (response) {
                  $scope.loading = false;
                  return response;
                })
              },
              _selected_api: function () {
                return $scope.data.restrict_api_list;
              }
            }
          }).result.then(function (result) {
            $scope.data.restrict_api_list = result;
          });
        }
      }
    ])
}());
