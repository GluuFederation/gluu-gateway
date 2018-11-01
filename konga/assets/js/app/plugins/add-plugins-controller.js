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
      '_plugins', '_info',
      function controller(_, $scope, $rootScope, $log,
                          $state, MessageService, DialogService,
                          KongPluginsService, PluginsService, $uibModal,
                          _plugins, _info) {


        var info = _info.data;
        var plugins_available = info.plugins.available_on_server;
        var pluginOptions = new KongPluginsService().pluginOptions();

        $scope.pluginOptions = pluginOptions;
        new KongPluginsService().makePluginGroups().then(function (groups) {
          $scope.pluginGroups = groups;
          $log.debug("Plugin Groups", $scope.pluginGroups);

          $scope.pluginGroups.forEach(function (group) {
            console.log(group.plugins);
            for (var key in group.plugins) {
              if (!plugins_available[key]) delete group.plugins[key]
            }
          });

          // Init
          syncPlugins(_plugins.data.data)
        });
        $scope.activeGroup = 'Authentication'
        $scope.setActiveGroup = setActiveGroup
        $scope.filterGroup = filterGroup
        $scope.onAddPlugin = onAddPlugin

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
          if (name == "gluu-oauth-pep") {
            return $state.go("plugins.oauth-plugin");
          }

          if (name == "gluu-uma-pep") {
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

          setTimeout(function () {
            var flag = false;
            $scope.existingPlugins.forEach(function(obj){
              if (obj == "gluu-oauth-pep") {
                $scope.pluginGroups[0].plugins['gluu-uma-pep'].isAllow = false;
                flag = true
              }
              if (obj == "gluu-uma-pep") {
                $scope.pluginGroups[0].plugins['gluu-oauth-pep'].isAllow = false;
                flag = true
              }
            });
            if (flag == false) {
              $scope.pluginGroups[0].plugins['gluu-uma-pep'].isAllow = true;
              $scope.pluginGroups[0].plugins['gluu-oauth-pep'].isAllow = true;
            }
          }, 100);
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
        })
      }
    ]);
}());
