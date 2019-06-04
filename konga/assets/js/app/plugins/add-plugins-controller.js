/**
 * This file contains all necessary Angular controller definitions for 'frontend.admin.login-history' module.
 *
 * Note that this file should only contain controllers and nothing else.
 */
(function () {
  'use strict';

  angular.module('frontend.plugins')
    .controller('AddPluginsController', [
      '_', '$scope', '$rootScope', '$log',
      '$state', 'MessageService', 'DialogService',
      'KongPluginsService', 'PluginsService', '$uibModal',
      function controller(_, $scope, $rootScope, $log,
                          $state, MessageService, DialogService,
                          KongPluginsService, PluginsService, $uibModal) {

        var pluginOptions = new KongPluginsService().pluginOptions();

        $scope.pluginOptions = pluginOptions;
        $scope.activeGroup = 'Security';
        $scope.setActiveGroup = setActiveGroup;
        $scope.filterGroup = filterGroup;
        $scope.onAddPlugin = onAddPlugin;
        $scope.checkAllow = checkAllow;

        $scope.alert = {
          msg: '<strong>Plugins added in this section will be applied Globally</strong>.' +
          '<br>- If you need to add plugins to a specific Service or Route, you can do it' +
          ' in the respective section.' +
          '<br>- If you need to add plugins to a specific Consumer, you can do it' +
          ' in the respective Consumer\'s page.'
        };

        $scope.closeAlert = function () {
          $scope.alert = undefined
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
          if ($scope.openingModal) return;

          $scope.openingModal = true;
          setTimeout(function () {
            $scope.openingModal = false;
          }, 1000);

          if (name == "gluu-oauth-auth") {
            return $state.go("plugins.oauth-plugin");
          }

          if (name == "gluu-uma-auth") {
            return $state.go("plugins.uma-plugin");
          }

          $uibModal.open({
            animation: true,
            ariaLabelledBy: 'modal-title',
            ariaDescribedBy: 'modal-body',
            templateUrl: 'js/app/plugins/modals/add-plugin-modal.html',
            size: 'lg',
            controller: 'AddPluginController',
            resolve: {
              _context: function () {
                return null;
              },
              _pluginName: function () {
                return name
              },
              _schema: function () {
                return PluginsService.schema(name)
              }
            }
          });
        }

        function findPlugin(plugins, name) {
          for (var i = 0; i < plugins.length; i++) {
            if (plugins[i].name === name) {
              return plugins[i]
            }
          }
          return undefined
        }

        function syncPlugins(added) {
          $scope.existingPlugins = [];

          added.forEach(function (item) {
            if (!(item.service_id || item.route_id || item.api_id)) {
              $scope.existingPlugins.push(item.name)
            }
          });

          new KongPluginsService().makePluginGroups().then(function (groups) {
            $scope.pluginGroups = groups;
            delete $scope.pluginGroups[0].plugins['gluu-openid-connect'];
            delete $scope.pluginGroups[7].plugins['gluu-oauth-pep'];
            delete $scope.pluginGroups[7].plugins['gluu-uma-pep'];
            $log.debug("Plugin Groups", $scope.pluginGroups);
          });
        }

        function fetchPlugins() {
          PluginsService.load()
            .then(function (res) {
              syncPlugins(res.data.data);
            })
        }

        // Listeners
        $scope.$on('plugin.added', function () {
          fetchPlugins()
        });

        /**
         * ------------------------------------------------------------
         * Listeners
         * ------------------------------------------------------------
         */
        $scope.$on("plugin.added", function () {
          fetchPlugins()
        });

        $scope.$on("plugin.updated", function (ev, plugin) {
          fetchPlugins()
        });

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
            ['gluu-uma-auth', 'gluu-oauth-auth'].forEach(function (name) {
              if ($scope.existingPlugins.indexOf(name) > -1) {
                allow = false
              }
            })
          }

          if (key === 'gluu-uma-auth') {
            ['gluu-uma-auth', 'gluu-opa-pep', 'gluu-oauth-auth', 'gluu-oauth-pep'].forEach(function (name) {
              if ($scope.existingPlugins.indexOf(name) > -1) {
                allow = false
              }
            })
          }

          return allow
        }

        fetchPlugins();
      }
    ]);
}());
