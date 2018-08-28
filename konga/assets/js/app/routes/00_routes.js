(function () {
  'use strict';

  angular.module('frontend.routes', [
    'angular.chips',
    'ngFileUpload'
  ]);

  // Module configuration
  angular.module('frontend.routes')
    .config([
      '$stateProvider',
      function config($stateProvider) {
        $stateProvider
          .state('routes', {
            parent: 'frontend',
            url: '/routes',
            data: {
              activeNode: true,
              pageName: "Routes",
              pageDescription: "" +
              "The Route entities defines rules to match client requests. Each Route is associated with a Service, and a Service may have multiple Routes associated to it. Every request matching a given Route will be proxied to its associated Service.",
              //displayName : "routes",
              prefix: '<i class="material-icons">cloud_queue</i>'
            },
            views: {
              'content@': {
                templateUrl: 'js/app/routes/views/routes.html',
                controller: 'RoutesController',
                resolve: {
                  _services: [
                    'ServiceModel', function resolve(ServiceModel) {
                      return ServiceModel.load({
                        size: 4294967295
                      })
                    }
                  ]
                }
              }
            }
          })
          .state('routes.edit', {
            url: '/:route_id/edit',
            data: {
              pageName: "Edit Route",
              pageDescription: "",
              displayName: "edit Route",
              prefix: '<i class="mdi mdi-pencil"></i>'
            },
            views: {
              'content@': {
                templateUrl: 'js/app/routes/views/edit-route.html',
                controller: 'RouteController',
                resolve: {
                  _route: [
                    'RoutesService', '$stateParams',
                    function resolve(RoutesService, $stateParams) {
                      return RoutesService.findById($stateParams.route_id)
                    }
                  ],
                  _activeNode: [
                    'NodesService',
                    function resolve(NodesService) {
                      return NodesService.isActiveNodeSet()
                    }
                  ],
                }

              },
              'details@routes.edit': {
                templateUrl: 'js/app/routes/views/route-details.html',
                controller: 'RouteDetailsController',
                resolve: {
                  _route: [
                    'RoutesService', '$stateParams',
                    function resolve(RoutesService, $stateParams) {
                      return RoutesService.findById($stateParams.route_id)
                    }
                  ]
                }
              },
              'plugins@routes.edit': {
                templateUrl: 'js/app/routes/views/route-plugins.html',
                controller: 'RoutePluginsController',
                resolve: {
                  _plugins: [
                    'PluginsService', '$stateParams',
                    function (PluginsService, $stateParams) {
                      return PluginsService.load({route_id: $stateParams.route_id})
                    }
                  ]
                }
              }
            }
          })
          .state('routes.uma-plugin', {
            url: '/:route_id/uma-plugin',
            data: {
              pageName: "UMA-RS plugin",
              pageDescription: "A Plugin entity represents a plugin configuration that will be executed during the HTTP request/response workflow, and it's how you can add functionalities to APIs that run behind Kong. <code> It will create a client and register the UMA resources using oxd.</code>",
              displayName: "UMA-RS plugin",
              prefix: '<i class="mdi mdi-pencil"></i>'
            },
            views: {
              'content@': {
                templateUrl: 'js/app/apis/views/manage-uma-rs-plugin.html',
                controller: 'ManageUmaRsPluginController',
                resolve: {
                  _context_name: [
                    '$log',
                    function resolve() {
                      return 'route';
                    }
                  ],
                  _context_data: [
                    '$stateParams',
                    'RoutesService',
                    '$log',
                    function resolve($stateParams,
                                     RoutesService) {
                      return RoutesService.findById($stateParams.route_id)
                    }
                  ],
                  _plugins: [
                    'PluginsService', '$stateParams',
                    function resolve(PluginsService, $stateParams) {
                      return PluginsService.load({route_id: $stateParams.route_id})
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
          .state('routes.plugins', {
            url: '/:route_id/plugins',
            params: {
              route: {}
            },
            data: {
              pageName: "Route Plugins",
              displayName: "Route plugins"
            },
            views: {
              'content@': {
                templateUrl: 'js/app/routes/views/route-plugins.html',
                controller: 'RoutePluginsController',
                resolve: {
                  _route: [
                    'RoutesService', '$stateParams',
                    function (RoutesService, $stateParams) {
                      return RoutesService.findById($stateParams.route_id)
                    }
                  ],
                  _plugins: [
                    'PluginsService', '$stateParams',
                    function (PluginsService, $stateParams) {
                      return PluginsService.load({
                        route_id: $stateParams.route_id
                      })
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
          .state('routes.plugins.manage', {
            url: '/manage',
            data: {
              pageName: "Manage Route Plugins",
              displayName: "manage"
            },
            views: {
              'content@': {
                templateUrl: 'js/app/routes/views/plugins/manage/manage-route-plugins.html',
                controller: 'ManageRoutePluginsController',
                resolve: {
                  _route: [
                    '$stateParams',
                    'RoutesService',
                    '$log',
                    function resolve($stateParams,
                                     RoutesService,
                                     $log) {
                      return RoutesService.findById($stateParams.route_id)
                    }
                  ],
                  _plugins: [
                    '$stateParams',
                    'RoutesService',
                    '$log',
                    function resolve($stateParams,
                                     RoutesService,
                                     $log) {
                      return RoutesService.plugins($stateParams.route_id)
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
