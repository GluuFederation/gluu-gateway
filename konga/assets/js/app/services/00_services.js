(function () {
  'use strict';

  angular.module('frontend.services', [
    'angular.chips',
    'ngFileUpload'
  ]);

  // Module configuration
  angular.module('frontend.services')
    .config([
      '$stateProvider',
      function config($stateProvider) {
        $stateProvider
          .state('services', {
            parent: 'frontend',
            url: '/services',
            data: {
              activeNode: true,
              pageName: "Services",
              pageDescription: "Service entities, as the name implies, are abstractions of each of your own upstream services. Examples of Services would be a data transformation microservice, a billing API, etc.",
              //displayName : "services",
              prefix: '<i class="material-icons">cloud_queue</i>'
            },
            views: {
              'content@': {
                templateUrl: 'js/app/services/views/services.html',
                controller: 'ServicesController',
              }
            }
          })
          .state('services.edit', {
            url: '/:service_id/edit',
            data: {
              pageName: "Edit Service",
              pageDescription: "",
              displayName: "edit Service",
              prefix: '<i class="mdi mdi-pencil"></i>'
            },
            views: {
              'content@': {
                templateUrl: 'js/app/services/views/edit-service.html',
                controller: 'ServiceController',
                resolve: {
                  _service: [
                    'ServiceService', '$stateParams',
                    function resolve(ServiceService, $stateParams) {
                      return ServiceService.findById($stateParams.service_id);
                    }
                  ],
                  _activeNode: [
                    'NodesService',
                    function resolve(NodesService) {
                      return NodesService.isActiveNodeSet();
                    }
                  ],
                }

              },
              'details@services.edit': {
                templateUrl: 'js/app/services/views/service-details.html',
                controller: 'ServiceDetailsController',
              },
              'routes@services.edit': {
                templateUrl: 'js/app/services/views/service-routes.html',
                controller: 'ServiceRoutesController'
              },
              'plugins@services.edit': {
                templateUrl: 'js/app/services/views/service-plugins.html',
                controller: 'ServicePluginsController',
                resolve: {
                  _plugins: [
                    'PluginsService', '$stateParams',
                    function (PluginsService, $stateParams) {
                      return PluginsService.getPluginsByContext("services", $stateParams.service_id)
                    }
                  ]
                }
              },
              'consumers@services.edit': {
                templateUrl: 'js/app/services/views/service-consumers.html',
                controller: 'ServiceConsumersController'
              },
              'healthchecks@services.edit': {
                templateUrl: 'js/app/services/views/service-health-checks.html',
                controller: 'ServiceHealthChecksController',
              }
            }
          })
          .state('services.oauth-plugin', {
            url: '/:service_id/oauth-plugin',
            data: {
              pageName: "Gluu OAuth Auth & PEP",
              pageDescription: "This plugin enables the use of an external OpenID Provider for OAuth2 client registration and authentication. It needs to connect to Gluu's `oxd` service, which is an OAuth2 client middleware service.",
              displayName: "Gluu OAuth plugins",
              prefix: '<i class="mdi mdi-pencil"></i>'
            },
            views: {
              'content@': {
                templateUrl: 'js/app/plugins/oauth-plugin.html',
                controller: 'OAuthPluginController',
                resolve: {
                  _context_name: [
                    '$log',
                    function resolve() {
                      return 'service';
                    }
                  ],
                  _context_data: [
                    '$stateParams',
                    'ServiceService',
                    '$log',
                    function resolve($stateParams,
                                     ServiceService) {
                      return ServiceService.findById($stateParams.service_id)
                    }
                  ],
                  _plugins: [
                    'PluginsService', '$stateParams',
                    function resolve(PluginsService, $stateParams) {
                      return PluginsService.getPluginsByContext("services", $stateParams.service_id)
                    }
                  ],
                  _activeNode: [
                    'NodesService',
                    function resolve(NodesService) {
                      return NodesService.isActiveNodeSet()
                    }
                  ],
                }
              }
            }
          })
          .state('services.uma-plugin', {
            url: '/:service_id/uma-plugin',
            data: {
              pageName: "Gluu UMA Auth & PEP",
              pageDescription: "This plugin enables the use of an external OpenID Provider for UMA resource registration and authorization. It needs to connect to Gluu's `oxd` service, which is an OAuth2 client middleware service.",
              displayName: "Gluu UMA plugins",
              prefix: '<i class="mdi mdi-pencil"></i>'
            },
            views: {
              'content@': {
                templateUrl: 'js/app/plugins/uma-plugin.html',
                controller: 'UMAPluginController',
                resolve: {
                  _context_name: [
                    '$log',
                    function resolve() {
                      return 'service';
                    }
                  ],
                  _context_data: [
                    '$stateParams',
                    'ServiceService',
                    '$log',
                    function resolve($stateParams,
                                     ServiceService) {
                      return ServiceService.findById($stateParams.service_id)
                    }
                  ],
                  _plugins: [
                    'PluginsService', '$stateParams',
                    function resolve(PluginsService, $stateParams) {
                      return PluginsService.getPluginsByContext("services", $stateParams.service_id)
                    }
                  ],
                  _activeNode: [
                    'NodesService',
                    function resolve(NodesService) {
                      return NodesService.isActiveNodeSet()
                    }
                  ],
                }
              }
            }
          })
          .state('services.plugins', {
            url: '/:service_id/plugins',
            params: {
              service: {}
            },
            data: {
              pageName: "Service Plugins",
              displayName: "Service plugins"
            },
            views: {
              'content@': {
                templateUrl: 'js/app/services/views/service-plugins.html',
                controller: 'ServicePluginsController',
                resolve: {
                  _service: [
                    'ServiceService', '$stateParams',
                    function (ServiceService, $stateParams) {
                      return ServiceService.findById($stateParams.service_id)
                    }
                  ],
                  _plugins: [
                    'PluginsService', '$stateParams',
                    function (PluginsService, $stateParams) {
                      return PluginsService.getPluginsByContext("services", $stateParams.service_id)
                    }
                  ],
                  _activeNode: [
                    'NodesService',
                    function resolve(NodesService) {

                      return NodesService.isActiveNodeSet()
                    }
                  ],
                }
              }
            },
          })
          .state('services.plugins.manage', {
            url: '/manage',
            data: {
              pageName: "Manage Service Plugins",
              displayName: "manage"
            },
            views: {
              'content@': {
                templateUrl: 'js/app/services/views/plugins/manage/manage-service-plugins.html',
                controller: 'ManageServicePluginsController',
                resolve: {
                  _service: [
                    '$stateParams',
                    'ServiceService',
                    '$log',
                    function resolve($stateParams,
                                     ServiceService,
                                     $log) {
                      return ServiceService.findById($stateParams.service_id)
                    }
                  ],
                  _plugins: [
                    '$stateParams',
                    'ServiceService',
                    '$log',
                    function resolve($stateParams,
                                     ServiceService,
                                     $log) {
                      return ServiceService.plugins($stateParams.service_id)
                    }
                  ],
                  _info: [
                    '$stateParams',
                    'InfoService',
                    '$log',
                    function resolve($stateParams,
                                     InfoService,
                                     $log) {
                      return InfoService.getInfo()
                    }
                  ],
                  _activeNode: [
                    'NodesService',
                    function resolve(NodesService) {

                      return NodesService.isActiveNodeSet()
                    }
                  ],
                }
              }
            },
          })
      }
    ])
  ;
}());
