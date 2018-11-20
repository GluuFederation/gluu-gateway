/**
 * This file contains all necessary Angular controller definitions for 'frontend.admin.login-history' module.
 *
 * Note that this file should only contain controllers and nothing else.
 */
(function () {
  'use strict';

  angular.module('frontend.snapshots')
    .controller('SnapshotController', [
      '_', '$scope', '$stateParams', '$rootScope', '$q', '$log', '$ngBootbox',
      'SocketHelperService', 'MessageService', 'SnapshotsService',
      '$state', '$uibModal', 'DialogService', 'Snapshot', 'AuthService',
      function controller(_, $scope, $stateParams, $rootScope, $q, $log, $ngBootbox,
                          SocketHelperService, MessageService, SnapshotsService,
                          $state, $uibModal, DialogService, Snapshot, AuthService) {

        $scope.token = AuthService.token();

        $scope.showRestoreModal = function () {

          var modalInstance = $uibModal.open({
            animation: true,
            ariaLabelledBy: 'modal-title',
            ariaDescribedBy: 'modal-body',
            templateUrl: 'js/app/snapshots/views/snapshot-apply-modal.html',
            controller: function ($scope, $uibModalInstance, SnapshotsService, UserService, _snapshot) {

              $scope.user = UserService.user();

              $scope.ready = false;
              $scope.imports = [];

              $scope.objects = {};
              Object.keys(_snapshot.data).forEach(function (item) {
                $scope.objects[item] = {
                  isChecked: false
                };
              });


              $scope.updateImports = function () {
                $scope.imports = [];
                Object.keys($scope.objects).forEach(function (key) {
                  if ($scope.objects[key].isChecked) {
                    $scope.imports.push(key)
                  }
                });
              };

              $scope.close = function () {
                $uibModalInstance.dismiss()
              };


              $scope.selectNode = function () {
                $uibModal.open({
                  animation: true,
                  ariaLabelledBy: 'modal-title',
                  ariaDescribedBy: 'modal-body',
                  templateUrl: 'js/app/connections/connections-modal.html',
                  controller: 'UpdateUserNodeController',
                  controllerAs: '$ctrl',
                  resolve: {
                    _nodes: [
                      '_',
                      'ListConfig', 'SocketHelperService',
                      'NodeModel',
                      function resolve(_,
                                       ListConfig, SocketHelperService,
                                       NodeModel) {
                        return NodeModel.load({
                          sort: 'createdAt DESC'
                        });
                      }
                    ]
                  }
                });
              };

              $scope.restore = function () {
                $scope.ready = true;
                $scope.restoring = true;
                SnapshotsService.restoreSnapshot(_snapshot.id, $scope.imports)
                  .then(function (success) {
                    $scope.results = success.data;
                    $scope.restoring = false;
                  })
                  .catch(function (err) {
                    console.error("restoreSnapshot:error", err);
                    $scope.restoring = false;
                    if (err.data && err.data.message) {
                      MessageService.error(err.data ? (err.data.message || 'Undefined error') : 'Server error');
                    }
                  });
              };

              //restore()
            },
            resolve: {
              _snapshot: function () {
                return $scope.originalSnapshot
              }
            }
          });

          modalInstance.result.then(function (d) {

          }, function (result) {

          });
        };


        function _fetchData() {

          $scope.loading = true;

          Snapshot.fetch($stateParams.id)
            .then(function (result) {
              // Delete `data.routes` since the routes are embedded in the `data.services`
              delete result.data.routes;
              $scope.originalSnapshot = result;
              $scope.snapshot = _.cloneDeep(result);

              // Hide the orderlist attribute of upstreams for faster rendering
              if ($scope.snapshot.data.upstreams) {
                $scope.snapshot.data.upstreams.forEach(function (item) {
                  item.orderlist = '( Not shown for faster DOM rendering... )'
                })
              }

              $scope.snapshot.data.services.map(function (o) {
                if (o.plugins) {
                  o.plugins.map(function (p) {
                    if (p.config.oauth_scope_expression) {
                      p.config.oauth_scope_expression = "Not shown for faster DOM rendering...";
                    }
                    return p;
                  })
                }

                if (o.routes) {
                  o.routes.map(function (r) {
                    if (r.plugins) {
                      r.plugins.map(function (p) {
                        if (p.config.oauth_scope_expression) {
                          p.config.oauth_scope_expression = "Not shown for faster DOM rendering...";
                        }
                        return p;
                      })
                    }
                    return r;
                  });
                }

                return o;
              });

              $scope.snapshot.data.plugins.map(function (p) {
                if (p.config.oauth_scope_expression) {
                  p.config.oauth_scope_expression = "Not shown for faster DOM rendering...";
                }
                return p;
              });

              $scope.loading = false;
            }).catch(function (err) {
            $scope.loading = false;

          })
        }

        _fetchData();
      }
    ]);
}());