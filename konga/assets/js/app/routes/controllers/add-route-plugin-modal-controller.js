/**
 * This file contains all necessary Angular controller definitions for 'frontend.admin.login-history' module.
 *
 * Note that this file should only contain controllers and nothing else.
 */
(function () {
  'use strict';

  angular.module('frontend.routes')
    .controller('AddRoutePluginModalController', [
      '_', '$scope', '$rootScope', '$log',
      '$state', 'RoutesService', 'MessageService', 'DialogService',
      'KongPluginsService', 'PluginsService', '$uibModal', '$uibModalInstance',
      '_route',
      function controller(_, $scope, $rootScope, $log,
                          $state, RoutesService, MessageService, DialogService,
                          KongPluginsService, PluginsService, $uibModal, $uibModalInstance,
                          _route) {


        var pluginOptions = new KongPluginsService().pluginOptions();

        $scope.route = _route;
        $scope.pluginOptions = pluginOptions;

        $scope.activeGroup = 'Security';
        $scope.setActiveGroup = setActiveGroup;
        $scope.filterGroup = filterGroup;
        $scope.onAddPlugin = onAddPlugin;
        $scope.checkAllow = checkAllow;
        $scope.close = function () {
          return $uibModalInstance.dismiss()
        };


        /**
         * -------------------------------------------------------------
         * Functions
         * -------------------------------------------------------------
         */

        function setActiveGroup(name) {
          $scope.activeGroup = name
        }

        function filterGroup(group) {
          return group.name == $scope.activeGroup
        }

        function onAddPlugin(name) {
          if (name == "gluu-oauth-auth") {
            $uibModalInstance.dismiss();
            return $state.go("routes.oauth-plugin", {route_id: $scope.route.id});
          }

          if (name == "gluu-uma-auth") {
            $uibModalInstance.dismiss();
            return $state.go("routes.uma-plugin", {route_id: $scope.route.id});
          }

          if (name == "gluu-openid-connect") {
            $uibModalInstance.dismiss();
            return $state.go("routes.openid-plugin", {route_id: $scope.route.id});
          }

          var modalInstance = $uibModal.open({
            animation: true,
            ariaLabelledBy: 'modal-title',
            ariaDescribedBy: 'modal-body',
            templateUrl: 'js/app/plugins/modals/add-plugin-modal.html',
            size: 'lg',
            controller: 'AddPluginController',
            resolve: {
              _context: function () {
                return {
                  name: 'route',
                  data: $scope.route
                }
              },
              _pluginName: function () {
                return name
              },
              _schema: function () {
                return PluginsService.schema(name)
              }
            }
          });


          modalInstance.result.then(function (data) {

          }, function (data) {
            if (data && data.name && $scope.existingPlugins.indexOf(data.name) < 0) {
              $scope.existingPlugins.push(data.name)
            }
          });
        }


        // Listeners
        $scope.$on('plugin.added', function () {
          getRoutePlugins()
        });

        /**
         * ------------------------------------------------------------
         * Listeners
         * ------------------------------------------------------------
         */
        $scope.$on("plugin.added", function () {
          getRoutePlugins()
        });

        $scope.$on("plugin.updated", function (ev, plugin) {
          getRoutePlugins()
        });


        function fetchPlugins() {
          PluginsService.load()
            .then(function (res) {

            })
        }

        function getRoutePlugins() {
          RoutesService.plugins($scope.route.id)
            .then(function (response) {
              $scope.existingPlugins = response.data.data.map(function (item) {
                return item.name
              });
              new KongPluginsService().makePluginGroups().then(function (groups) {
                $scope.pluginGroups = groups.filter(function(group) {
                  return group.name !== "Metrics"
                });
                delete $scope.pluginGroups[6].plugins['gluu-oauth-pep'];
                delete $scope.pluginGroups[6].plugins['gluu-uma-pep'];
                $log.debug("Plugin Groups", $scope.pluginGroups);
              });
            })
            .catch(function (err) {

            })
        }

        function checkAllow(key) {
          var allow = true;
          if (key === 'gluu-opa-pep') {
            ['gluu-opa-pep', 'gluu-oauth-pep', 'gluu-uma-pep'].forEach(function (name) {
              if ($scope.existingPlugins.indexOf(name) > -1) {
                allow = false
              }
            })
          }

          if (key === 'gluu-oauth-auth') {
            ['gluu-openid-connect', 'gluu-uma-auth', 'gluu-oauth-auth'].forEach(function (name) {
              if ($scope.existingPlugins.indexOf(name) > -1) {
                allow = false
              }
            })
          }

          if (key === 'gluu-uma-auth') {
            ['gluu-uma-auth', 'gluu-openid-connect', 'gluu-opa-pep', 'gluu-oauth-auth', 'gluu-oauth-pep'].forEach(function (name) {
              if ($scope.existingPlugins.indexOf(name) > -1) {
                allow = false
              }
            })
          }

          if (key === 'gluu-openid-connect') {
            ['gluu-openid-connect', 'gluu-oauth-auth', 'gluu-uma-auth'].forEach(function (name) {
              if ($scope.existingPlugins.indexOf(name) > -1) {
                allow = false
              }
            })
          }

          return allow
        }

        getRoutePlugins();
      }
    ]);
}());
