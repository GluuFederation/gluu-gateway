/**
 * This file contains all necessary Angular controller definitions for 'frontend.admin.login-history' module.
 *
 * Note that this file should only contain controllers and nothing else.
 */
(function () {
  'use strict';

  angular.module('frontend.services')
    .controller('AddServicePluginModalController', [
      '_', '$scope', '$rootScope', '$log',
      '$state', 'ServiceService', 'MessageService', 'DialogService',
      'KongPluginsService', 'PluginsService', '$uibModal', '$uibModalInstance',
      '_service',
      function controller(_, $scope, $rootScope, $log,
                          $state, ServiceService, MessageService, DialogService,
                          KongPluginsService, PluginsService, $uibModal, $uibModalInstance,
                          _service) {


        var pluginOptions = new KongPluginsService().pluginOptions();

        $scope.service = _service;
        $scope.pluginOptions = pluginOptions;

        $scope.activeGroup = 'Security';
        $scope.setActiveGroup = setActiveGroup;
        $scope.filterGroup = filterGroup;
        $scope.onAddPlugin = onAddPlugin;
        $scope.close = function () {
          return $uibModalInstance.dismiss()
        };
        $scope.checkAllow = checkAllow;

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
            return $state.go("services.oauth-plugin", {service_id: $scope.service.id});
          }

          if (name == "gluu-uma-auth") {
            $uibModalInstance.dismiss();
            return $state.go("services.uma-plugin", {service_id: $scope.service.id});
          }

          if (name == "gluu-openid-connect") {
            $uibModalInstance.dismiss();
            return MessageService.error("Not Allow! You need to configure it on Route.");
          }

          var modalInstance = $uibModal.open({
            animation: true,
            ariaLabelledBy: 'modal-title',
            ariaDescribedBy: 'modal-body',
            templateUrl: 'js/app/plugins/modals/add-plugin-modal.html',
            size: 'lg',
            controller: 'AddPluginController',
            resolve: {
              _context: {
                name: 'service',
                data: $scope.service
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
          getServicePlugins()
        });

        /**
         * ------------------------------------------------------------
         * Listeners
         * ------------------------------------------------------------
         */
        $scope.$on("plugin.added", function () {
          getServicePlugins()
        });

        $scope.$on("plugin.updated", function (ev, plugin) {
          getServicePlugins()
        });


        function fetchPlugins() {
          PluginsService.load()
            .then(function (res) {

            })
        }

        function getServicePlugins() {
          ServiceService.plugins($scope.service.id)
            .then(function (response) {
              $scope.existingPlugins = response.data.data.map(function (item) {
                return item.name
              });

              new KongPluginsService().makePluginGroups().then(function (groups) {
                $scope.pluginGroups = groups.filter(function(group) {
                    return group.name !== "Metrics"
                  });

                delete $scope.pluginGroups[0].plugins['gluu-openid-connect'];
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

        getServicePlugins();
      }
    ]);
}());
