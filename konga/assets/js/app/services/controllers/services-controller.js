(function () {
  'use strict';

  angular.module('frontend.services')
    .controller('ServicesController', [
      '$scope', '$rootScope', '$log', '$state', 'ServiceService', 'PluginsService', 'ListConfig', 'ServiceModel',
      'UserService', '$uibModal', 'PluginModel',
      function controller($scope, $rootScope, $log, $state, ServiceService, PluginsService, ListConfig, ServiceModel,
                          UserService, $uibModal, PluginModel) {

        ServiceModel.setScope($scope, false, 'items', 'itemCount');
        $scope = angular.extend($scope, angular.copy(ListConfig.getConfig('service', ServiceModel)));
        $scope.user = UserService.user()
        $scope.toggleStripRequestPathOrUri = toggleStripRequestPathOrUri
        $scope.isRequestPathOrUriStripped = isRequestPathOrUriStripped
        $scope.openAddServiceModal = openAddServiceModal
        $scope.updateService = updateService
        $scope.onEditPlugin = onEditPlugin

        /**
         * -----------------------------------------------------------------------------------------------------------
         * Internal Functions
         * -----------------------------------------------------------------------------------------------------------
         */

        function updateService(id, data) {

          $scope.loading = true

          ServiceModel.update(id, data)
            .then(function (res) {
              $log.debug("Update Service: ", res)
              $scope.loading = false
              _fetchData()
            }).catch(function (err) {
            $log.error("Update Service: ", err)
            $scope.loading = false;
          });

        }

        function toggleStripRequestPathOrUri(service) {

          if ($rootScope.Gateway.version.indexOf("0.9.") > -1) {
            service.strip_request_path = !service.strip_request_path;
          } else {
            service.strip_uri = !service.strip_uri;
          }

          $scope.updateService(service.id, {
            strip_uri: service.strip_uri
          })
        }


        function isRequestPathOrUriStripped(service) {
          if ($rootScope.Gateway && $rootScope.Gateway.version.indexOf("0.9.") > -1) {
            return service.strip_request_path;
          }

          return service.strip_uri
        }


        function openAddServiceModal() {
          if ($scope.openingModal) return;

          $scope.openingModal = true;
          setTimeout(function () {
            $scope.openingModal = false;
          }, 1000);

          $uibModal.open({
            animation: true,
            ariaLabelledBy: 'modal-title',
            ariaDescribedBy: 'modal-body',
            templateUrl: 'js/app/services/views/add-service-modal.html',
            controller: 'AddServiceModalController',
            controllerAs: '$ctrl',
            size: 'lg'
          });
        }


        function _fetchData() {
          $scope.loading = true;
          ServiceModel.load({
            size: $scope.itemsFetchSize
          }).then(function (serviceResponse) {
            PluginModel.load()
              .then(function (pluginsSesponse) {
                serviceResponse.data.map(function(service) {
                  service.plugins = [];
                  pluginsSesponse.data.forEach(function(plugin){
                    if ((plugin.service && plugin.service.id === service.id) && (plugin.name === 'gluu-opa-pep' || plugin.name === 'gluu-oauth-auth' || plugin.name === 'gluu-uma-auth')) {
                      service.plugins.push(plugin);
                    }
                  });
                  return service;
                });

                $scope.items = serviceResponse;
                console.log("Services =>", $scope.items);

                $scope.loading = false;
              })
          })
        }


        function onFilteredItemsChanged(services) {


        }


        /**
         * -----------------------------------------------------------------------------------------------------------
         * Watchers and Listeners
         * -----------------------------------------------------------------------------------------------------------
         */



        $scope.$on('service.created', function () {
          _fetchData()
        })


        $scope.$on('user.node.updated', function (node) {
          _fetchData()
        })


        // Assign Service health checks to filtered items only
        // so that the DOM is not overencumbered
        // when dealing with large datasets

        $scope.$watch('filteredItems', function (newValue, oldValue) {

          if (newValue && (JSON.stringify(newValue) !== JSON.stringify(oldValue))) {
            onFilteredItemsChanged(newValue)
          }
        })


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

        $scope.$on("plugin.added", function () {
          _fetchData()
        });

        $scope.$on("plugin.updated", function (ev, plugin) {
          _fetchData()
        });

        // Init
        _fetchData();

      }
    ])
  ;
}());
