/**
 * This file contains all necessary Angular controller definitions for 'frontend.admin.login-history' module.
 *
 * Note that this file should only contain controllers and nothing else.
 */
(function () {
  'use strict';

  angular.module('frontend.plugins')
    .controller('AddPluginModalController', [
      '_', '$scope', '$rootScope', '$log',
      '$state', 'ConsumerService', 'MessageService', 'DialogService', 'Semver',
      'KongPluginsService', 'PluginsService', '$uibModal', '$uibModalInstance',
      '_context', 'ServiceService', 'RoutesService',
      function controller(_, $scope, $rootScope, $log,
                          $state, ConsumerService, MessageService, DialogService, Semver,
                          KongPluginsService, PluginsService, $uibModal, $uibModalInstance,
                          _context, ServiceService, RoutesService) {

        if (_.isArray(_context)) {
          _context.forEach(function (ctx) {
            $scope[ctx.name] = ctx.data;
          })
        } else if (_context) {
          $scope[_context.name] = _context.data;
        }

        var pluginOptions = new KongPluginsService().pluginOptions();
        $scope.pluginOptions = pluginOptions;

        new KongPluginsService().makePluginGroups().then(function (groups) {
          $scope.pluginGroups = groups;

          // Remove non consumer plugins if this is a consumer plugins context
          if ($scope.consumer) {
            var remainingPluginGroups = [];
            $scope.pluginGroups.forEach(function (group) {

              if (group.hasConsumerPlugins) {
                Object.keys(group.plugins).forEach(function (key) {
                  if (group.plugins[key].hideIfNotInConsumerContext) {
                    delete group.plugins[key];
                  }
                });
                remainingPluginGroups.push(group);
              }

            });

            $scope.pluginGroups = remainingPluginGroups;
          }

          $scope.activeGroup = $scope.pluginGroups[0].name;
        });


        $scope.setActiveGroup = setActiveGroup;
        $scope.filterGroup = filterGroup;
        $scope.onAddPlugin = onAddPlugin;
        $scope.close = function () {
          return $uibModalInstance.dismiss()
        };


        /**
         * -------------------------------------------------------------
         * Functions
         * -------------------------------------------------------------
         */

        function setActiveGroup(name) {
          $scope.activeGroup = name;
        }

        function filterGroup(group) {
          return group.name === $scope.activeGroup;
        }

        function onAddPlugin(name) {
          var modalInstance = $uibModal.open({
            animation: true,
            ariaLabelledBy: 'modal-title',
            ariaDescribedBy: 'modal-body',
            templateUrl: 'js/app/plugins/modals/add-plugin-modal.html',
            size: 'lg',
            controller: 'AddPluginController',
            resolve: {
              _context: function () {
                return _context;
              },
              _pluginName: function () {
                return name;
              },
              _schema: function () {
                return PluginsService.schema(name);
              }
            }
          });


          modalInstance.result.then(function (data) {

          }, function (data) {
            if (data && data.name && $scope.existingPlugins.indexOf(data.name) < 0) {
              $scope.existingPlugins.push(data.name);
            }
          });
        }


        // Listeners
        $scope.$on('plugin.added', function () {
          fetchPlugins();
        });

        /**
         * ------------------------------------------------------------
         * Listeners
         * ------------------------------------------------------------
         */
        $scope.$on("plugin.added", function () {
          fetchPlugins();
        });

        $scope.$on("plugin.updated", function (ev, plugin) {
          fetchPlugins();
        });


        function fetchPlugins() {
          PluginsService.load()
            .then(function (res) {

            });
        }

        function getExistingPlugins() {
          if ($scope.consumer) {
            ConsumerService.listPlugins($scope.consumer.id)
              .then(function (response) {
                $scope.existingPlugins = response.data.data.map(function (item) {
                  return item.name;
                });
              })
              .catch(function (err) {

              });
          }

          if ($scope.service) {
            ServiceService.plugins($scope.service.id)
              .then(function (response) {
                $scope.existingPlugins = response.data.data.map(function (item) {
                  return item.name;
                });
              })
              .catch(function (err) {

              });
          }

          if ($scope.route) {
            RoutesService.listPlugins($scope.route.id)
              .then(function (response) {
                $scope.existingPlugins = response.data.data.map(function (item) {
                  return item.name;
                });
              })
              .catch(function (err) {

              });
          }
        }

        getExistingPlugins();
      }
    ]);
}());
