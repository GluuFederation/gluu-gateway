/**
 * This file contains all necessary Angular controller definitions for 'frontend.admin.login-history' module.
 *
 * Note that this file should only contain controllers and nothing else.
 */
(function () {
  'use strict';

  angular.module('frontend.consumers')
    .controller('ConsumersController', [
      '_', '$scope', '$log', '$state', 'ConsumerService', '$q', 'MessageService',
      'RemoteStorageService', 'UserService', 'SocketHelperService',
      '$uibModal', 'DialogService', 'ListConfig', 'ConsumerModel', 'PluginsService', '$rootScope',
      function controller(_, $scope, $log, $state, ConsumerService, $q, MessageService,
                          RemoteStorageService, UserService, SocketHelperService,
                          $uibModal, DialogService, ListConfig, ConsumerModel, PluginsService, $rootScope) {

        ConsumerModel.setScope($scope, false, 'items', 'itemCount');
        $scope = angular.extend($scope, angular.copy(ListConfig.getConfig('consumer', ConsumerModel)));
        $scope.user = UserService.user();
        $scope.importConsumers = importConsumers;
        $scope.openCreateConsumerModal = openCreateConsumerModal;
        $scope.openCreateClientModal = openCreateClientModal;
        $scope.deleteConsumer = deleteConsumer;
        $scope.importClick = false;
        function importConsumers() {
          $scope.importClick = true;
          $uibModal.open({
            animation: true,
            ariaLabelledBy: 'modal-title',
            ariaDescribedBy: 'modal-body',
            templateUrl: 'js/app/consumers/import/modal-select-storage.html',
            controller: 'ImportConsumersStorageController',
            controllerAs: '$ctrl',
            resolve: {
              _adapters: function () {
                return RemoteStorageService.loadAdapters()
                  .then(function (response) {
                    $scope.importClick = false;
                    return response;
                  });
              }
            }
          });
        }

        function openCreateConsumerModal() {
          if ($scope.openingModal) return;

          $scope.openingModal = true;
          setTimeout(function () {
            $scope.openingModal = false;
          }, 1000);

          $uibModal.open({
            animation: true,
            ariaLabelledBy: 'modal-title',
            ariaDescribedBy: 'modal-body',
            templateUrl: 'js/app/consumers/create-consumer-modal.html',
            controller: function ($scope, $rootScope, $log, $uibModalInstance, MessageService, ConsumerModel) {

              $scope.consumer = {
                username: '',
                custom_id: ''
              };

              $scope.close = close;
              $scope.submit = submit;

              function submit(valid) {
                if (!valid) {
                  return
                }

                $scope.errors = {};

                var data = _.cloneDeep($scope.consumer);
                if (!data.custom_id) {
                  delete data.custom_id;
                }

                if (!data.username) {
                  delete data.username;
                }

                ConsumerModel.create(data)
                  .then(function (res) {
                    MessageService.success("Consumer created successfully!");
                    $rootScope.$broadcast('consumer.created', res.data);
                    close()
                  })
                  .catch(function (err) {
                    $log.error("Failed to create consumer", err);
                    handleErrors(err);
                  });
              }

              function handleErrors(err) {
                $scope.errors = {};
                if (err.data && err.data.body) {
                  if (err.data.body.fields) {
                    Object.keys(err.data.body.fields).forEach(function (key) {
                      $scope.errors[key] = err.data.body.fields[key]
                    })
                  } else {
                    Object.keys(err.data.body).forEach(function (key) {
                      $scope.errors[key] = err.data.body[key]
                    })
                  }
                }
              }

              function close() {
                $uibModalInstance.dismiss()
              }
            },
            controllerAs: '$ctrl',
          })
        }

        function openCreateClientModal() {
          if ($scope.openingModal) return;

          $scope.openingModal = true;
          setTimeout(function () {
            $scope.openingModal = false;
          }, 1000);

          $uibModal.open({
            animation: true,
            ariaLabelledBy: 'modal-title',
            ariaDescribedBy: 'modal-body',
            templateUrl: 'js/app/consumers/create-op-client-modal.html',
            controller: function ($scope, $rootScope, $log, $uibModalInstance, MessageService, PluginsService, $localStorage) {
              var globalInfo = $localStorage.credentials.user;
              $scope.opClient = {
                client_name: '',
                client_id: '',
                client_secret: '',
                access_token_as_jwt: true,
                rpt_as_jwt: true,
                access_token_signing_alg: 'RS256',
                oxd_url: globalInfo.oxdWeb,
                op_host: globalInfo.opHost,
                scope: ['openid', 'oxd', 'uma_protection']
              };

              $scope.close = close;
              $scope.submit = submit;

              function submit(valid) {
                if (!valid) {
                  return
                }

                PluginsService
                  .addOAuthConsumerClient($scope.opClient)
                  .then(function (res) {
                    var clientResposne = res.data;
                    clientResposne.client_name = $scope.opClient.client_name;
                    prompt(clientResposne);
                    MessageService.success("Client created successfully!");
                    close();
                  })
                  .catch(function (err) {
                    MessageService.error("Failed to create client");
                    $log.error("Failed to create client", err);
                  });
              }

              function close() {
                $uibModalInstance.dismiss()
              }
            },
            controllerAs: '$ctrl',
            size: 'lg'
          })
        }

        function deleteConsumer(item) {
          var modalInstance = $uibModal.open({
            animation: true,
            ariaLabelledBy: 'modal-title',
            ariaDescribedBy: 'modal-body',
            windowClass: 'dialog',
            template: '' +
            '<div class="modal-header dialog no-margin">' +
            '<h5 class="modal-title">CONFIRM</h5>' +
            '</div>' +
            '<div class="modal-body">Do you want to delete the selected item?<br/>' +
            '</div>' +
            '<div class="modal-footer dialog">' +
            '<button class="btn btn-link" data-ng-click="decline()">CANCEL</button>' +
            '<button class="btn btn-success btn-link" data-ng-click="accept()">OK</button>' +
            '</div>',
            controller: function ($scope, $uibModalInstance) {
              $scope.accept = function () {
                $uibModalInstance.close();
              };

              $scope.decline = function () {
                $uibModalInstance.dismiss();
              };
            },
            size: 'sm'
          });

          modalInstance.result.then(function () {
            ConsumerService
              .delete(item)
              .then(function (cResponse) {
                MessageService.success("Kong consumer deleted successfully");
                $rootScope.$broadcast('consumer.created');
              })
              .catch(function (error) {
                console.log(error);
                MessageService.error((error.data && error.data.message) || "Failed to delete Consumer");
              });
          });
        }

        function prompt(data) {
          var modalInstance = $uibModal.open({
            animation: true,
            ariaLabelledBy: 'modal-title',
            ariaDescribedBy: 'modal-body',
            windowClass: 'dialog',
            backdrop: 'static',
            template: '' +
            '<div class="modal-header dialog no-margin">' +
            '<h5 class="modal-title">Client Registration Success</h5>' +
            '</div>' +
            '<div class="modal-body">' +
            '<table class="table table-bordered">' +
            '<tbody>' +
            '<tr>' +
            '<td>Client Name</td>' +
            '<td>' + data.client_name + ' </td>' +
            '</tr>' +
            '<tr>' +
            '<td>OXD Id</td>' +
            '<td>' + data.oxd_id + ' </td>' +
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
            '<label class="label label-danger"> * Write this down because there is no other way to recover the client secret!. </label>' +
            '<label class="label label-info"> * You need to use client_id as custom_id in kong consumer creation. </label>' +
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

        function _fetchData() {
          $scope.loading = true;
          ConsumerModel.load({
            size: $scope.itemsFetchSize
          }).then(function (response) {
            $scope.items = response;
            $scope.loading = false;
          })
        }

        $scope.$on('consumer.created', function (ev, user) {
          _fetchData()
        });

        $scope.$on('consumer.updated', function (ev, user) {
          _fetchData()
        });

        $scope.$on('credentials.assigned', function (ev, user) {
          _fetchData()
        });

        $scope.$on('search', function (ev, user) {
          _fetchData()
        });

        $scope.$on('user.node.updated', function (ev, node) {
          _fetchData()
        });

        _fetchData();
      }
    ])
}());
