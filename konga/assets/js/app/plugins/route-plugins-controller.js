/**
 * This file contains all necessary Angular controller definitions for 'frontend.admin.login-history' module.
 *
 * Note that this file should only contain controllers and nothing else.
 */
(function () {
  'use strict';

  angular.module('frontend.plugins')
    .controller('RoutePluginsController', [
      '_', '$scope', '$stateParams', '$log', '$state', 'RoutesService', 'PluginsService',
      '$uibModal', 'DialogService', 'InfoService', '_plugins', 'MessageService', '$rootScope',
      function controller(_, $scope, $stateParams, $log, $state, RoutesService, PluginsService,
                          $uibModal, DialogService, InfoService, _plugins, MessageService, $rootScope) {


        $scope.plugins = _plugins.data;
        $scope.onAddPlugin = onAddPlugin;
        $scope.onEditPlugin = onEditPlugin;
        $scope.deletePlugin = deletePlugin;
        $scope.updatePlugin = updatePlugin;
        $scope.togglePlugin = togglePlugin;
        $scope.deleteOPClient = deleteOPClient;
        $scope.search = ''

        $log.debug("Plugins", $scope.plugins.data);

        /**
         * ----------------------------------------------------------------------
         * Functions
         * ----------------------------------------------------------------------
         */


        function togglePlugin(plugin) {
          plugin.enabled = !plugin.enabled;
          updatePlugin(plugin);
        }

        function onAddPlugin() {
          $uibModal.open({
            animation: true,
            ariaLabelledBy: 'modal-title',
            ariaDescribedBy: 'modal-body',
            templateUrl: 'js/app/routes/views/add-route-plugin-modal.html',
            size: 'lg',
            controller: 'AddRoutePluginModalController',
            resolve: {
              _route: function () {
                return $scope.route
              },
              _plugins: function () {
                return PluginsService.load()
              },
              _info: [
                '$stateParams',
                'InfoService',
                '$log',
                function resolve($stateParams,
                                 InfoService,
                                 $log) {
                  return InfoService.getInfo()
                }
              ]
            }
          });
        }

        function updatePlugin(plugin) {
          PluginsService.update(plugin.id, {
            enabled: plugin.enabled,
            //config : plugin.config
          })
            .then(function (res) {
              $log.debug("updatePlugin", res)
              $scope.plugins.data[$scope.plugins.data.indexOf(plugin)] = res.data;

            }).catch(function (err) {
            $log.error("updatePlugin", err)
          })
        }

        function deleteOPClient(item) {
          var createConsumer = $uibModal.open({
            animation: true,
            ariaLabelledBy: 'modal-title',
            ariaDescribedBy: 'modal-body',
            templateUrl: 'js/app/plugins/comment-modal.html',
            controller: function ($scope, $rootScope, $log, $uibModalInstance, MessageService) {
              $scope.close = close;
              $scope.submit = submit;
              $scope.comment = "";

              function submit(valid) {
                if (!valid) {
                  return;
                }

                if (!$scope.comment) {
                  MessageService.error('Comment required!');
                  return
                }
                $uibModalInstance.close($scope.comment);
              }

              function close() {
                $uibModalInstance.dismiss();
              }
            },
            controllerAs: '$ctrl',
          });

          createConsumer.result.then(function (comment) {
            PluginsService
              .delete(item.id)
              .then(function (cResponse) {
                PluginsService
                  .deleteOPClient({comment: comment, route_id: item.route.id})
                  .then(function (pResponse) {
                    MessageService.success("Plugin deleted successfully");
                    $rootScope.$broadcast('plugin.added');
                  })
                  .catch(function (error) {
                    console.log(error);
                    MessageService.error((error.data && error.data.message) || "Failed to add comment");
                  });
              })
              .catch(function (error) {
                console.log(error);
                MessageService.error((error.data && error.data.message) || "Failed to delete Plugin");
              });
          })
        }

        function deletePlugin(plugin) {
          DialogService.prompt(
            "Delete Plugin", "Really want to delete the plugin?",
            ['CANCEL', 'YES'],
            function accept() {
              PluginsService.delete(plugin.id)
                .then(function (resp) {
                  $scope.plugins.data.splice($scope.plugins.data.indexOf(plugin), 1);
                }).catch(function (err) {
                $log.error(err)
              })
            }, function decline() {
            })
        }

        function onEditPlugin(item) {
          $uibModal.open({
            animation: true,
            ariaLabelledBy: 'modal-title',
            ariaDescribedBy: 'modal-body',
            templateUrl: 'js/app/plugins/modals/edit-plugin-modal.html',
            size: 'lg',
            controller: 'EditPluginController',
            resolve: {
              _plugin: function () {
                return _.cloneDeep(item)
              },
              _schema: function () {
                return PluginsService.schema(item.name)
              }
            }
          });
        }

        function fetchPlugins() {
          RoutesService.plugins($stateParams.route_id)
            .then(function (res) {
              $scope.plugins = res.data
            })
        }


        /**
         * ------------------------------------------------------------
         * Listeners
         * ------------------------------------------------------------
         */
        $scope.$on("plugin.added", function () {
          fetchPlugins()
        })

        $scope.$on("plugin.updated", function (ev, plugin) {
          fetchPlugins()
        })


      }
    ])
  ;
}());
