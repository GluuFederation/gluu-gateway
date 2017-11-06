(function () {
  'use strict';

  angular.module('frontend.plugins')
    .controller('PluginsController', [
      '_', '$scope', '$log', '$state', 'ApiService', 'PluginsService', 'MessageService',
      '$uibModal', 'DialogService', 'PluginModel', 'ListConfig', 'UserService', 'ApiModel', 'PluginHelperService',
      function controller(_, $scope, $log, $state, ApiService, PluginsService, MessageService,
                          $uibModal, DialogService, PluginModel, ListConfig, UserService, ApiModel, PluginHelperService) {

        PluginModel.setScope($scope, false, 'items', 'itemCount');
        $scope = angular.extend($scope, angular.copy(ListConfig.getConfig('plugin', PluginModel)));
        $scope.user = UserService.user();
        $scope.onEditPlugin = onEditPlugin
        $scope.updatePlugin = updatePlugin
        $scope.addNewCondition = addNewCondition
        $scope.addNewPath = addNewPath
        $scope.showResourceJSON = showResourceJSON
        $scope.addPlugin = addPlugin
        $scope.loadMethods = loadMethods
        $scope.loadScopes = loadScopes
        $scope.modelPlugin = {
          api_id: '',
          name: 'kong-uma-rs',
          config: {
            protection_document: [{
              path: '/path',
              conditions: [
                {
                  httpMethods: [{text: 'GET'}, {text: 'POST'}],
                  scopes: [
                    {text: 'http://example.com/dev/actions'}
                  ],
                  ticketScopes: []
                }]
            }]
          }
        };


        /**
         * ----------------------------------------------------------------------
         * Functions
         * ----------------------------------------------------------------------
         */

        function updatePlugin(plugin) {

          if (!$scope.user.hasPermission('plugins', 'update')) {

            MessageService.error("You don't have permissions to perform this action")
            return false;
          }

          PluginsService.update(plugin.id, {
            enabled: plugin.enabled
          })
            .then(function (res) {
              $log.debug("updatePlugin", res)
              // $scope.items.data[$scope.items.data.indexOf(plugin)] = res.data;

            }).catch(function (err) {
            $log.error("updatePlugin", err)
          })
        }

        function addNewCondition(pathIndex) {
          $scope.modelPlugin.config.protection_document[pathIndex].conditions.push(
            {
              httpMethods: [{text: 'GET'}],
              scopes: [
                {text: 'http://example.com/view'}
              ],
              ticketScopes: []
            });
        }

        function showResourceJSON() {
          $uibModal.open({
            animation: true,
            templateUrl: 'js/app/plugins/modals/show-resource-json-modal.html',
            size: 'lg',
            controller: ['$uibModalInstance', '$scope', 'modelPlugin', ShowScriptController],
            resolve: {
              modelPlugin: function () {
                return $scope.modelPlugin;
              }
            }
          }).result.then(function (result) {
          });
        }

        function ShowScriptController($uibModalInstance, $scope, modelPlugin) {
          $scope.model = angular.copy(modelPlugin);
          $scope.model.config.protection_document.forEach(function (path, pIndex) {
            path.conditions.forEach(function (cond, cIndex) {
              cond.httpMethods = cond.httpMethods.map(function (o) {
                return o.text;
              });
              cond.scopes = cond.scopes.map(function (o) {
                return o.text;
              });
              if (cond.ticketScopes.length > 0) {
                cond.ticketScopes = cond.ticketScopes.map(function (o) {
                  return o.text;
                });
              } else {
                delete cond.ticketScopes;
              }
            });
          });
        }

        function addNewPath() {
          $scope.modelPlugin.config.protection_document.push({
            path: '/path',
            conditions: [
              {
                httpMethods: [{text: 'GET'}],
                scopes: [
                  {text: 'http://example.com/view'}
                ],
                ticketScopes: []
              }
            ]
          });
        }

        function onEditPlugin(item) {

          if (!$scope.user.hasPermission('plugins', 'edit')) {
            return false;
          }

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

        function _fetchData() {
          $scope.loading = true;
          ApiModel.load({
            size: $scope.itemsFetchSize
          }).then(function (response) {
            $scope.apis = response.data;
            $scope.loading = false;
          })
        }

        function addPlugin(isValid) {
          if (!isValid) {
            return false;
          }
          var model = angular.copy($scope.modelPlugin);
          model.config.protection_document.forEach(function (path, pIndex) {
            path.conditions.forEach(function (cond, cIndex) {
              cond.httpMethods = cond.httpMethods.map(function (o) {
                return o.text;
              });
              cond.scopes = cond.scopes.map(function (o) {
                return o.text;
              });
              if (cond.ticketScopes.length > 0) {
                cond.ticketScopes = cond.ticketScopes.map(function (o) {
                  return o.text;
                });
              } else {
                delete cond.ticketScopes;
              }
            });
          });
          model.config.protection_document = (JSON.stringify(JSON.parse(angular.toJson(model.config.protection_document))));
          PluginHelperService.addPlugin(
            model,
            function success(res) {
              console.log("create plugin", res)
              $scope.busy = false;
              MessageService.success('Plugin added successfully!')
              $state.go('apis') // return to plugins page if specified
            }, function (err) {
              $scope.busy = false;
              $log.error("create plugin", err)
              var errors = {}

              if (err.data.customMessage) {
                Object.keys(err.data.customMessage).forEach(function (key) {
                  errors[key.replace('config.', '')] = err.data.customMessage[key]
                  MessageService.error(key + " : " + err.data.customMessage[key])
                })
              }

              if (err.data.body) {
                Object.keys(err.data.body).forEach(function (key) {
                  errors[key] = err.data.body[key]
                  MessageService.error(key + " : " + err.data.body[key])
                })
              }
              $scope.errors = errors
            }, function evt(event) {
              // Only used for ssl plugin certs upload
              var progressPercentage = parseInt(100.0 * event.loaded / event.total);
              $log.debug('progress: ' + progressPercentage + '% ' + event.config.data.file.name);
            });

        }

        function loadMethods(query) {
          var arr = ['GET', 'POST', 'DELETE', 'PUT', 'PATCH'];
          arr = arr.filter(function (o) {
            return o.indexOf(query.toUpperCase()) >= 0;
          });
          return arr;
        }

        function loadScopes(query) {
          return [];
        }

        /**
         * ------------------------------------------------------------
         * Listeners
         * ------------------------------------------------------------
         */
        $scope.$on("plugin.added", function () {
          _fetchData()
        })

        $scope.$on("plugin.updated", function (ev, plugin) {
          _fetchData()
        })


        $scope.$on('user.node.updated', function (node) {
          _fetchData()
        })


        _fetchData();

      }
    ])
  ;
}());
